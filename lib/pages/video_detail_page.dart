import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

import '../models/watch_history.dart';
import '../services/watch_history_service.dart';

class VideoDetailPage extends StatefulWidget {
  final String videoPath;
  final Duration? initialPosition;

  const VideoDetailPage({
    super.key,
    required this.videoPath,
    this.initialPosition,
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isMuted = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  final List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    // 判断路径类型
    if (widget.videoPath.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(widget.videoPath);
    } else {
      _controller = VideoPlayerController.file(File(widget.videoPath));
    }

    _controller
      ..setLooping(true)
      ..initialize().then((_) {
        if (widget.initialPosition != null) {
          _controller.seekTo(widget.initialPosition!);
        }
        setState(() {
          _totalDuration = _controller.value.duration;
        });
        _controller.play();
        _controller.addListener(_updateProgress);
        _controller.addListener(_updateWatchHistory);
      });
  }

  void _updateProgress() {
    if (mounted) {
      setState(() {
        _currentPosition = _controller.value.position;
      });
    }
  }

  void _updateWatchHistory() {
    if (!_controller.value.isInitialized || !_controller.value.isPlaying) {
      return;
    }
    _saveWatchHistory();
  }

  Future<void> _saveWatchHistory() async {
    final position = _controller.value.position;
    print('Saving watch history: ${widget.videoPath}, position: $position');

    try {
      await WatchHistoryService.addHistory(WatchHistory(
        videoPath: widget.videoPath,
        videoTitle: widget.videoPath.split('/').last,
        position: position,
        lastWatched: DateTime.now(),
        thumbnailPath: null,
      ));
      print('Watch history saved successfully');
    } catch (e) {
      print('Error saving watch history: $e');
    }
  }

  Future<void> _toggleFullScreen() async {
    if (_isFullScreen) {
      // 退出全屏
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ]);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      // 进入全屏
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    setState(() => _isFullScreen = !_isFullScreen);
  }

  @override
  void dispose() {
    // 恢复原始方向和系统UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _controller.removeListener(_updateProgress);
    _controller.removeListener(_updateWatchHistory); // 移除播放历史记录监听
    _controller.dispose();
    _saveWatchHistory(); // 退出时保存播放历史
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : '';
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours$minutes:$seconds';
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _volume = _isMuted ? 0.0 : 1.0;
      _controller.setVolume(_volume);
    });
  }

  void _changeSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _controller.setPlaybackSpeed(speed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
        title: Text(widget.videoPath.split('/').last),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),

            if (_showControls) ...[
              // 半透明背景层
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // 中央播放/暂停按钮
              Positioned(
                child: IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    size: 60,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                ),
              ),

              // 顶部控制栏（全屏按钮）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 全屏按钮
                      IconButton(
                        icon: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullScreen,
                      ),
                    ],
                  ),
                ),
              ),

              // 底部控制栏
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 进度条
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.red,
                          inactiveTrackColor: Colors.grey[700],
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                        ),
                        child: Slider(
                          min: 0,
                          max: _totalDuration.inMilliseconds.toDouble(),
                          value: _currentPosition.inMilliseconds
                              .toDouble()
                              .clamp(
                              0, _totalDuration.inMilliseconds.toDouble()),
                          onChanged: (value) {
                            setState(() {
                              _currentPosition =
                                  Duration(milliseconds: value.toInt());
                            });
                            _controller.seekTo(_currentPosition);
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 控制按钮行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 播放/暂停按钮
                          IconButton(
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_controller.value.isPlaying) {
                                  _controller.pause();
                                } else {
                                  _controller.play();
                                }
                              });
                            },
                          ),

                          // 音量控制
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isMuted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleMute,
                              ),
                              SizedBox(
                                width: 100,
                                child: Slider(
                                  value: _volume,
                                  min: 0,
                                  max: 1,
                                  onChanged: (value) {
                                    setState(() {
                                      _volume = value;
                                      _isMuted = value == 0;
                                      _controller.setVolume(_volume);
                                    });
                                  },
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),

                          // 倍速选择
                          PopupMenuButton<double>(
                            icon: const Icon(Icons.speed, color: Colors.white),
                            itemBuilder: (context) => _playbackSpeeds
                                .map((speed) => PopupMenuItem<double>(
                              value: speed,
                              child: Text(
                                '${speed}x',
                                style: TextStyle(
                                  fontWeight: _playbackSpeed == speed
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ))
                                .toList(),
                            onSelected: _changeSpeed,
                          ),

                          // 时间显示
                          Text(
                            '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      )
          : const Center(
        child: CircularProgressIndicator(color: Colors.red),
      ),
    );
  }
}