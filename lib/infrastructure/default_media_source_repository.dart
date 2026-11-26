import 'package:qr_jukebox/domain/entities/media_source.dart';
import 'package:qr_jukebox/domain/repositories/media_source_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DefaultMediaSourceRepository implements MediaSourceRepository {
  static const _typeKey = 'mediaSourceType';
  static const _valueKey = 'mediaSourceValue';
  static const _legacyPathKey = 'mediaRootPath';

  final SharedPreferences prefs;

  DefaultMediaSourceRepository({
    required this.prefs,
  });

  @override
  Future<MediaSource?> getActive() async {
    final type = prefs.getString(_typeKey);
    final value = prefs.getString(_valueKey);

    if (type == null) {
      return _migrateLegacyPreference();
    }

    if (value == null || value.isEmpty) {
      return null;
    }

    return switch (type) {
      'customDirectory' => CustomDirectoryMediaSource(
          directory: value,
        ),
      'installedPack' => InstalledPackMediaSource(
          packId: value,
        ),
      _ => null,
    };
  }

  @override
  Future<void> activate(MediaSource source) async {
    final (type, value) = switch (source) {
      CustomDirectoryMediaSource(:final directory) => (
          'customDirectory',
          directory
        ),
      InstalledPackMediaSource(:final packId) => ('installedPack', packId),
    };

    await prefs.setString(_valueKey, value);
    await prefs.setString(_typeKey, type);
  }

  Future<MediaSource?> _migrateLegacyPreference() async {
    final legacyPath = prefs.getString(_legacyPathKey);

    if (legacyPath == null || legacyPath.isEmpty) {
      return null;
    }

    final source = CustomDirectoryMediaSource(
      directory: legacyPath,
    );

    await activate(source);

    return source;
  }
}
