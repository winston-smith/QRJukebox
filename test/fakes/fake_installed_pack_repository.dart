import 'package:qr_jukebox/domain/entities/installed_pack.dart';
import 'package:qr_jukebox/domain/repositories/installed_pack_repository.dart';

class FakeInstalledPackRepository implements InstalledPackRepository {
  final List<InstalledPack> packs = [];

  @override
  Future<List<InstalledPack>> getAll() async => packs;

  @override
  Future<InstalledPack?> getById(String id) async {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  @override
  Future<void> delete(String id) async {
    packs.removeWhere((pack) => pack.id == id);
  }
}
