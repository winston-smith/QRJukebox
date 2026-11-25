import 'dart:io';

abstract interface class PackDownloadService {
  Future<File> download(Uri url);
}
