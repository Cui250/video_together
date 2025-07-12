import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_together/models/watch_history.dart';
import 'package:video_together/services/watch_history_service.dart';

class HistoryListPage extends StatefulWidget {

  final String videoPath;
  final Duration? initialPosition;

  const HistoryListPage({
    super.key,
    this.videoPath= '',
    this.initialPosition,
  });

  @override
  State<HistoryListPage> createState() => _HistoryListPageState();
}

class _HistoryListPageState extends State<HistoryListPage> {
  late VideoPlayerController _controller;
  final WatchHistoryService _historyService = WatchHistoryService();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        if (widget.initialPosition != null) {
          _controller.seekTo(widget.initialPosition!);
        }
        setState(() {});
        _playVideo();
      });

    _controller.addListener(_updatePlaybackState);
  }

  void _playVideo() {
    setState(() {
      _isPlaying = true;
      _controller.play();
    });
    _saveHistory(); // 开始播放时保存记录
  }

  void _pauseVideo() {
    setState(() {
      _isPlaying = false;
      _controller.pause();
    });
    _saveHistory(); // 暂停时保存记录
  }

  void _updatePlaybackState() {
    if (_controller.value.isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = _controller.value.isPlaying;
      });
    }
    // 播放进度变化时自动保存（但限制频率）
    if (_isPlaying) {
      _throttledSaveHistory();
    }
  }

  // 节流保存，避免频繁写入
  DateTime _lastSaveTime = DateTime.now();
  void _throttledSaveHistory() {
    if (DateTime.now().difference(_lastSaveTime).inSeconds >= 5) {
      _saveHistory();
      _lastSaveTime = DateTime.now();
    }
  }

  Future<void> _saveHistory() async {
    if (!_controller.value.isInitialized) return;

    try {
      await WatchHistoryService.addHistory(
        WatchHistory(
          videoPath: widget.videoPath,
          videoTitle: widget.videoPath.split('/').last,
          position: _controller.value.position,
          lastWatched: DateTime.now(),
          thumbnailPath: null, // 可以替换为实际缩略图路径
        ),
      );
      debugPrint('历史记录已保存: ${widget.videoPath}');
    } catch (e) {
      debugPrint('保存历史记录失败: $e');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePlaybackState);
    // 退出页面时保存最后进度
    _saveHistory();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoPath.split('/').last),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 50,
                color: Colors.white.withOpacity(0.8),
              ),
              onPressed: () {
                if (_isPlaying) {
                  _pauseVideo();
                } else {
                  _playVideo();
                }
              },
            ),
          ],
        )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.bookmark),
        onPressed: () {
          // 可以添加收藏功能
          _saveHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已保存观看进度')),
          );
        },
      ),
    );
  }
}