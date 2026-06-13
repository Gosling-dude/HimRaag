// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_recently_played.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveRecentlyPlayedAdapter extends TypeAdapter<HiveRecentlyPlayed> {
  @override
  final int typeId = 2;

  @override
  HiveRecentlyPlayed read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveRecentlyPlayed(
      songId: fields[0] as String,
      songTitle: fields[1] as String,
      artistName: fields[2] as String,
      artworkUrl: fields[3] as String,
      playedAt: fields[4] as DateTime,
      audioUrl: fields[5] as String?,
      localPath: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveRecentlyPlayed obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.songId)
      ..writeByte(1)
      ..write(obj.songTitle)
      ..writeByte(2)
      ..write(obj.artistName)
      ..writeByte(3)
      ..write(obj.artworkUrl)
      ..writeByte(4)
      ..write(obj.playedAt)
      ..writeByte(5)
      ..write(obj.audioUrl)
      ..writeByte(6)
      ..write(obj.localPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveRecentlyPlayedAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
