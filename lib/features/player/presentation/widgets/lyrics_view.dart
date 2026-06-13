import 'package:flutter/material.dart';

class LyricsView extends StatelessWidget {
  const LyricsView({super.key, this.lyrics});

  final String? lyrics;

  @override
  Widget build(BuildContext context) {
    if (lyrics == null || lyrics!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined,
                color: Colors.white.withValues(alpha: 0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'Lyrics not available',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Text(
        lyrics!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 2.0,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
