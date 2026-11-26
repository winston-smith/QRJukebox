import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:qr_jukebox/domain/entities/installed_pack.dart';
import 'package:qr_jukebox/services/pack_download_service.dart';
import 'package:qr_jukebox/services/pack_install_service.dart';
import 'package:qr_jukebox/infrastructure/pack_metadata.dart';


class DefaultPackInstallService implements PackInstallService {
  final PackDownloadService downloadService;
  final Directory packsDirectory;

  static const defaultMaxArchiveSize = 1 << 30; // 1 GiB
  static const defaultMaxFileCount = 500;
  static const defaultMaxExtractedSize = 2 << 30; // 2 GiB
  static const defaultMaxFileSize = 100 << 20; // 100 MiB

  final int maxArchiveSize;
  final int maxFileCount;
  final int maxExtractedSize;
  final int maxFileSize;

  DefaultPackInstallService({
    required this.downloadService,
    required this.packsDirectory,
    this.maxArchiveSize = defaultMaxArchiveSize,
    this.maxFileCount = defaultMaxFileCount,
    this.maxExtractedSize = defaultMaxExtractedSize,
    this.maxFileSize = defaultMaxFileSize,
  });

  @override
  Future<InstalledPack> install({
    required Uri url,
    required String expectedChecksum,
    required String password,
  }) async {
    final id = _getPackId(url);

    final stagingDirectory = await _createStagingDirectory(id);

    final archiveFile = await downloadService.download(url);
    final archiveSize = await archiveFile.length();

    try {
      if (archiveSize > maxArchiveSize) {
        throw FormatException('Pack archive exceeds maximum size');
      }

      await _verifyChecksum(archiveFile, expectedChecksum);
      await _extractArchive(
        archiveFile,
        stagingDirectory,
        password,
      );

      await _writePackMetadata(
        directory: stagingDirectory,
        id: id,
        sourceUrl: url,
      );

      final destination = Directory(
        p.join(packsDirectory.path, id),
      );

      if (await destination.exists()) {
        throw FileSystemException(
          'Pack is already installed',
          destination.path,
        );
      }
      await stagingDirectory.rename(destination.path);

      return InstalledPack(
        id: id,
        name: id,
        directory: destination.path,
        sourceUrl: url,
      );
    } catch (_) {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      rethrow;
    } finally {
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }
    }
  }

  String _getPackId(Uri url) {
    final filename = p.basename(url.path);

    if (!filename.endsWith('.qrj')) {
      throw FormatException('Invalid pack URL: $url');
    }

    return filename.substring(0, filename.length - 4);
  }

  Future<Directory> _createStagingDirectory(String id) async {
    await packsDirectory.create(recursive: true);

    final stagingDirectory = await packsDirectory.createTemp(
      '.$id-install-',
    );

    return stagingDirectory;
  }

  Future<void> _verifyChecksum(
    File archiveFile,
    String expectedChecksum,
  ) async {
    final bytes = await archiveFile.readAsBytes();
    final digest = sha256.convert(bytes);

    final checksum = base64Url
        .encode(digest.bytes.sublist(0, 16))
        .replaceAll('=', '');

    if (checksum != expectedChecksum) {
      throw FormatException('Pack checksum mismatch');
    }
  }

  Future<void> _extractArchive(
    File archiveFile,
    Directory destination,
    String password,
  ) async {
    final input = InputFileStream(archiveFile.path);

    try {
      final archive = ZipDecoder().decodeStream(
        input,
        password: password,
        verify: true,
      );

      final destinationPath = p.normalize(
        p.absolute(destination.path),
      );

      var fileCount = 0;
      var extractedSize = 0;

      for (final entry in archive) {
        if (entry.isSymbolicLink) {
          throw FormatException(
            'Symbolic links are not allowed: ${entry.name}',
          );
        }

        // ZIP-Einträge verwenden / als Pfadtrenner.
        // Backslashes und NUL-Bytes lehnen wir ebenfalls ab.
        if (entry.name.contains('\\') ||
            entry.name.contains('\u0000')) {
          throw FormatException(
            'Invalid path in pack archive: ${entry.name}',
          );
        }

        final outputPath = p.normalize(
          p.join(destinationPath, entry.name),
        );

        if (p.isAbsolute(entry.name) ||
            (outputPath != destinationPath &&
                !p.isWithin(destinationPath, outputPath))) {
          throw FormatException(
            'Invalid path in pack archive: ${entry.name}',
          );
        }

        if (entry.isFile) {
          fileCount++;

          if (fileCount > maxFileCount) {
            throw FormatException(
              'Pack contains too many files',
            );
          }

          if (entry.size > maxFileSize) {
            throw FormatException(
              'Pack contains an oversized file: ${entry.name}',
            );
          }

          extractedSize += entry.size;

          if (extractedSize > maxExtractedSize) {
            throw FormatException(
              'Pack exceeds maximum extracted size',
            );
          }

          final outputFile = File(outputPath);
          await outputFile.parent.create(recursive: true);

          final output = OutputFileStream(outputFile.path);

          try {
            entry.writeContent(output);
          } finally {
            output.closeSync();
          }
        } else {
          await Directory(outputPath).create(recursive: true);
        }
      }
    } finally {
      input.closeSync();
    }
  }

  Future<void> _writePackMetadata({
    required Directory directory,
    required String id,
    required Uri sourceUrl,
  }) async {
    final metadataFile = File(
      p.join(directory.path, packMetadataFileName),
    );

    await metadataFile.writeAsString(
      jsonEncode({
        'id': id,
        'name': id,
        'sourceUrl': sourceUrl.toString(),
      }),
    );
  }
}
