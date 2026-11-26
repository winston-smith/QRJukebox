import 'package:qr_jukebox/domain/entities/installed_pack.dart';

abstract interface class InstalledPackRepository {
  Future<List<InstalledPack>> getAll();

  Future<InstalledPack?> getById(String id);

  Future<void> delete(String id);
}
