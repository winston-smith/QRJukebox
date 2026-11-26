sealed class MediaSource {
  const MediaSource();
}

class CustomDirectoryMediaSource extends MediaSource {
  final String directory;

  const CustomDirectoryMediaSource({
    required this.directory,
  });
}

class InstalledPackMediaSource extends MediaSource {
  final String packId;

  const InstalledPackMediaSource({
    required this.packId,
  });
}
