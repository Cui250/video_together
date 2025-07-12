// services/watch_history_service.dart
import 'package:hive/hive.dart';
import '../models/watch_history.dart';

class WatchHistoryService {
  static const String _boxName = 'watchHistory';

  static Future<Box<WatchHistory>> get _box async {
    return await Hive.openBox<WatchHistory>(_boxName);
  }

  static Future<void> addHistory(WatchHistory history) async {
    final box = await _box;
    await box.put(history.videoPath, history);
  }

  static Future<List<WatchHistory>> getAllHistory() async {
    final box = await _box;
    return box.values.toList()
      ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
  }

  static Future<void> clearAll() async {
    final box = await _box;
    await box.clear();
  }

  static Future<void> removeHistory(String videoPath) async {
    final box = await _box;
    await box.delete(videoPath);
  }
}