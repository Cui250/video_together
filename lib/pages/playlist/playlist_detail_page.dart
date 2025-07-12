// pages/playlist/playlist_detail_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:video_together/models/playlist.dart';
import 'package:video_together/services/playlist_service.dart';
import 'package:video_together/pages/video_detail_page.dart';

class PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  Future<void> _refresh() async {
    final updated = await PlaylistService.getPlaylist(_playlist.id);
    if (updated != null) {
      setState(() {
        _playlist = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _playAll,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('编辑信息'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除列表'),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                _editPlaylist();
              } else if (value == 'delete') {
                _deletePlaylist();
              }
            },
          ),
        ],
      ),
      body: _playlist.items.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_add, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('播放列表为空'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 可以跳转到视频库选择视频
              },
              child: const Text('添加视频'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          itemCount: _playlist.items.length,
          itemBuilder: (context, index) {
            final item = _playlist.items[index];
            return _buildPlaylistItem(item, index);
          },
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(PlaylistItem item, int index) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _removeItem(item.videoPath),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '删除',
          ),
        ],
      ),
      child: ListTile(
        leading: item.thumbnailPath != null
            ? Image.file(File(item.thumbnailPath!), width: 60, height: 60, fit: BoxFit.cover)
            : const Icon(Icons.video_library, size: 40),
        title: Text(item.videoTitle),
        subtitle: Text('添加于: ${_formatDate(item.addedAt)}'),
        trailing: const Icon(Icons.more_vert),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoDetailPage(videoPath: item.videoPath),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _playAll() async {
    if (_playlist.items.isNotEmpty) {
      // 实现播放全部逻辑
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoDetailPage(
            videoPath: _playlist.items[0].videoPath,
          ),
        ),
      );
    }
  }

  Future<void> _removeItem(String videoPath) async {
    await PlaylistService.removeFromPlaylist(
      playlistId: _playlist.id,
      videoPath: videoPath,
    );
    _refresh();
  }

  Future<void> _editPlaylist() async {
    final nameController = TextEditingController(text: _playlist.name);
    final descController = TextEditingController(text: _playlist.description ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑播放列表'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '列表名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = Playlist(
                id: _playlist.id,
                name: nameController.text,
                description: descController.text.isNotEmpty ? descController.text : null,
                createdAt: _playlist.createdAt,
                items: _playlist.items,
              );

              await PlaylistService.savePlaylist(updated);
              if (mounted) {
                Navigator.pop(context);
                _refresh();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除播放列表'),
        content: const Text('确定要删除这个播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PlaylistService.deletePlaylist(_playlist.id);
      if (mounted) Navigator.pop(context);
    }
  }
}