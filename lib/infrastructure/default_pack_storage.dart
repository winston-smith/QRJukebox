import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_jukebox/domain/services/pack_storage.dart';

class DefaultPackStorage implements PackStorage {
  @override
  Future<Directory> getPacksDirectory() async {
    final appDirectory = await getApplicationSupportDirectory();

    final packsDirectory = Directory(
      p.join(appDirectory.path, 'packs'),
    );

    await packsDirectory.create(recursive: true);
    return packsDirectory;
  }
}
