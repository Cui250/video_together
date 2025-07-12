// services/playlist_service.dart
import 'package:hive/hive.dart';
import '../models/playlist.dart';

class PlaylistService {
  static const String _boxName = 'playlists';

  static Future<Box<Playlist>> get _box async {
    return await Hive.openBox<Playlist>(_boxName);
  }

  static Future<List<Playlist>> getAllPlaylists() async {
    final box = await _box;
    return box.values.toList();
  }

  static Future<Playlist?> getPlaylist(String id) async {
    final box = await _box;
    return box.get(id);
  }

  static Future<void> savePlaylist(Playlist playlist) async {
    final box = await _box;
    await box.put(playlist.id, playlist);
  }

  static Future<void> deletePlaylist(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  static Future<void> addToPlaylist({
    required String playlistId,
    required PlaylistItem item,
  }) async {
    final playlist = await getPlaylist(playlistId);
    if (playlist != null) {
      playlist.items.add(item);
      await savePlaylist(playlist);
    }
  }

  static Future<void> removeFromPlaylist({
    required String playlistId,
    required String videoPath,
  }) async {
    final playlist = await getPlaylist(playlistId);
    if (playlist != null) {
      playlist.items.removeWhere((item) => item.videoPath == videoPath);
      await savePlaylist(playlist);
    }
  }
}