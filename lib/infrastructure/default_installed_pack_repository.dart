import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qr_jukebox/domain/entities/installed_pack.dart';
import 'package:qr_jukebox/domain/repositories/installed_pack_repository.dart';

class DefaultInstalledPackRepository
    implements InstalledPackRepository {
  final Directory packsDirectory;

  DefaultInstalledPackRepository({
    required this.packsDirectory,
  });

  @override
  Future<List<InstalledPack>> getAll() async {
    if (!await packsDirectory.exists()) {
      return [];
    }

    final packs = <InstalledPack>[];

    await for (final entity in packsDirectory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }

      final pack = await _readPack(entity);

      if (pack != null) {
        packs.add(pack);
      }
    }

    return packs;
  }

  @override
  Future<InstalledPack?> getById(String id) async {
    if (!_isValidId(id)) {
      return null;
    }

    final directory = Directory(
      p.join(packsDirectory.path, id),
    );

    if (!await directory.exists()) {
      return null;
    }

    return _readPack(directory);
  }

  @override
  Future<void> delete(String id) async {
    if (!_isValidId(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid pack ID');
    }

    final directory = Directory(
      p.join(packsDirectory.path, id),
    );

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<InstalledPack?> _readPack(Directory directory) async {
    final metadataFile = File(
      p.join(directory.path, 'pack.json'),
    );

    if (!await metadataFile.exists()) {
      return null;
    }

    try {
      final json = jsonDecode(await metadataFile.readAsString())
          as Map<String, dynamic>;

      return InstalledPack(
        id: json['id'] as String,
        name: json['name'] as String,
        directory: directory.path,
        sourceUrl: Uri.parse(json['sourceUrl'] as String),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  bool _isValidId(String id) {
    return id.isNotEmpty &&
        p.basename(id) == id &&
        id != '.' &&
        id != '..' &&
        !id.contains('/') &&
        !id.contains(r'\');
  }
}
