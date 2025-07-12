import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:convert';
class ResourceGalleryPage extends StatefulWidget {
  const ResourceGalleryPage({super.key});

  @override
  State<ResourceGalleryPage> createState() => _ResourceGalleryPageState();
}

class _ResourceGalleryPageState extends State<ResourceGalleryPage> {
  List<String> assetVideos = [];
  Map<String, String?> thumbnails = {};
  bool isLoading = true;
  bool isSelecting = false;
  Set<String> selectedAssets = Set();
  List<File> localCopies = []; // 存储已复制的本地文件路径

  @override
  void initState() {
    super.initState();
    _loadResourceVideos();
  }

  Future<void> _loadResourceVideos() async {
    try {
      // 加载资源清单
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> assetMap = json.decode(manifestContent);

      // 获取所有视频资源
      final videos = assetMap.keys.where((key) {
        final ext = p.extension(key).toLowerCase();
        return key.startsWith('assets/gallery/') &&
            ['.mp4', '.avi', '.mkv', '.mov'].contains(ext);
      }).toList();

      setState(() {
        assetVideos = videos;
        isLoading = true;
      });

      // 生成缩略图
      for (var assetPath in videos) {
        await _generateThumbnail(assetPath);
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Error loading resource videos: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _generateThumbnail(String assetPath) async {
    try {
      // 将资源文件复制到临时目录
      final tempDir = await getTemporaryDirectory();
      final tempVideoPath = '${tempDir.path}/${p.basename(assetPath)}';

      if (!File(tempVideoPath).existsSync()) {
        final ByteData videoData = await rootBundle.load(assetPath);
        await File(tempVideoPath).writeAsBytes(videoData.buffer.asUint8List());
      }

      // 生成缩略图
      final uint8list = await VideoThumbnail.thumbnailData(
        video: tempVideoPath,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        timeMs: 1000,
      );

      if (uint8list != null) {
        final thumbPath = '${tempDir.path}/${p.basename(assetPath)}_thumb.jpg';
        await File(thumbPath).writeAsBytes(uint8list);

        setState(() {
          thumbnails[assetPath] = thumbPath;
        });
      }
    } catch (e) {
      debugPrint('Failed to generate thumbnail for $assetPath: $e');
      setState(() => thumbnails[assetPath] = null);
    }
  }

  void _toggleSelection(String assetPath) {
    setState(() {
      if (selectedAssets.contains(assetPath)) {
        selectedAssets.remove(assetPath);
      } else {
        selectedAssets.add(assetPath);
      }

      if (selectedAssets.isEmpty) {
        isSelecting = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (selectedAssets.length == assetVideos.length) {
        selectedAssets.clear();
        isSelecting = false;
      } else {
        selectedAssets = Set.from(assetVideos);
        isSelecting = true;
      }
    });
  }

  Future<void> _uploadResources() async {
    if (selectedAssets.isEmpty) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final uploadDir = Directory('${appDocDir.path}/uploaded_resources');

      if (!await uploadDir.exists()) {
        await uploadDir.create(recursive: true);
      }

      int successCount = 0;
      for (var assetPath in selectedAssets) {
        try {
          // 获取资源文件数据
          final ByteData data = await rootBundle.load(assetPath);

          // 创建目标文件
          final fileName = p.basename(assetPath);
          final destPath = '${uploadDir.path}/$fileName';
          final destFile = File(destPath);

          // 写入文件
          await destFile.writeAsBytes(data.buffer.asUint8List());

          // 添加到已复制列表
          if (!localCopies.any((file) => file.path == destPath)) {
            localCopies.add(destFile);
          }

          successCount++;
        } catch (e) {
          debugPrint('Failed to copy resource $assetPath: $e');
        }
      }

      // 显示结果
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功复制 $successCount/${selectedAssets.length} 个资源文件')),
      );

      // 重置选择状态
      setState(() {
        selectedAssets.clear();
        isSelecting = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSelecting
            ? Text('已选择 ${selectedAssets.length} 个资源')
            : const Text('资源文件图库'),
        actions: [
          if (isSelecting) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _uploadResources,
              tooltip: '复制选中资源',
            ),
            IconButton(
              icon: Icon(selectedAssets.length == assetVideos.length
                  ? Icons.deselect
                  : Icons.select_all),
              onPressed: _selectAll,
              tooltip: '全选/取消全选',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResourceVideos,
            tooltip: '刷新资源列表',
          ),
        ],
      ),
      body: Column(
        children: [
          // 已复制文件提示
          if (localCopies.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已复制 ${localCopies.length} 个文件到应用目录',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => localCopies.clear()),
                    child: const Text('清除记录'),
                  ),
                ],
              ),
            ),

          // 资源列表
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : assetVideos.isEmpty
                ? const Center(child: Text('没有找到资源文件'))
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3 / 4,
              ),
              itemCount: assetVideos.length,
              itemBuilder: (context, index) {
                final assetPath = assetVideos[index];
                final fileName = p.basename(assetPath);
                final isSelected = selectedAssets.contains(assetPath);
                final isCopied = localCopies.any((file) =>
                p.basename(file.path) == fileName);

                return GestureDetector(
                  onTap: () {
                    if (isSelecting) {
                      _toggleSelection(assetPath);
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      isSelecting = true;
                      _toggleSelection(assetPath);
                    });
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                          border: isSelected
                              ? Border.all(color: Colors.blue, width: 3)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: thumbnails.containsKey(assetPath) &&
                                    thumbnails[assetPath] != null
                                    ? Image.file(
                                  File(thumbnails[assetPath]!),
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                  const Center(child: Icon(Icons.broken_image)),
                                )
                                    : const Center(child: Icon(Icons.video_library, size: 40)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4.0, horizontal: 4.0),
                              child: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCopied ? Colors.green : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      if (isCopied && !isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      if (assetPath.startsWith('assets/'))
                        Positioned(
                          bottom: 30,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '资源',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isSelecting
          ? FloatingActionButton.extended(
        onPressed: _uploadResources,
        icon: const Icon(Icons.copy),
        label: Text('复制(${selectedAssets.length})'),
        backgroundColor: Colors.blue,
      )
          : null,
    );
  }
}