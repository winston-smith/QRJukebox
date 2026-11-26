
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qr_jukebox/infrastructure/default_installed_pack_repository.dart';
import 'package:qr_jukebox/infrastructure/pack_metadata.dart';

void main() {
  late Directory tempDirectory;
  late Directory packsDirectory;
  late DefaultInstalledPackRepository repository;

  const sourceUrl = 'https://example.org/mozart.qrj';

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'installed-pack-repository-test-',
    );

    packsDirectory = Directory(
      p.join(tempDirectory.path, 'packs'),
    );

    await packsDirectory.create();

    repository = DefaultInstalledPackRepository(
      packsDirectory: packsDirectory,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<Directory> createPack(
    String id, {
    String? name,
    String? url,
    bool writeMetadata = true,
  }) async {
    final directory = Directory(
      p.join(packsDirectory.path, id),
    );

    await directory.create();

    if (writeMetadata) {
      final metadataFile = File(
        p.join(directory.path, packMetadataFileName),
      );

      await metadataFile.writeAsString(
        jsonEncode({
          'id': id,
          'name': name ?? id,
          'sourceUrl': url ?? sourceUrl,
        }),
      );
    }

    return directory;
  }

  group('getAll', () {
    test('returns all installed packs', () async {
      await createPack('mozart');
      await createPack('hitster');

      final packs = await repository.getAll();

      expect(packs, hasLength(2));
      expect(
        packs.map((pack) => pack.id).toSet(),
        {'mozart', 'hitster'},
      );

      final mozart = packs.firstWhere(
        (pack) => pack.id == 'mozart',
      );

      expect(mozart.name, 'mozart');
      expect(mozart.sourceUrl, Uri.parse(sourceUrl));
      expect(
        mozart.directory,
        p.join(packsDirectory.path, 'mozart'),
      );
    });

    test('returns an empty list if packs directory does not exist', () async {
      await packsDirectory.delete();

      expect(await repository.getAll(), isEmpty);
    });

    test('ignores directories without metadata', () async {
      await createPack('mozart');
      await createPack('incomplete', writeMetadata: false);

      final packs = await repository.getAll();

      expect(packs, hasLength(1));
      expect(packs.single.id, 'mozart');
    });

    test('ignores invalid metadata', () async {
      await createPack('mozart');

      final invalidDirectory = await createPack(
        'invalid',
        writeMetadata: false,
      );

      await File(
        p.join(invalidDirectory.path, packMetadataFileName),
      ).writeAsString('{invalid json');

      final packs = await repository.getAll();

      expect(packs, hasLength(1));
      expect(packs.single.id, 'mozart');
    });
  });

  group('getById', () {
    test('returns an installed pack', () async {
      await createPack('mozart');

      final pack = await repository.getById('mozart');

      expect(pack, isNotNull);
      expect(pack!.id, 'mozart');
      expect(pack.name, 'mozart');
      expect(pack.sourceUrl, Uri.parse(sourceUrl));
    });

    test('returns null if pack does not exist', () async {
      expect(await repository.getById('unknown'), isNull);
    });

    test('returns null for an invalid ID', () async {
      expect(await repository.getById('../outside'), isNull);
    });

    test('returns null if metadata is missing', () async {
      await createPack('mozart', writeMetadata: false);

      expect(await repository.getById('mozart'), isNull);
    });
  });

  group('delete', () {
    test('deletes an installed pack recursively', () async {
      final directory = await createPack('mozart');

      final audioDirectory = Directory(
        p.join(directory.path, 'audio'),
      );

      await audioDirectory.create();

      await File(
        p.join(audioDirectory.path, 'track.mp3'),
      ).writeAsString('audio');

      await repository.delete('mozart');

      expect(await directory.exists(), isFalse);
    });

    test('does nothing if pack does not exist', () async {
      await expectLater(
        repository.delete('unknown'),
        completes,
      );
    });

    test('rejects an invalid ID', () async {
      expect(
        () => repository.delete('../outside'),
        throwsArgumentError,
      );
    });
  });
}

