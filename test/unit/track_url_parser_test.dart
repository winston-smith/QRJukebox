import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/utils/track_url_parser.dart';

void main() {
  group('parseUrl', () {
    test('parses a URL without protocol', () {
      final result = parseUrl('example.com/de/aaaa0015/00015');

      expect(result, isNotNull);
      expect(result!.host, 'example.com');
      expect(result.folders, ['de', 'aaaa0015']);
      expect(result.trackId, '00015');
    });

    test('parses a URL with https protocol', () {
      final result = parseUrl('https://example.com/de/aaaa0015/00015');

      expect(result, isNotNull);
      expect(result!.host, 'example.com');
      expect(result.folders, ['de', 'aaaa0015']);
      expect(result.trackId, '00015');
    });

    test('returns null if there are not enough path segments', () {
      expect(parseUrl('example.com'), isNull);
      expect(parseUrl('example.com/00015'), isNull);
    });

    test('returns null for an invalid URL', () {
      expect(parseUrl('http://[invalid'), isNull);
    });
  });
}