import 'package:qr_jukebox/domain/entities/media_source.dart';

abstract interface class MediaSourceRepository {
  Future<MediaSource?> getActive();

  Future<void> activate(MediaSource source);
}
