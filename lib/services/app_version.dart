import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  static String _version = "dev";

  static Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _version = packageInfo.version;
    } catch (_) {
    }
  }
  static String get version => _version;
}
