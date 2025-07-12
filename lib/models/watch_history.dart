// models/watch_history.dart
import 'package:hive/hive.dart';

part 'watch_history.g.dart';

@HiveType(typeId: 0)
class WatchHistory {
  @HiveField(0)
  final String videoPath;

  @HiveField(1)
  final String videoTitle;

  @HiveField(2)
  final Duration position;

  @HiveField(3)
  final DateTime lastWatched;

  @HiveField(4)
  final String? thumbnailPath;

  WatchHistory({
    required this.videoPath,
    required this.videoTitle,
    required this.position,
    required this.lastWatched,
    this.thumbnailPath,
  });
}