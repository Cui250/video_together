// lib/pages/together/room_dialog.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class RoomDialog extends StatefulWidget {
  @override
  _RoomDialogState createState() => _RoomDialogState();
}

class _RoomDialogState extends State<RoomDialog> {
  final _formKey = GlobalKey<FormState>();
  bool isCreate = true;
  String? selectedVideo;
  final roomIdController = TextEditingController();
  List<String> availableVideos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      // 1. 加载应用资源目录中的视频
      final assetVideos = await _loadAssetVideos();

      // 2. 加载上传目录中的视频
      final localVideos = await _loadLocalVideos();

      // 3. 合并并去重
      final allVideos = {...assetVideos, ...localVideos}.toList();

      setState(() {
        availableVideos = allVideos;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading videos: $e');
    }
  }

  Future<List<String>> _loadAssetVideos() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> assetMap = json.decode(manifestContent);

    return assetMap.keys
        .where((key) =>
    key.startsWith('assets/videos/') &&
        ['mp4', 'avi', 'mkv'].contains(p.extension(key).toLowerCase().replaceFirst('.', '')))
        .toList();
  }

  Future<List<String>> _loadLocalVideos() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final uploadDir = Directory('${appDocDir.path}/uploaded_resources');

    if (!await uploadDir.exists()) {
      return [];
    }

    final entities = await uploadDir.list().toList();
    return entities.where((entity) {
      final ext = p.extension(entity.path).toLowerCase();
      return ['.mp4', '.avi', '.mkv'].contains(ext);
    }).map((entity) => entity.path).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isCreate ? '创建房间' : '加入房间'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCreate) ...[
                if (isLoading)
                  const CircularProgressIndicator()
                else if (availableVideos.isEmpty)
                  const Text('没有找到视频文件')
                else
                  DropdownButtonFormField<String>(
                    value: selectedVideo,
                    items: availableVideos.map((videoPath) {
                      final videoName = p.basename(videoPath).split('.').first;
                      return DropdownMenuItem<String>(
                        value: videoPath,
                        child: Text(videoName),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedVideo = value),
                    decoration: const InputDecoration(labelText: '选择视频'),
                    validator: (value) => value == null ? '请选择视频' : null,
                  ),
              ] else ...[
                TextFormField(
                  controller: roomIdController,
                  decoration: const InputDecoration(labelText: '输入房间ID'),
                  validator: (value) => value?.isEmpty ?? true ? '请输入房间ID' : null,
                ),
              ],
              TextButton(
                child: Text(isCreate ? '加入现有房间' : '创建新房间'),
                onPressed: () => setState(() => isCreate = !isCreate),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'is_create': isCreate,
                'video': selectedVideo,
                'room_id': roomIdController.text,
              });
            }
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    roomIdController.dispose();
    super.dispose();
  }
}