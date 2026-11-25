
import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/infrastructure/http_client_pack_download_service.dart';

void main() {
  late Directory downloadDirectory;
  late HttpClientPackDownloadService service;

  setUp(() async {
    downloadDirectory =
        await Directory.systemTemp.createTemp('qrjukebox_test_');

    service = HttpClientPackDownloadService(
      downloadDirectory: downloadDirectory,
    );
  });

  tearDown(() async {
    if (await downloadDirectory.exists()) {
      await downloadDirectory.delete(recursive: true);
    }
  });

  Future<void> expectDownloadDirectoryEmpty() async {
    final contents = await downloadDirectory.list().toList();
    expect(contents, isEmpty);
  }

  Future<void> withServer({
    required int statusCode,
    required List<int> body,
    required Future<void> Function(Uri url) callback,
  }) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );

    server.listen((request) async {
      request.response.statusCode = statusCode;
      request.response.add(body);
      await request.response.close();
    });

    final url = Uri.parse(
      'http://${server.address.address}:${server.port}/packs/mozart.qrj',
    );

    try {
      await callback(url);
    } finally {
      await server.close(force: true);
    }
  }

  group('HttpClientPackDownloadService', () {
    test('downloads and saves a pack', () async {
      final content = utf8.encode('fake audio pack');

      await withServer(
        statusCode: HttpStatus.ok,
        body: content,
        callback: (url) async {
          final result = await service.download(url);

          expect(result.path, endsWith('mozart.qrj'));
          expect(await result.exists(), isTrue);
          expect(await result.readAsBytes(), content);

          final files = await downloadDirectory.list().toList();
          expect(files, hasLength(1));
          expect(files.single.path, result.path);
        },
      );
    });

    test('throws for an invalid URL', () async {
      final url = Uri.parse('ftp://example.org/mozart.qrj');

      expect(
        () => service.download(url),
        throwsFormatException,
      );

      await expectDownloadDirectoryEmpty();
    });

    test('throws for an invalid pack ID', () async {
      final url = Uri.parse('http://example.org/packs/.qrj');

      expect(
        () => service.download(url),
        throwsFormatException,
      );

      await expectDownloadDirectoryEmpty();
    });

    test('throws when HTTP response is not successful', () async {
      await withServer(
        statusCode: HttpStatus.notFound,
        body: utf8.encode('Not found'),
        callback: (url) async {
          await expectLater(
            service.download(url),
            throwsA(isA<HttpException>()),
          );

          await expectDownloadDirectoryEmpty();
        },
      );
    });

    test('throws when downloaded pack is empty', () async {
      await withServer(
        statusCode: HttpStatus.ok,
        body: [],
        callback: (url) async {
          await expectLater(
            service.download(url),
            throwsA(isA<HttpException>()),
          );

          await expectDownloadDirectoryEmpty();
        },
      );
    });
  });
}
