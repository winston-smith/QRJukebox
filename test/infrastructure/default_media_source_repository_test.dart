import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/domain/entities/media_source.dart';
import 'package:qr_jukebox/infrastructure/default_media_source_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late DefaultMediaSourceRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    prefs = await SharedPreferences.getInstance();

    repository = DefaultMediaSourceRepository(
      prefs: prefs,
    );
  });

  group('getActive', () {
    test('returns null if no media source is configured', () async {
      expect(await repository.getActive(), isNull);
    });

    test('returns a custom directory', () async {
      SharedPreferences.setMockInitialValues({
        'mediaSourceType': 'customDirectory',
        'mediaSourceValue': '/music',
      });

      prefs = await SharedPreferences.getInstance();
      repository = DefaultMediaSourceRepository(prefs: prefs);

      final source = await repository.getActive();

      expect(
        source,
        isA<CustomDirectoryMediaSource>()
            .having((s) => s.directory, 'directory', '/music'),
      );
    });

    test('returns an installed pack', () async {
      SharedPreferences.setMockInitialValues({
        'mediaSourceType': 'installedPack',
        'mediaSourceValue': 'mozart',
      });

      prefs = await SharedPreferences.getInstance();
      repository = DefaultMediaSourceRepository(prefs: prefs);

      final source = await repository.getActive();

      expect(
        source,
        isA<InstalledPackMediaSource>()
            .having((s) => s.packId, 'packId', 'mozart'),
      );
    });

    test('returns null for an unknown source type', () async {
      SharedPreferences.setMockInitialValues({
        'mediaSourceType': 'unknown',
        'mediaSourceValue': 'something',
      });

      prefs = await SharedPreferences.getInstance();
      repository = DefaultMediaSourceRepository(prefs: prefs);

      expect(await repository.getActive(), isNull);
    });

    test('returns null if source value is missing', () async {
      SharedPreferences.setMockInitialValues({
        'mediaSourceType': 'customDirectory',
      });

      prefs = await SharedPreferences.getInstance();
      repository = DefaultMediaSourceRepository(prefs: prefs);

      expect(await repository.getActive(), isNull);
    });

    test('migrates the legacy mediaRootPath preference', () async {
      SharedPreferences.setMockInitialValues({
        'mediaRootPath': '/old/music',
      });

      prefs = await SharedPreferences.getInstance();
      repository = DefaultMediaSourceRepository(prefs: prefs);

      final source = await repository.getActive();

      expect(
        source,
        isA<CustomDirectoryMediaSource>().having(
          (s) => s.directory,
          'directory',
          '/old/music',
        ),
      );

      expect(prefs.getString('mediaSourceType'), 'customDirectory');
      expect(prefs.getString('mediaSourceValue'), '/old/music');
    });

    test('does not migrate an empty legacy path', () async {
      SharedPreferences.setMockInitialValues({
        'mediaRootPath': '',
      });

      prefs = await SharedPreferences.getInstance();
      repository = DefaultMediaSourceRepository(prefs: prefs);

      expect(await repository.getActive(), isNull);
      expect(prefs.getString('mediaSourceType'), isNull);
    });
  });

  group('activate', () {
    test('stores a custom directory', () async {
      await repository.activate(
        const CustomDirectoryMediaSource(
          directory: '/music',
        ),
      );

      expect(prefs.getString('mediaSourceType'), 'customDirectory');
      expect(prefs.getString('mediaSourceValue'), '/music');
    });

    test('stores an installed pack', () async {
      await repository.activate(
        const InstalledPackMediaSource(
          packId: 'mozart',
        ),
      );

      expect(prefs.getString('mediaSourceType'), 'installedPack');
      expect(prefs.getString('mediaSourceValue'), 'mozart');
    });

    test('replaces the previously active source', () async {
      await repository.activate(
        const CustomDirectoryMediaSource(
          directory: '/music',
        ),
      );

      await repository.activate(
        const InstalledPackMediaSource(
          packId: 'mozart',
        ),
      );

      final source = await repository.getActive();

      expect(source, isA<InstalledPackMediaSource>());
      expect(
        (source as InstalledPackMediaSource).packId,
        'mozart',
      );
    });
  });
}
