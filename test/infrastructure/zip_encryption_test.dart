import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZIP AES-256 encryption', () {
    final archiveFile = File('test/fixtures/test_aes256.qrj');

    test('decrypts an AES-256 encrypted archive', () async {
      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(
        bytes,
        password: 'TestPassword123',
      );

      expect(archive, hasLength(1));
      expect(archive.first.name, 'test.txt');
      expect(
        String.fromCharCodes(archive.first.content as List<int>),
        'QRJukebox AES-256 test\n',
      );
    });

    test('rejects an incorrect password', () async {
      final bytes = await archiveFile.readAsBytes();

      final archive = ZipDecoder().decodeBytes(
        bytes,
        password: 'WrongPassword',
      );

      expect(
        () => archive.first.content,
        throwsA(isA<ArchivePasswordException>()),
      );
    });

  });
}
