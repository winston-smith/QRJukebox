
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/utils/url_parser.dart';

void main() {
  group('parseUrl', () {
    group('track URLs', () {
      test('parses a URL without protocol', () {
        final result = parseUrl('example.com/de/aaaa0015/00015');

        expect(result, isA<ParsedTrack>());

        final data = (result as ParsedTrack).data;
        expect(data.host, 'example.com');
        expect(data.folders, ['de', 'aaaa0015']);
        expect(data.trackId, '00015');
        expect(data.raw, 'example.com/de/aaaa0015/00015');
      });

      test('parses a URL with https protocol', () {
        final result = parseUrl(
          'https://example.com/de/aaaa0015/00015',
        );

        expect(result, isA<ParsedTrack>());

        final data = (result as ParsedTrack).data;
        expect(data.host, 'example.com');
        expect(data.folders, ['de', 'aaaa0015']);
        expect(data.trackId, '00015');
      });

      test('parses a URL with http protocol', () {
        final result = parseUrl(
          'http://example.com/de/aaaa0015/00015',
        );

        expect(result, isA<ParsedTrack>());
      });

      test('returns null if there are not enough path segments', () {
        expect(parseUrl('example.com'), isNull);
        expect(parseUrl('example.com/00015'), isNull);
      });
    });

    group('pack URLs', () {
      test('parses a pack URL', () {
        final result = parseUrl(
          'qrjukebox://pack?url=https%3A%2F%2Fexample.com%2Fpacks%2Fmozart.qrj',
        );

        expect(result, isA<ParsedPack>());

        final data = (result as ParsedPack).data;
        expect(
          data.url,
          Uri.parse('https://example.com/packs/mozart.qrj'),
        );
        expect(data.id, 'mozart');
      });

      test('returns null if pack URL is missing', () {
        expect(parseUrl('qrjukebox://pack'), isNull);
      });

      test('returns null if pack URL has an unsupported scheme', () {
        expect(
          parseUrl(
            'qrjukebox://pack?url=ftp%3A%2F%2Fexample.com%2Fmozart.qrj',
          ),
          isNull,
        );
      });

      test('returns null if pack filename has no qrj extension', () {
        expect(
          parseUrl(
            'qrjukebox://pack?url=https%3A%2F%2Fexample.com%2Fmozart.zip',
          ),
          isNull,
        );
      });

      test('returns null if pack filename is empty', () {
        expect(
          parseUrl(
            'qrjukebox://pack?url=https%3A%2F%2Fexample.com%2F.qrj',
          ),
          isNull,
        );
      });
    });

    group('invalid URLs', () {
      test('returns null for an invalid URL', () {
        expect(parseUrl('http://[invalid'), isNull);
      });

      test('returns null for unsupported URI schemes', () {
        expect(
          parseUrl('ftp://example.com/de/aaaa0015/00015'),
          isNull,
        );
        expect(
          parseUrl('mailto:test@example.com'),
          isNull,
        );
      });

      test('returns null for an unknown qrjukebox URI', () {
        expect(
          parseUrl('qrjukebox://unknown'),
          isNull,
        );
      });
    });
  });
}
