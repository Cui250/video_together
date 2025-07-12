// models/playlist.dart
import 'package:hive/hive.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final List<PlaylistItem> items;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.items,
  });
}

@HiveType(typeId: 2)
class PlaylistItem {
  @HiveField(0)
  final String videoPath;

  @HiveField(1)
  final String videoTitle;

  @HiveField(2)
  final String? thumbnailPath;

  @HiveField(3)
  final DateTime addedAt;

  PlaylistItem({
    required this.videoPath,
    required this.videoTitle,
    this.thumbnailPath,
    required this.addedAt,
  });
}