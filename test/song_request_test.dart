import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/features/requests/song_request_sheet.dart';

void main() {
  group('isValidRequestLink', () {
    test('accepts empty (the link is optional)', () {
      expect(isValidRequestLink(''), isTrue);
      expect(isValidRequestLink('   '), isTrue);
    });

    test('accepts links with or without a scheme', () {
      expect(isValidRequestLink('https://youtu.be/abc123'), isTrue);
      expect(isValidRequestLink('youtube.com/watch?v=abc123'), isTrue);
    });

    test('rejects text that is not a link', () {
      expect(isValidRequestLink('bedu pako'), isFalse);
      expect(isValidRequestLink('youtube'), isFalse);
    });
  });
}
