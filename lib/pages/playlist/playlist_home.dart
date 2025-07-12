// pages/playlist/playlist_home.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:video_together/models/playlist.dart';
import 'package:video_together/services/playlist_service.dart';
import 'package:video_together/pages/playlist/playlist_detail_page.dart';
import 'package:video_together/pages/playlist/create_playlist_dialog.dart';

class PlaylistHomePage extends StatefulWidget {
  const PlaylistHomePage({super.key});

  @override
  State<PlaylistHomePage> createState() => _PlaylistHomePageState();
}

class _PlaylistHomePageState extends State<PlaylistHomePage> {
  late Future<List<Playlist>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _playlistsFuture = PlaylistService.getAllPlaylists();
  }

  Future<void> _refresh() async {
    setState(() {
      _playlistsFuture = PlaylistService.getAllPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的播放列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Playlist>>(
          future: _playlistsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final playlist = snapshot.data![index];
                return _buildPlaylistCard(playlist);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('还没有播放列表', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('点击右上角+号创建第一个播放列表'),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    final itemCount = playlist.items.length;
    final coverImage = itemCount > 0 && playlist.items[0].thumbnailPath != null
        ? Image.file(File(playlist.items[0].thumbnailPath!), fit: BoxFit.cover)
        : const Icon(Icons.music_note, size: 40);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailPage(playlist: playlist),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverImage,
                    if (itemCount > 0)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$itemCount个视频',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (playlist.description != null)
                    Text(
                      playlist.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreatePlaylistDialog(),
    ).then((_) => _refresh());
  }
}