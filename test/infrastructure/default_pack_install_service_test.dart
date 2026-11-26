import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/domain/entities/installed_pack.dart';
import 'package:qr_jukebox/services/pack_download_service.dart';
import 'package:qr_jukebox/infrastructure/default_pack_install_service.dart';
import 'package:qr_jukebox/infrastructure/pack_metadata.dart';

void main() {
  group('DefaultPackInstallService', () {
    late Directory tempDirectory;
    late Directory packsDirectory;
    late File downloadedArchive;
    late FakePackDownloadService downloadService;
    late DefaultPackInstallService service;

    const packUrl = 'https://example.org/packs/test-pack.qrj';
    const password = 'TestPassword123';

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'qrjukebox-pack-install-test-',
      );
      packsDirectory = Directory('${tempDirectory.path}/packs');
      downloadedArchive = File('${tempDirectory.path}/download.qrj');

      downloadService = FakePackDownloadService(downloadedArchive);
      service = DefaultPackInstallService(
        downloadService: downloadService,
        packsDirectory: packsDirectory,
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    Future<void> writeArchive(List<int> bytes) async {
      await downloadedArchive.writeAsBytes(bytes);
    }

    Future<void> writeZip(Archive archive) async {
      await writeArchive(ZipEncoder().encode(archive));
    }

    Future<void> writeAesFixture() async {
      final fixture = File('test/fixtures/test_aes256.qrj');
      await writeArchive(await fixture.readAsBytes());
    }

    Future<InstalledPack> install({
      String checksum = '',
      String suppliedPassword = password,
      Uri? url,
    }) {
      return service.install(
        url: url ?? Uri.parse(packUrl),
        expectedChecksum: checksum.isEmpty
            ? checksumFor(downloadedArchive.readAsBytesSync())
            : checksum,
        password: suppliedPassword,
      );
    }

    test('installs an AES-256 encrypted pack', () async {
      await writeAesFixture();

      final installedPack = await install();

      expect(installedPack.id, 'test-pack');
      expect(installedPack.name, 'test-pack');
      expect(installedPack.sourceUrl, Uri.parse(packUrl));
      expect(installedPack.directory, '${packsDirectory.path}/test-pack');

      final extractedFile = File(
        '${installedPack.directory}/test.txt',
      );
      expect(await extractedFile.readAsString(), 'QRJukebox AES-256 test\n');
      expect(await downloadedArchive.exists(), isFalse);

      final metadataFile = File(
        p.join(installedPack.directory, packMetadataFileName),
      );

      expect(await metadataFile.exists(), isTrue);

      final metadata = jsonDecode(
        await metadataFile.readAsString(),
      ) as Map<String, dynamic>;

      expect(metadata['id'], 'test-pack');
      expect(metadata['name'], 'test-pack');
      expect(metadata['sourceUrl'], packUrl.toString());
    });

    test('rejects an incorrect password', () async {
      await writeAesFixture();

      await expectLater(
        install(suppliedPassword: 'WrongPassword'),
        throwsA(isA<ArchivePasswordException>()),
      );

      expect(await downloadedArchive.exists(), isFalse);
      expect(await _stagingDirectories(packsDirectory), isEmpty);
    });

    test('rejects a checksum mismatch', () async {
      await writeZip(
        Archive()..addFile(ArchiveFile.string('track.txt', 'audio data')),
      );

      await expectLater(
        install(checksum: 'not-the-right-checksum'),
        throwsA(isA<FormatException>()),
      );

      expect(await downloadedArchive.exists(), isFalse);
      expect(await _stagingDirectories(packsDirectory), isEmpty);
    });

    test('rejects an archive larger than maxArchiveSize', () async {
      await writeZip(
        Archive()..addFile(ArchiveFile.string('track.txt', 'audio data')),
      );

      service = DefaultPackInstallService(
        downloadService: downloadService,
        packsDirectory: packsDirectory,
        maxArchiveSize: 1,
      );

      await expectLater(
        install(),
        throwsA(isA<FormatException>()),
      );

      expect(await downloadedArchive.exists(), isFalse);
    });

    test('rejects an archive with too many files', () async {
      await writeZip(
        Archive()
          ..addFile(ArchiveFile.string('one.txt', '1'))
          ..addFile(ArchiveFile.string('two.txt', '2')),
      );

      service = DefaultPackInstallService(
        downloadService: downloadService,
        packsDirectory: packsDirectory,
        maxFileCount: 1,
      );

      await expectLater(
        install(),
        throwsA(isA<FormatException>()),
      );

      expect(await _stagingDirectories(packsDirectory), isEmpty);
    });

    test('rejects a file larger than maxFileSize', () async {
      await writeZip(
        Archive()
          ..addFile(ArchiveFile.string('large.txt', '123456789')),
      );

      service = DefaultPackInstallService(
        downloadService: downloadService,
        packsDirectory: packsDirectory,
        maxFileSize: 8,
      );

      await expectLater(
        install(),
        throwsA(isA<FormatException>()),
      );

      expect(await _stagingDirectories(packsDirectory), isEmpty);
    });

    test('rejects an archive exceeding maxExtractedSize', () async {
      await writeZip(
        Archive()
          ..addFile(ArchiveFile.string('one.txt', '123456'))
          ..addFile(ArchiveFile.string('two.txt', '789012')),
      );

      service = DefaultPackInstallService(
        downloadService: downloadService,
        packsDirectory: packsDirectory,
        maxExtractedSize: 10,
      );

      await expectLater(
        install(),
        throwsA(isA<FormatException>()),
      );

      expect(await _stagingDirectories(packsDirectory), isEmpty);
    });

    test('rejects paths escaping the destination directory', () async {
      await writeZip(
        Archive()
          ..addFile(ArchiveFile.string('../outside.txt', 'not allowed')),
      );

      await expectLater(
        install(),
        throwsA(isA<FormatException>()),
      );

      expect(File('${tempDirectory.path}/outside.txt').existsSync(), isFalse);
      expect(await _stagingDirectories(packsDirectory), isEmpty);
    });

    test('rejects symbolic links', () async {
      await writeZip(
        Archive()
          ..addFile(ArchiveFile.symlink('link', '../outside.txt')),
      );

      await expectLater(
        install(),
        throwsA(isA<FormatException>()),
      );

      expect(await _stagingDirectories(packsDirectory), isEmpty);
    });

    test('does not overwrite an already installed pack', () async {
      await writeZip(
        Archive()..addFile(ArchiveFile.string('track.txt', 'new content')),
      );

      final existingPackDirectory = Directory(
        '${packsDirectory.path}/test-pack',
      );
      await existingPackDirectory.create(recursive: true);
      final existingFile = File('${existingPackDirectory.path}/existing.txt');
      await existingFile.writeAsString('keep me');

      await expectLater(
        install(),
        throwsA(isA<FileSystemException>()),
      );

      expect(await existingFile.readAsString(), 'keep me');
      expect(await _stagingDirectories(packsDirectory), isEmpty);
      expect(await downloadedArchive.exists(), isFalse);
    });

    test('rejects URLs without a .qrj filename before downloading', () async {
      await expectLater(
        service.install(
          url: Uri.parse('https://example.org/packs/not-a-pack.zip'),
          expectedChecksum: 'irrelevant',
          password: password,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(downloadService.downloadCalls, 0);
    });

    test('cleans up the staging directory after extraction fails', () async {
      await writeAesFixture();

      await expectLater(
        install(suppliedPassword: 'WrongPassword'),
        throwsA(isA<ArchivePasswordException>()),
      );

      expect(await _stagingDirectories(packsDirectory), isEmpty);
      expect(await downloadedArchive.exists(), isFalse);
    });
  });
}

class FakePackDownloadService implements PackDownloadService {
  FakePackDownloadService(this.file);

  final File file;
  int downloadCalls = 0;

  @override
  Future<File> download(Uri url) async {
    downloadCalls++;
    return file;
  }
}

String checksumFor(List<int> bytes) {
  final digest = sha256.convert(bytes);
  return base64Url
      .encode(digest.bytes.sublist(0, 16))
      .replaceAll('=', '');
}

Future<List<Directory>> _stagingDirectories(Directory packsDirectory) async {
  if (!await packsDirectory.exists()) {
    return [];
  }

  return packsDirectory
      .listSync()
      .whereType<Directory>()
      .where((directory) => directory.basename.startsWith('.'))
      .toList();
}

extension on Directory {
  String get basename => path.split(Platform.pathSeparator).last;
}
