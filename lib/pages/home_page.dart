// pages/home_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:video_together/services/playlist_service.dart';
import 'package:video_together/pages/playlist/create_playlist_dialog.dart';
import 'package:video_together/pages/video_detail_page.dart';
import 'package:video_together/models/playlist.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<VideoFile> videoFiles = [];
  Map<String, String?> thumbnails = {};
  bool isLoading = true;
  final String _uploadDirName = 'uploaded_resources';

  @override
  void initState() {
    super.initState();
    _loadAllVideos();
  }

  Future<void> _loadAllVideos() async {
    try {
      // 1. 加载应用资源目录中的视频
      final assetVideos = await _loadAssetVideos();

      // 2. 加载上传目录中的视频
      final localVideos = await _loadLocalVideos();

      // 3. 合并并去重（基于文件名）
      final allVideos = [...assetVideos, ...localVideos];
      final uniqueVideos = <String, VideoFile>{};

      for (var video in allVideos) {
        uniqueVideos[video.fileName] = video; // 相同文件名会被覆盖
      }

      setState(() {
        videoFiles = uniqueVideos.values.toList();
        isLoading = false;
      });

      // 4. 生成缩略图（在UI显示后异步处理）
      _generateThumbnails();
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() => isLoading = false);
    }
  }

  Future<List<VideoFile>> _loadAssetVideos() async {
    final manifestContent = await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
    final Map<String, dynamic> assetMap = json.decode(manifestContent);

    final assetVideos = assetMap.keys
        .where((key) =>
    key.startsWith('assets/videos/') &&
        ['mp4', 'avi', 'mkv'].contains(p.extension(key).toLowerCase().replaceFirst('.', '')))
        .toList();

    final appDocDir = await getApplicationDocumentsDirectory();
    final result = <VideoFile>[];

    for (var assetPath in assetVideos) {
      final fileName = p.basename(assetPath);
      final localPath = '${appDocDir.path}/$fileName';

      // 确保资源文件已复制到本地
      if (!File(localPath).existsSync()) {
        final ByteData data = await rootBundle.load(assetPath);
        await File(localPath).writeAsBytes(data.buffer.asUint8List());
      }

      result.add(VideoFile(
        id: 'asset_$fileName',
        fileName: fileName,
        assetPath: assetPath,
        localPath: localPath,
      ));
    }

    return result;
  }

  Future<List<VideoFile>> _loadLocalVideos() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final uploadDir = Directory('${appDocDir.path}/$_uploadDirName');

    // 确保上传目录存在
    if (!await uploadDir.exists()) {
      await uploadDir.create(recursive: true);
      return [];
    }

    // 获取目录下所有视频文件
    final entities = await uploadDir.list().toList();
    final videoFiles = entities.where((entity) {
      final ext = p.extension(entity.path).toLowerCase();
      return ['.mp4', '.avi', '.mkv'].contains(ext);
    }).toList();

    return videoFiles.map((entity) {
      final fileName = p.basename(entity.path);
      return VideoFile(
        id: 'local_$fileName',
        fileName: fileName,
        assetPath: null,
        localPath: entity.path,
      );
    }).toList();
  }

  Future<void> _generateThumbnails() async {
    for (var video in videoFiles) {
      try {
        final uint8list = await VideoThumbnail.thumbnailData(
          video: video.localPath,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        );

        if (uint8list != null) {
          final tempDir = await getTemporaryDirectory();
          final thumbPath = '${tempDir.path}/${video.fileName}_thumb.jpg';
          await File(thumbPath).writeAsBytes(uint8list);

          setState(() {
            thumbnails[video.id] = thumbPath;
          });
        }
      } catch (e) {
        debugPrint('Failed to generate thumbnail for ${video.fileName}: $e');
      }
    }
  }

  Future<void> _showAddToPlaylistDialog(String videoPath, String videoTitle) async {
    final playlists = await PlaylistService.getAllPlaylists();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('添加到播放列表'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('新建播放列表'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog(videoPath, videoTitle);
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return ListTile(
                          leading: playlist.items.isNotEmpty &&
                              playlist.items[0].thumbnailPath != null
                              ? Image.file(
                            File(playlist.items[0].thumbnailPath!),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          )
                              : const Icon(Icons.playlist_add),
                          title: Text(playlist.name),
                          subtitle: Text('${playlist.items.length}个视频'),
                          onTap: () async {
                            await PlaylistService.addToPlaylist(
                              playlistId: playlist.id,
                              item: PlaylistItem(
                                videoPath: videoPath,
                                videoTitle: videoTitle,
                                addedAt: DateTime.now(),
                                thumbnailPath: thumbnails[videoPath],
                              ),
                            );
                            if (mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(String videoPath, String videoTitle) async {
    await showDialog(
      context: context,
      builder: (context) => CreatePlaylistDialog(),
    ).then((_) async {
      final playlists = await PlaylistService.getAllPlaylists();
      if (playlists.isNotEmpty) {
        final newest = playlists.last;
        await PlaylistService.addToPlaylist(
          playlistId: newest.id,
          item: PlaylistItem(
            videoPath: videoPath,
            videoTitle: videoTitle,
            addedAt: DateTime.now(),
            thumbnailPath: thumbnails[videoPath],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频库')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : videoFiles.isEmpty
          ? const Center(child: Text('没有找到视频文件'))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3 / 4,
        ),
        itemCount: videoFiles.length,
        itemBuilder: (context, index) {
          final video = videoFiles[index];
          final hasThumbnail = thumbnails.containsKey(video.id) && thumbnails[video.id] != null;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoDetailPage(videoPath: video.localPath),
                ),
              );
            },
            onLongPress: () => _showAddToPlaylistDialog(video.localPath, video.fileName),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: hasThumbnail
                          ? Image.file(
                        File(thumbnails[video.id]!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.video_library, size: 40),
                      )
                          : const Icon(Icons.video_library, size: 40),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      video.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 视频文件模型
class VideoFile {
  final String id;        // 唯一标识
  final String fileName;  // 文件名
  final String? assetPath; // 资源路径（如果是应用资源）
  final String localPath; // 本地路径

  VideoFile({
    required this.id,
    required this.fileName,
    required this.assetPath,
    required this.localPath,
  });
}