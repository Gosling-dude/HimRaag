// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_download_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveDownloadTaskAdapter extends TypeAdapter<HiveDownloadTask> {
  @override
  final int typeId = 1;

  @override
  HiveDownloadTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveDownloadTask(
      songId: fields[0] as String,
      songTitle: fields[1] as String,
      audioUrl: fields[2] as String,
      artworkUrl: fields[3] as String,
      statusIndex: fields[4] as int,
      progress: fields[5] as double,
      localPath: fields[6] as String?,
      errorMessage: fields[7] as String?,
      startedAt: fields[8] as DateTime?,
      completedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveDownloadTask obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.songId)
      ..writeByte(1)
      ..write(obj.songTitle)
      ..writeByte(2)
      ..write(obj.audioUrl)
      ..writeByte(3)
      ..write(obj.artworkUrl)
      ..writeByte(4)
      ..write(obj.statusIndex)
      ..writeByte(5)
      ..write(obj.progress)
      ..writeByte(6)
      ..write(obj.localPath)
      ..writeByte(7)
      ..write(obj.errorMessage)
      ..writeByte(8)
      ..write(obj.startedAt)
      ..writeByte(9)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveDownloadTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
