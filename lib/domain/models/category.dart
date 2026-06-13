import 'package:equatable/equatable.dart';

class MusicCategory extends Equatable {
  const MusicCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconUrl,
    required this.gradientColors,
    required this.songCount,
    this.type = CategoryType.genre,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconUrl;
  final List<String> gradientColors;
  final int songCount;
  final CategoryType type;

  @override
  List<Object?> get props =>
      [id, title, subtitle, iconUrl, gradientColors, songCount, type];
}

enum CategoryType { genre, mood, festival, region, season }
