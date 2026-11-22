abstract interface class AudioPlaybackService {
  Future<void> play(
    String filePath, {
    Duration position = Duration.zero,
  });

  Future<void> pause();

  Future<void> resume();

  Future<void> seek(Duration position);

  Future<void> stop();

  Stream<bool> get playing;

  Stream<Duration> get position;

  Stream<Duration> get duration;

  Stream<void> get completed;

  Future<void> dispose();
}
