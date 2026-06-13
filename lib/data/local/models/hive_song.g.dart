// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_song.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveSongAdapter extends TypeAdapter<HiveSong> {
  @override
  final int typeId = 0;

  @override
  HiveSong read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveSong(
      id: fields[0] as String,
      title: fields[1] as String,
      artistName: fields[2] as String,
      albumTitle: fields[3] as String,
      artworkUrl: fields[4] as String,
      localAudioPath: fields[5] as String,
      durationMs: fields[6] as int,
      region: fields[7] as String,
      language: fields[8] as String,
      genre: fields[9] as String,
      downloadedAt: fields[10] as DateTime,
      lyrics: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveSong obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artistName)
      ..writeByte(3)
      ..write(obj.albumTitle)
      ..writeByte(4)
      ..write(obj.artworkUrl)
      ..writeByte(5)
      ..write(obj.localAudioPath)
      ..writeByte(6)
      ..write(obj.durationMs)
      ..writeByte(7)
      ..write(obj.region)
      ..writeByte(8)
      ..write(obj.language)
      ..writeByte(9)
      ..write(obj.genre)
      ..writeByte(10)
      ..write(obj.downloadedAt)
      ..writeByte(11)
      ..write(obj.lyrics);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveSongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
