import 'dart:io'; // 新增的导入
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async'; // 添加这行，用于TimeoutException
import 'package:flutter/foundation.dart'; // 添加这行，用于kReleaseMode
class SharedVideoPlayer extends StatefulWidget {
  final String videoPath;
  final Duration? initialPosition;
  final bool autoPlay;
  final bool showControls;
  final VideoPlayerController? externalController;

  const SharedVideoPlayer({
    super.key,
    required this.videoPath,
    this.initialPosition,
    this.autoPlay = true,
    this.showControls = true,
    this.externalController,
  });

  @override
  State<SharedVideoPlayer> createState() => _SharedVideoPlayerState();
}

class _SharedVideoPlayerState extends State<SharedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      if (widget.externalController != null) {
        _controller = widget.externalController!;

        // 外部控制器需要确保已初始化
        if (!_controller.value.isInitialized) {
          await _controller.initialize().timeout(const Duration(seconds: 10));
        }
      } else {
        if (Platform.isAndroid && !kReleaseMode) {
          await Future.delayed(const Duration(milliseconds: 500));
        }

        _controller = widget.videoPath.startsWith('assets/')
            ? VideoPlayerController.asset(widget.videoPath)
            : VideoPlayerController.file(File(widget.videoPath));

        await _controller.initialize().timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;
      _handleInitialized();
    } catch (e) {
      debugPrint('控制器初始化失败: ${e.toString()}');
      if (mounted) {
        setState(() {
          _errorMessage = e is TimeoutException
              ? '加载超时'
              : '播放错误: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
      // 不释放外部控制器！
      if (widget.externalController == null) {
        _controller.dispose();
      }
    }
  }

  void _checkInitialization() {
    if (_controller.value.isInitialized && !_isInitialized) {
      _handleInitialized();
    }
  }

  void _handleInitialized() {
    if (mounted) {
      setState(() {
        _isInitialized = true;
        if (widget.initialPosition != null) {
          _controller.seekTo(widget.initialPosition!);
        }
        if (widget.autoPlay && !_controller.value.isPlaying) {
          _controller.play();
        }
      });
    }
  }

  @override
  void dispose() {
    // 只有内部创建的控制器才需要dispose
    if (widget.externalController == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_checkInitialization);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryInitialization,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('视频加载中...'),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller),
          if (widget.showControls) _buildControls(),
        ],
      ),
    );
  }

  Future<void> _retryInitialization() async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _isInitialized = false;
      });
    }
    await _initController();
  }

  Widget _buildControls() {
    return GestureDetector(
      onTap: () {
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        if (mounted) setState(() {});
      },
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 50,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}