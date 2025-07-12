// lib/pages/together/together_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'together_state.dart';
import 'package:flutter/services.dart';  // 添加这行导入

class TogetherController {
  final ValueNotifier<TogetherState> state;
  final BuildContext context;
  final String userId;

  late WebSocketChannel channel;
  Timer? _heartbeatTimer;

  TogetherController({
    required this.state,
    required this.context,
    required this.userId,
  });

  Future<void> initialize() async {
    await _connectToServer();
    state.value = state.value.copyWith(
      controller: VideoPlayerController.asset(''),
    );
    await _verifyVideoAssets();
    await _verifyVideo();

    // 心跳定时器
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      channel.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  Future<void> _connectToServer() async {
    int retryCount = 0;
    const maxRetries = 3;

    state.value = state.value.copyWith(isLoading: true);

    while (retryCount < maxRetries) {
      try {
        final serverIp = await _getServerIp();
        debugPrint('连接服务器: ws://$serverIp:8080');

        channel = WebSocketChannel.connect(
          Uri.parse('ws://$serverIp:8080'),
        );

        await channel.ready.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('连接超时')
        );

        channel.stream.listen(
          _handleMessage,
          onError: (error) => _handleError('连接错误', error),
          onDone: () => _handleError('连接断开', null),
          cancelOnError: true,
        );

        _sendHandshake();
        state.value = state.value.copyWith(isLoading: false);
        return;
      } on TimeoutException catch (e) {
        _handleError('连接超时', e);
      } catch (e) {
        _handleError('连接异常', e);
      }
      retryCount++;
    }
    state.value = state.value.copyWith(isLoading: false);
  }

  void _handleError(String title, dynamic error) {
    debugPrint('$title: $error');
    state.value = state.value.copyWith(
      controllerState: ControllerState.error,
      controllerError: error?.toString() ?? '未知错误',
    );
  }

  void _sendHandshake() {
    channel.sink.add(jsonEncode({
      'type': 'handshake',
      'user_id': userId,
      'device': Platform.operatingSystem,
      'time': DateTime.now().toIso8601String()
    }));
  }

  Future<String> _getServerIp() async {
    if (Platform.isAndroid) {
      try {
        final result = await Process.run('getprop', ['ro.kernel.qemu']);
        return result.stdout.toString().trim() == '1' ? '10.0.2.2' : '192.168.x.x';
      } catch (_) {
        return '10.0.2.2';
      }
    }
    return 'localhost';
  }

  void _handleMessage(dynamic message) {
    try {
      if (message == null) return;

      final data = jsonDecode(message.toString());
      if (data is! Map<String, dynamic>) {
        throw FormatException('Invalid message format');
      }
      _handleServerMessage(data);
    } catch (e) {
      debugPrint('消息解析失败: $e');
      if (e is FormatException) {
        _showError('服务器消息格式错误');
      }
    }
  }

  void _handleServerMessage(Map<String, dynamic> message) {
    final isFromSelf = message['from_user'] == userId;
    // 在_handleServerMessage开头添加调试输出
    debugPrint('收到消息: ${message['type']}');

    switch (message['type']) {
      case 'pong':
        debugPrint('收到pong响应');
        break;
      case 'room_created':
        state.value = state.value.copyWith(
          roomId: message['room_id'],
          isHost: true,
        );
        _initializeMainController(message['video']);
        break;
      case 'room_joined':
        state.value = state.value.copyWith(
          roomId: message['room_id'],
          isHost: false,
          participants: List<String>.from(message['participants'] ?? []),
        );

        Future.delayed(const Duration(milliseconds: 100), () {
          _checkVideoAvailability(message['video']).then((_) {
            if (_isControllerInitialized()) {
              if (message['position'] != null) {
                state.value.controller?.seekTo(Duration(milliseconds: message['position']));
              }
              if (message['is_playing'] == true) {
                state.value.controller?.play();
              } else {
                state.value.controller?.pause();
              }
            }
          });
        });
        break;
      case 'sync_playback':
        if (message['from_user'] == userId) break;
        state.value = state.value.copyWith(
          syncState: SyncState.receiving,
          currentPosition: Duration(milliseconds: message['position']),
          isPlaying: message['is_playing'],
        );

        state.value.controller?.seekTo(state.value.currentPosition);
        if (state.value.isPlaying) {
          state.value.controller?.play();
        } else {
          state.value.controller?.pause();
        }

        Future.delayed(const Duration(milliseconds: 300), () {
          state.value = state.value.copyWith(syncState: SyncState.idle);
        });
        break;
      case 'video_changed':
        _checkVideoAvailability(message['video']);
        break;
      case 'participant_update':
        state.value = state.value.copyWith(
          participants: List<String>.from(message['participants']),
        );
        break;

    // 在_handleServerMessage中添加聊天消息处理
      case 'chat_message':
        final isMe = message['sender_id'] == userId;
        final chatMessage = ChatMessage(
          senderId: message['sender_id'],
          senderName: isMe ? '我' : '用户${message['sender_id'].substring(0, 4)}',
          content: message['content'],
          timestamp: DateTime.parse(message['timestamp']),
          isMe: isMe,
        );

        state.value = state.value.copyWith(
          messages: [...state.value.messages, chatMessage],
        );
        break;
    // 在_handleServerMessage中添加对新消息类型的处理
      case 'video_share_response':
        _handleVideoShareResponse(message);
        break;

      case 'video_chunk':
        _handleVideoChunk(message);
        break;

      case 'video_transfer_complete':
        _handleVideoTransferComplete(message);
        break;

      case 'video_share_request':
        _handleVideoShareRequest(message);
        break;


    }
  }

  Future<void> _verifyVideoAssets() async {
    try {
      final manifest = await DefaultAssetBundle.of(context)
          .loadString('AssetManifest.json');
      final videos = jsonDecode(manifest).keys
          .where((key) => key is String && key.startsWith('assets/videos/'))
          .toList();

      if (videos.isEmpty) {
        throw Exception('未找到视频资源');
      }

      for (final video in videos) {
        try {
          await VideoPlayerController.asset(video).initialize();
          debugPrint('视频验证成功: $video');
        } catch (e) {
          debugPrint('视频加载失败: $video - $e');
        }
      }
    } catch (e) {
      debugPrint('资源清单读取失败: $e');
      _showError('资源清单读取失败: ${e.toString()}');
    }
  }

  Future<void> _verifyVideo() async {
    const video = 'assets/videos/01test.mp4';
    try {
      final byteData = await rootBundle.load(video);
      debugPrint('视频文件存在，大小: ${byteData.lengthInBytes} bytes');

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_video.mp4');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      final controller = VideoPlayerController.file(tempFile);
      await controller.initialize();
      debugPrint('视频可播放，时长: ${controller.value.duration}');

      await controller.dispose();
      await tempFile.delete();
    } catch (e) {
      debugPrint('视频验证失败: $e');
      _showError('视频验证失败: ${e.toString()}');
    }
  }

  Future<void> _initializeMainController(String videoPath) async {
    try {
      state.value = state.value.copyWith(
        isLoading: true,
        controllerState: ControllerState.initializing,
        currentVideo: videoPath,
      );

      await state.value.controller?.dispose();

      final newController = videoPath.startsWith('assets/')
          ? VideoPlayerController.asset(videoPath)
          : VideoPlayerController.file(File(videoPath));

      newController.addListener(_handleControllerUpdates);

      await newController.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('视频加载超时'),
      );

      if (newController.value.duration.inSeconds <= 0) {
        throw Exception('视频时长无效: ${newController.value.duration}');
      }

      state.value = state.value.copyWith(
        isLoading: false,
        controllerState: ControllerState.initialized,
        controller: newController,
        isPlaying: state.value.isHost,
        hasVideoFile: true, // 标记视频文件可用
      );

      if (state.value.isHost) {
        newController.play();
      } else {
        await newController.pause();
        await newController.seekTo(Duration.zero);
      }
    } catch (e) {
      debugPrint('初始化主控制器失败: $e');
      state.value = state.value.copyWith(
        isLoading: false,
        controllerState: ControllerState.error,
        controllerError: e.toString(),
        hasVideoFile: false, // 标记视频文件不可用
      );
      _showError('视频初始化失败: ${e.toString().split(':').first}');
      debugPrint('视频初始化失败: ${e.toString().split(':').first}');

      // 如果不是默认视频，尝试回退到默认视频
      if (videoPath != 'assets/videos/01test.mp4') {
        _checkVideoAvailability('assets/videos/01test.mp4');
      } else {
        _showError('视频初始化失败: ${e.toString().split(':').first}');
      }
    }
  }

  Future<void> _checkVideoAvailability(String videoPath) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(videoPath);
    final localPath = '${appDocDir.path}/$fileName';

    state.value = state.value.copyWith(currentVideo: videoPath);

    try {
      // 检查本地文件是否存在
      if (await File(localPath).exists()) {
        await loadAndPlayVideo(localPath);
      } else if (videoPath.startsWith('assets/')) {
        // 如果是资源文件，直接尝试加载
        await loadAndPlayVideo(videoPath);
      } else {
        // 既不是本地文件也不是资源文件，显示下载对话框
        state.value = state.value.copyWith(hasVideoFile: false);
        _showDownloadDialog(videoPath);
      }
    } catch (e) {
      state.value = state.value.copyWith(hasVideoFile: false);
      _showDownloadDialog(videoPath);
    }
  }

  Future<void> loadAndPlayVideo(String videoPath) async {
    try {
      // 先检查文件是否存在且有效
      if (videoPath.startsWith('assets/')) {
        // 对于资源文件，直接尝试加载
        await _initializeMainController(videoPath);
      } else {
        final file = File(videoPath);
        if (!await file.exists()) {
          throw Exception('视频文件不存在');
        }
        if (await file.length() == 0) {
          throw Exception('视频文件为空');
        }
        await _initializeMainController(videoPath);
      }
    } catch (e) {
      // 加载失败时，如果不是默认视频，尝试回退到默认视频
      if (videoPath != 'assets/videos/01test.mp4') {
        _checkVideoAvailability('assets/videos/01test.mp4');
      } else {
        // 默认视频也加载失败，显示错误
        _showError('无法播放视频: ${e.toString()}');
      }
    }
  }
  void _showDownloadDialog(String videoPath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('视频未找到'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('您没有此视频文件，需要下载才能一起观看'),
            const SizedBox(height: 16),
            ValueListenableBuilder<TogetherState>(
              valueListenable: state,
              builder: (context, state, _) {
                return Column(
                  children: [
                    LinearProgressIndicator(value: state.videoReceiveProgress),
                    Text('${(state.videoReceiveProgress * 100).toStringAsFixed(1)}%'),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              leaveRoom();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadVideo(videoPath);
            },
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }
  Future<void> _downloadVideo(String videoPath) async {
    try {
      state.value = state.value.copyWith(
        isReceivingVideo: true,
        videoReceiveProgress: 0.0,
      );

      // 1. 向房主请求视频文件
      channel.sink.add(jsonEncode({
        'type': 'video_share_request',
        'room_id': state.value.roomId,
        'requester_id': userId,
      }));

      // 2. 等待视频传输完成（由_handleVideoTransferComplete处理）
      // 传输进度通过_handleVideoChunk更新
    } catch (e) {
      state.value = state.value.copyWith(
        isReceivingVideo: false,
      );
      _showError('下载失败: $e');
    }
  }

  void _handleControllerUpdates() {
    if (state.value.controller == null) return;

    final controller = state.value.controller!;
    final positionChanged = (controller.value.position - state.value.currentPosition).abs() >
        Duration(milliseconds: state.value.isHost ? 200 : 500);
    final stateChanged = controller.value.isPlaying != state.value.isPlaying;

    if (state.value.syncState == SyncState.idle && (positionChanged || stateChanged)) {
      state.value = state.value.copyWith(
        currentPosition: controller.value.position,
        isPlaying: controller.value.isPlaying,
      );

      if (state.value.isManualControl) {
        _syncPlaybackState();
      }
    }
  }

  void togglePlayPause() {
    if (state.value.controller == null) return;

    final newIsPlaying = !state.value.isPlaying;
    state.value = state.value.copyWith(
      isPlaying: newIsPlaying,
      isManualControl: true,
    );

    if (newIsPlaying) {
      state.value.controller!.play();
    } else {
      state.value.controller!.pause();
    }

    _syncPlaybackState();

    Future.delayed(const Duration(milliseconds: 1000), () {
      state.value = state.value.copyWith(isManualControl: false);
    });
  }

  void _syncPlaybackState() {
    if (state.value.syncState != SyncState.idle || state.value.roomId == null) return;

    state.value = state.value.copyWith(syncState: SyncState.sending);

    final syncMessage = {
      'type': 'sync_playback',
      'room_id': state.value.roomId,
      'position': state.value.controller!.value.position.inMilliseconds,
      'is_playing': state.value.controller!.value.isPlaying,
      'from_user': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    channel.sink.add(jsonEncode(syncMessage));

    Future.delayed(const Duration(milliseconds: 300), () {
      state.value = state.value.copyWith(syncState: SyncState.idle);
    });
  }

  Future<void> createRoom(String videoPath) async {
    channel.sink.add(jsonEncode({
      'type': 'create_room',
      'video': videoPath,
    }));
  }

  Future<void> joinRoom(String roomId) async {
    channel.sink.add(jsonEncode({
      'type': 'join_room',
      'room_id': roomId,
    }));
  }

  void leaveRoom() {
    channel.sink.add(jsonEncode({
      'type': 'leave_room',
      'room_id': state.value.roomId,
    }));
    state.value = state.value.copyWith(
      roomId: null,
      currentVideo: null,
    );
    state.value.controller?.dispose();
  }

  void retryVideoLoading() {
    if (state.value.currentVideo != null) {
      _manageVideoController(state.value.currentVideo!);
    }
  }

  Future<void> _manageVideoController(String videoPath) async {
    if (state.value.controllerState == ControllerState.initializing) return;

    state.value = state.value.copyWith(
      controllerState: ControllerState.initializing,
      controllerError: null,
    );

    try {
      // 释放旧控制器
      if (state.value.controllerState == ControllerState.initialized) {
        await state.value.controller?.dispose();
      }

      // 初始化新控制器
      final newController = videoPath.startsWith('assets/')
          ? VideoPlayerController.asset(videoPath)
          : VideoPlayerController.file(File(videoPath));

      newController.addListener(_handleControllerUpdates);

      await newController.initialize();

      state.value = state.value.copyWith(
        controllerState: ControllerState.initialized,
        controller: newController,
        isPlaying: state.value.isPlaying, // 保持原有播放状态
      );

      if (state.value.isPlaying) {
        newController.play();
      }
    } catch (e) {
      state.value = state.value.copyWith(
        controllerState: ControllerState.error,
        controllerError: e.toString(),
      );
      debugPrint('控制器管理错误: $e');
      _showError('视频加载失败: ${e.toString()}');
    }
  }

  bool _isControllerInitialized() {
    return state.value.controller != null &&
        state.value.controller!.value.isInitialized &&
        state.value.controllerState == ControllerState.initialized;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        )
    );
  }

  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    state.value.controller?.dispose();
    channel.sink.close();
  }

  // 发送聊天消息
  void sendChatMessage(String content) {
    if (state.value.roomId == null) return;

    final message = {
      'type': 'chat_message',
      'room_id': state.value.roomId,
      'sender_id': userId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };

    channel.sink.add(jsonEncode(message));

    // 本地立即显示自己发送的消息
    final chatMessage = ChatMessage(
      senderId: userId,
      senderName: '我', // 可以根据需要显示用户名
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
    );

    state.value = state.value.copyWith(
      messages: [...state.value.messages, chatMessage],
    );
  }

  // 切换聊天输入框可见性
  void toggleChatInput() {
    state.value = state.value.copyWith(
      isChatInputVisible: !state.value.isChatInputVisible,
    );
  }



  void _showShareConfirmationDialog(String requesterId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('视频共享请求'),
        content: const Text('有成员请求共享当前视频文件，是否同意共享？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _declineVideoShare(requesterId);
            },
            child: const Text('拒绝'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptVideoShare(requesterId);
            },
            child: const Text('共享'),
          ),
        ],
      ),
    );
  }


  Future<void> _shareVideoFile(String requesterId, File videoFile) async {
    final fileSize = await videoFile.length();
    const chunkSize = 64 * 1024; // 64KB每块

    final stream = videoFile.openRead();
    var bytesSent = 0;

    await for (final chunk in stream) {
      channel.sink.add(jsonEncode({
        'type': 'video_chunk',
        'requester_id': requesterId,
        'data': base64Encode(chunk),
        'total_size': fileSize,
        'bytes_sent': bytesSent,
      }));

      bytesSent += chunk.length;
      final progress = bytesSent / fileSize;

      // 更新发送进度
      if (state.value.isHost) {
        state.value = state.value.copyWith(
          videoSendProgress: progress,
        );
      }

      // 小延迟防止阻塞
      await Future.delayed(const Duration(milliseconds: 10));
    }

    channel.sink.add(jsonEncode({
      'type': 'video_transfer_complete',
      'requester_id': requesterId,
    }));
  }

  // 处理接收视频块
  void _handleVideoChunk(Map<String, dynamic> message) async {
    if (!state.value.isReceivingVideo) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(state.value.currentVideo!);
    final filePath = '${appDocDir.path}/$fileName';
    final file = File(filePath);

    try {
      // 追加数据块
      await file.writeAsBytes(
        base64Decode(message['data']),
        mode: message['bytes_sent'] == 0 ? FileMode.writeOnly : FileMode.append,
      );

      // 更新进度
      state.value = state.value.copyWith(
        videoReceiveProgress: message['bytes_sent'] / message['total_size'],
      );
    } catch (e) {
      debugPrint('接收视频块失败: $e');
      _showError('接收视频失败');
    }
  }

  void _handleVideoTransferComplete(Map<String, dynamic> message) {
    if (state.value.currentVideo != null) {
      // 延迟一点确保文件完全写入
      Future.delayed(Duration(milliseconds: 300), () {
        loadAndPlayVideo(state.value.currentVideo!);
      });
    }

    state.value = state.value.copyWith(
      isReceivingVideo: false,
    );
  }

  Future<void> _onVideoReceived(String filePath) async {
    state.value = state.value.copyWith(
      isReceivingVideo: false,
      currentVideo: filePath,
    );

    await loadAndPlayVideo(filePath);

    // 同步当前播放状态
    if (state.value.roomId != null) {
      channel.sink.add(jsonEncode({
        'type': 'sync_request',
        'room_id': state.value.roomId,
      }));
    }
  }

  // 请求视频共享
  void requestVideoShare() {
    if (state.value.roomId == null || state.value.isHost) return;

    channel.sink.add(jsonEncode({
      'type': 'video_share_request',
      'room_id': state.value.roomId,
      'requester_id': userId,
    }));

    state.value = state.value.copyWith(
      isReceivingVideo: true,
      videoReceiveProgress: 0.0,
    );
  }

  // 拒绝视频共享
  void _declineVideoShare(String requesterId) {
    channel.sink.add(jsonEncode({
      'type': 'video_share_response',
      'requester_id': requesterId,
      'approved': false,
    }));

    state.value = state.value.copyWith(
      isVideoSharingAvailable: false,
      pendingRequesterId: null,
    );
  }

  // 获取当前视频文件
  Future<File?> _getCurrentVideoFile() async {
    if (state.value.controller == null) return null;

    if (state.value.currentVideo?.startsWith('file://') ?? false) {
      return File(state.value.currentVideo!.substring(7));
    } else if (state.value.currentVideo != null) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(state.value.currentVideo!);
      return File('${appDocDir.path}/$fileName');
    }
    return null;
  }

  // 处理视频共享请求
  void _handleVideoShareRequest(Map<String, dynamic> message) {
    if (!state.value.isHost) return;

    state.value = state.value.copyWith(
      isVideoSharingAvailable: true,
      pendingRequesterId: message['requester_id'],
    );

    _showShareConfirmationDialog(message['requester_id']);
  }

  void _acceptVideoShare(String requesterId) async {
    if (state.value.controller == null) return;

    state.value = state.value.copyWith(
      isSendingVideo: true,
      videoSendProgress: 0.0,
    );

    // 通知请求方已同意
    channel.sink.add(jsonEncode({
      'type': 'video_share_response',
      'requester_id': requesterId,
      'approved': true,
    }));

    // 获取视频文件
    final videoFile = await _getCurrentVideoFile();
    if (videoFile == null) {
      state.value = state.value.copyWith(isSendingVideo: false);
      return;
    }

    // 开始传输
    await _shareVideoFile(requesterId, videoFile);

    state.value = state.value.copyWith(
      isSendingVideo: false,
      isVideoSharingAvailable: false,
    );
  }

  // 处理视频共享响应
  void _handleVideoShareResponse(Map<String, dynamic> message) {
    if (message['approved']) {
      state.value = state.value.copyWith(
        isReceivingVideo: true,
        videoReceiveProgress: 0.0,
      );
    } else {
      state.value = state.value.copyWith(
        isReceivingVideo: false,
        isVideoSharingAvailable: false,
      );
      _showError('房主拒绝了视频共享请求');
    }
  }


}