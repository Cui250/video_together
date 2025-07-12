// pages/playlist/create_playlist_dialog.dart
import 'package:flutter/material.dart';
import 'package:video_together/models/playlist.dart';
import 'package:video_together/services/playlist_service.dart';
import 'package:uuid/uuid.dart';

class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建播放列表'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '列表名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入列表名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '描述(可选)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _createPlaylist,
          child: const Text('创建'),
        ),
      ],
    );
  }

  Future<void> _createPlaylist() async {
    if (_formKey.currentState!.validate()) {
      final playlist = Playlist(
        id: const Uuid().v4(),
        name: _nameController.text,
        description: _descController.text.isNotEmpty ? _descController.text : null,
        createdAt: DateTime.now(),
        items: [],
      );

      await PlaylistService.savePlaylist(playlist);
      if (mounted) Navigator.pop(context);
    }
  }
}