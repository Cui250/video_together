import 'package:flutter/material.dart';
import 'together_state.dart';
import 'together_controller.dart';

class ChatUI {
  static Widget buildChatPanel(
      BuildContext context,
      TogetherState state,
      TogetherController controller,
      TextEditingController textController,
      ) {
    return Column(
      children: [
        // 聊天消息列表
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: state.messages.length,
            itemBuilder: (context, index) {
              final message = state.messages.reversed.toList()[index];
              return _buildMessageBubble(message);
            },
          ),
        ),

        // 聊天输入框
        if (state.isChatInputVisible) _buildChatInput(context, controller, textController),
      ],
    );
  }

  static Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: message.isMe ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: message.isMe ? Colors.blue : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(message.content),
              const SizedBox(height: 4),
              Text(
                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildChatInput(
      BuildContext context,
      TogetherController controller,
      TextEditingController textController,
      ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  controller.sendChatMessage(text);
                  textController.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              final text = textController.text;
              if (text.isNotEmpty) {
                controller.sendChatMessage(text);
                textController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}