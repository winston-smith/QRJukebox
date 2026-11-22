import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';

class AppVersion {
  static String _version = 'dev${AppConfig.versionSuffix}';

  static Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _version = '${packageInfo.version}${AppConfig.versionSuffix}';
    } catch (_) {
      // Keep the fallback version if package information is unavailable.
    }
  }

  static String get version => _version;
}
