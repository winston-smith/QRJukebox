import 'dart:async';
import 'dart:io';

import 'package:qr_jukebox/domain/services/pack_storage.dart';

class FakePackStorage implements PackStorage {
  final Completer<Directory> completer = Completer<Directory>();

  @override
  Future<Directory> getPacksDirectory() {
    return completer.future;
  }
}

