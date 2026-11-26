import 'dart:io';

abstract interface class PackStorage {
  Future<Directory> getPacksDirectory();
}
