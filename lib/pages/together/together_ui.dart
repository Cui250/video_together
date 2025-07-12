import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_together/pages/together/share_video_ui.dart';
import 'together_state.dart';
import 'together_controller.dart';
import 'chat_ui.dart'; // 新增导入

class TogetherUI {
  static Widget buildContent(
      BuildContext context,
      TogetherState state,
      TogetherController controller,
      TextEditingController chatTextController,
      ) {
    if (state.roomId == null) {
      return _buildEmptyState();
    }

    if (state.isLoading) {
      return _buildLoadingIndicator();
    }

    if (!_isControllerInitialized(state) || state.currentVideo == null) {
      return _buildInitializingState();
    }

    return Stack(
      children: [
        Column(
          children: [
            // 视频播放器部分
            _buildVideoPlayer(state, controller),

            // 进度条
            _buildProgressIndicator(state),

            // 播放控制按钮
            _buildPlaybackControls(controller),

            // 使用Expanded包装房间信息和聊天面板
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 房间信息（宽度占40%）
                  Expanded(
                    flex: 4,
                    child: _buildRoomInfo(state),
                  ),

                  // 垂直分隔线
                  const VerticalDivider(width: 1),

                  // 聊天面板（宽度占60%）
                  Expanded(
                    flex: 6,
                    child: ChatUI.buildChatPanel(
                      context,
                      state,
                      controller,
                      chatTextController,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // 聊天开关按钮（浮动在右下角）
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            mini: true,
            heroTag: 'chatToggle',
            child: Icon(
              state.isChatInputVisible ? Icons.chat : Icons.chat_bubble_outline,
            ),
            onPressed: controller.toggleChatInput,
          ),
        ),

        // 添加视频传输状态显示
        ShareVideoUI.buildVideoTransferStatus(context, state),

      ],
    );
  }

  static Widget _buildEmptyState() {
    return const Center(child: Text('创建或加入房间开始一起看'));
  }

  static Widget _buildInitializingState() {
    return const Center(child: Text('视频初始化中...'));
  }

  static Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('视频加载中...'),
        ],
      ),
    );
  }

  static Widget _buildVideoPlayer(TogetherState state, TogetherController controller) {
    return AspectRatio(
      aspectRatio: state.controller?.value.aspectRatio ?? 16/9,
      child: Stack(
        children: [
          VideoPlayer(state.controller!),
          _buildControlsOverlay(controller),
        ],
      ),
    );
  }

  static Widget _buildControlsOverlay(TogetherController controller) {
    return GestureDetector(
      onTap: controller.togglePlayPause,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Icon(
            controller.state.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 50,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  static Widget _buildProgressIndicator(TogetherState state) {
    return VideoProgressIndicator(
      state.controller!,
      allowScrubbing: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  static Widget _buildPlaybackControls(TogetherController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(controller.state.value.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: controller.togglePlayPause,
          ),
        ],
      ),
    );
  }

  static Widget _buildRoomInfo(TogetherState state) {
    return ListView(
      children: [
        ListTile(
          title: Text('房间ID: ${state.roomId}'),
          subtitle: Text(state.isHost ? '您是房主' : '您已加入房间'),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('房间成员:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...state.participants.map((p) => ListTile(
          leading: const Icon(Icons.person),
          title: Text(p),
        )).toList(),
      ],
    );
  }

  static bool _isControllerInitialized(TogetherState state) {
    return state.controller != null &&
        state.controller!.value.isInitialized &&
        state.controllerState == ControllerState.initialized;
  }
}