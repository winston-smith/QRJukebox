import 'dart:async';

import 'package:qr_jukebox/services/audio_playback_service.dart';

class FakeAudioPlaybackService implements AudioPlaybackService {
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  final List<Completer<void>> playCompleters = [];
  final List<String> playedFiles = [];
  final List<Duration> playPositions = [];

  int pauseCalls = 0;
  int resumeCalls = 0;
  int seekCalls = 0;
  Duration? lastSeekPosition;

  @override
  Stream<bool> get playing => _playingController.stream;

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Stream<Duration> get duration => _durationController.stream;

  @override
  Stream<void> get completed => _completedController.stream;

  @override
  Future<void> play(
    String filePath, {
    Duration position = Duration.zero,
  }) async {
    playedFiles.add(filePath);
    playPositions.add(position);

    final completer = Completer<void>();
    playCompleters.add(completer);

    await completer.future;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playingController.add(false);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls++;
    lastSeekPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
  }
}
