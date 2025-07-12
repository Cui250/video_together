// lib/pages/together/together_state.dart
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

enum ControllerState {
  notInitialized,
  initializing,
  initialized,
  error
}

enum SyncState {
  idle,
  sending,
  receiving
}

class TogetherState {
  ControllerState controllerState = ControllerState.notInitialized;
  String? controllerError;
  bool isLoading = false;

  // 房间状态
  String? roomId;
  bool isHost = false;
  List<String> participants = [];

  // 视频状态
  String? currentVideo;
  Duration currentPosition = Duration.zero;
  bool isPlaying = false;

  // 同步状态
  SyncState syncState = SyncState.idle;
  bool hasVideoFile = false;
  double downloadProgress = 0.0;
  bool isManualControl = false;

  // 新增聊天状态
  List<ChatMessage> messages = [];
  bool isChatInputVisible = false;

  // 新增视频共享相关状态
  bool isVideoSharingAvailable = false;
  bool isReceivingVideo = false;
  bool isSendingVideo = false;
  double videoReceiveProgress = 0.0;
  double videoSendProgress = 0.0;
  String? pendingRequesterId;

  // 控制器
  VideoPlayerController? controller;

  TogetherState();

  TogetherState copyWith({
    ControllerState? controllerState,
    String? controllerError,
    bool? isLoading,
    String? roomId,
    bool? isHost,
    List<String>? participants,
    String? currentVideo,
    Duration? currentPosition,
    bool? isPlaying,
    SyncState? syncState,
    bool? hasVideoFile,
    double? downloadProgress,
    bool? isManualControl,
    VideoPlayerController? controller,

    // 在copyWith中添加新字段
    List<ChatMessage>? messages,
    bool? isChatInputVisible,

    bool? isVideoSharingAvailable,
    bool? isReceivingVideo,
    bool? isSendingVideo,
    double? videoReceiveProgress,
    double? videoSendProgress,
    String? pendingRequesterId,

  }) {
    return TogetherState()
      ..controllerState = controllerState ?? this.controllerState
      ..controllerError = controllerError ?? this.controllerError
      ..isLoading = isLoading ?? this.isLoading
      ..roomId = roomId ?? this.roomId
      ..isHost = isHost ?? this.isHost
      ..participants = participants ?? this.participants
      ..currentVideo = currentVideo ?? this.currentVideo
      ..currentPosition = currentPosition ?? this.currentPosition
      ..isPlaying = isPlaying ?? this.isPlaying
      ..syncState = syncState ?? this.syncState
      ..hasVideoFile = hasVideoFile ?? this.hasVideoFile
      ..downloadProgress = downloadProgress ?? this.downloadProgress
      ..isManualControl = isManualControl ?? this.isManualControl
      ..controller = controller ?? this.controller
      //聊天相关
      ..messages = messages ?? this.messages
      ..isChatInputVisible = isChatInputVisible ?? this.isChatInputVisible

      //视频可用性检查相关
      ..isVideoSharingAvailable = isVideoSharingAvailable ?? this.isVideoSharingAvailable
      ..isReceivingVideo = isReceivingVideo ?? this.isReceivingVideo
      ..isSendingVideo = isSendingVideo ?? this.isSendingVideo
      ..videoReceiveProgress = videoReceiveProgress ?? this.videoReceiveProgress
      ..videoSendProgress = videoSendProgress ?? this.videoSendProgress
      ..pendingRequesterId = pendingRequesterId ?? this.pendingRequesterId;

  }
}

// 新增聊天消息模型
class ChatMessage {
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe; // 是否是我发送的消息

  ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });
}
