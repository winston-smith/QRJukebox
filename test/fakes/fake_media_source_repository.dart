import 'package:qr_jukebox/domain/entities/media_source.dart';
import 'package:qr_jukebox/domain/repositories/media_source_repository.dart';

class FakeMediaSourceRepository implements MediaSourceRepository {
  MediaSource? activeSource;

  @override
  Future<MediaSource?> getActive() async => activeSource;

  @override
  Future<void> activate(MediaSource source) async {
    activeSource = source;
  }
}
