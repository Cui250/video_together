import 'package:flutter/material.dart';
import 'together_controller.dart';
import 'together_state.dart';
import 'together_ui.dart';
import 'room_dialog.dart';

class TogetherPage extends StatefulWidget {
  final bool showControls;
  const TogetherPage({super.key, this.showControls = true});

  @override
  State<TogetherPage> createState() => _TogetherPageState();
}

class _TogetherPageState extends State<TogetherPage> {
  late final TogetherController _controller;
  late final ValueNotifier<TogetherState> _state;
  final String userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
  final TextEditingController _chatTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _state = ValueNotifier(TogetherState());
    _controller = TogetherController(
      state: _state,
      context: context,
      userId: userId,
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _chatTextController.dispose();
    _controller.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('一起看'),
        actions: [
          ValueListenableBuilder<TogetherState>(
            valueListenable: _state,
            builder: (context, state, _) {
              return Row(
                children: [
                  // 聊天开关按钮
                  if (state.roomId != null)
                    IconButton(
                      icon: Icon(
                        state.isChatInputVisible
                            ? Icons.chat
                            : Icons.chat_bubble_outline,
                      ),
                      onPressed: _controller.toggleChatInput,
                    ),
                  // 退出房间按钮
                  if (state.roomId != null)
                    IconButton(
                      icon: const Icon(Icons.exit_to_app),
                      onPressed: _controller.leaveRoom,
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<TogetherState>(
        valueListenable: _state,
        builder: (context, state, _) {
          return TogetherUI.buildContent(
            context,
            state,
            _controller,
            _chatTextController, // 传递聊天文本控制器
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<TogetherState>(
        valueListenable: _state,
        builder: (context, state, _) {
          if (state.roomId == null) {
            return FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: _showRoomDialog,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _showRoomDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RoomDialog(),
    );

    if (result != null) {
      if (result['is_create']) {
        _controller.createRoom(result['video']);
      } else {
        _controller.joinRoom(result['room_id']);
      }
    }
  }
}