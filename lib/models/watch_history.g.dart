// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchHistoryAdapter extends TypeAdapter<WatchHistory> {
  @override
  final int typeId = 0;

  @override
  WatchHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchHistory(
      videoPath: fields[0] as String,
      videoTitle: fields[1] as String,
      position: fields[2] as Duration,
      lastWatched: fields[3] as DateTime,
      thumbnailPath: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WatchHistory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.videoPath)
      ..writeByte(1)
      ..write(obj.videoTitle)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.lastWatched)
      ..writeByte(4)
      ..write(obj.thumbnailPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
