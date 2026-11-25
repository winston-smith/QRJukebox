
import 'dart:io';

import '../services/pack_download_service.dart';

typedef HttpClientFactory = HttpClient Function();

class HttpClientPackDownloadService implements PackDownloadService {
  final Directory downloadDirectory;
  final HttpClientFactory httpClientFactory;

  HttpClientPackDownloadService({
    required this.downloadDirectory,
    HttpClientFactory? httpClientFactory,
  }) : httpClientFactory = httpClientFactory ?? HttpClient.new;

  @override
  Future<File> download(Uri url) async {
    _validateUrl(url);

    final filename = url.pathSegments.last;
    final packId = filename.substring(0, filename.length - 4);

    if (!_isValidPackId(packId)) {
      throw FormatException('Invalid pack ID: $packId');
    }

    await downloadDirectory.create(recursive: true);

    final separator = Platform.pathSeparator;
    final targetFile = File(
      '${downloadDirectory.path}$separator$filename',
    );

    final temporaryFile = File(
      '${downloadDirectory.path}$separator'
      '.$packId-${DateTime.now().microsecondsSinceEpoch}.part',
    );

    final client = httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw HttpException(
          'Pack download failed with HTTP '
          '${response.statusCode}',
          uri: url,
        );
      }

      await response.pipe(temporaryFile.openWrite());

      if (await temporaryFile.length() == 0) {
        throw HttpException(
          'Downloaded pack is empty',
          uri: url,
        );
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      return await temporaryFile.rename(targetFile.path);
    } catch (_) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void _validateUrl(Uri url) {
    if (url.scheme != 'https' && url.scheme != 'http') {
      throw FormatException(
        'Unsupported pack URL scheme: ${url.scheme}',
      );
    }

    if (url.host.isEmpty || url.pathSegments.isEmpty) {
      throw FormatException('Invalid pack URL: $url');
    }

    final filename = url.pathSegments.last;

    if (!filename.toLowerCase().endsWith('.qrj')) {
      throw FormatException(
        'Pack URL must point to a .qrj file',
      );
    }
  }

  bool _isValidPackId(String id) {
    return id.isNotEmpty &&
        id != '.' &&
        id != '..' &&
        RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$')
            .hasMatch(id);
  }
}
