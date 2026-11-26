import 'package:qr_jukebox/domain/entities/installed_pack.dart';

abstract interface class PackInstallService {
  Future<InstalledPack> install({
    required Uri url,
    required String expectedChecksum,
    required String password,
  });
}
