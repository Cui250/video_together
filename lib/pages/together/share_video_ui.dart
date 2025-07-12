import 'package:flutter/material.dart';
import 'together_state.dart';
import 'together_controller.dart';

class ShareVideoUI {
  static Widget buildVideoTransferStatus(
      BuildContext context,
      TogetherState state,
      ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isSendingVideo)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('发送进度: '),
                Expanded(
                  child: LinearProgressIndicator(value: state.videoSendProgress),
                ),
                Text('${(state.videoSendProgress * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        if (state.isReceivingVideo)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('接收进度: '),
                Expanded(
                  child: LinearProgressIndicator(value: state.videoReceiveProgress),
                ),
                Text('${(state.videoReceiveProgress * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ),
      ],
    );
  }
}