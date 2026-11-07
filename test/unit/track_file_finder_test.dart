import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/services/track_file_finder.dart';

void main() {
  group('findTrackFile', () {
    late Directory mediaRoot;

    setUp(() async {
      mediaRoot = await Directory.systemTemp.createTemp('qr_jukebox_test_');
    });

    tearDown(() async {
      if (await mediaRoot.exists()) {
        await mediaRoot.delete(recursive: true);
      }
    });

    test('finds a track in the expected folder structure', () async {
      final track = File(
        '${mediaRoot.path}/'
        'example.com/'
        'de_original-game-edition/'
        'aaaa0015_Superhits-Extension/'
        '00015_Song Title.mp3',
      );

      await track.create(recursive: true);

      final result = await findTrackFile(
        mediaRoot: mediaRoot.path,
        host: 'example.com',
        folders: ['de', 'aaaa0015'],
        trackId: '00015',
      );

      expect(result, isNotNull);
      expect(result!.path, track.path);
    });

    test('matches directory and file names case-insensitively', () async {
      final track = File(
        '${mediaRoot.path}/'
        'Example.COM/'
        'DE_original-game-edition/'
        '00015_Song Title.MP3',
      );

      await track.create(recursive: true);

      final result = await findTrackFile(
        mediaRoot: mediaRoot.path,
        host: 'example.com',
        folders: ['de'],
        trackId: '00015',
      );

      expect(result, isNotNull);
      expect(result!.path, track.path);
    });

    test('returns null if the media root does not exist', () async {
      final result = await findTrackFile(
        mediaRoot: '${mediaRoot.path}/non-existing',
        host: 'example.com',
        folders: ['de'],
        trackId: '00015',
      );

      expect(result, isNull);
    });

    test('returns null if the host folder does not exist', () async {
      final result = await findTrackFile(
        mediaRoot: mediaRoot.path,
        host: 'example.com',
        folders: ['de'],
        trackId: '00015',
      );

      expect(result, isNull);
    });

    test('returns null if the track does not exist', () async {
      final track = File(
        '${mediaRoot.path}/example.com/de/another-track.mp3',
      );

      await track.create(recursive: true);

      final result = await findTrackFile(
        mediaRoot: mediaRoot.path,
        host: 'example.com',
        folders: ['de'],
        trackId: '00015',
      );

      expect(result, isNull);
    });

    test('ignores files with unsupported extensions', () async {
      final track = File(
        '${mediaRoot.path}/example.com/de/00015_Song Title.ogg',
      );

      await track.create(recursive: true);

      final result = await findTrackFile(
        mediaRoot: mediaRoot.path,
        host: 'example.com',
        folders: ['de'],
        trackId: '00015',
      );

      expect(result, isNull);
    });
  });
}