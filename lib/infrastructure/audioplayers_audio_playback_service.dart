import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:qr_jukebox/services/audio_playback_service.dart';

typedef AudioPlayerFactory = AudioPlayer Function();

class AudioplayersAudioPlaybackService implements AudioPlaybackService{
  final AudioPlayerFactory _createPlayer;
  
  AudioplayersAudioPlaybackService(
    this._createPlayer,
  );

  AudioPlayer? _player;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completedSubscription;

  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _completedController = StreamController<void>.broadcast();

  void _initializePlayer() {
    if (_player != null) return;

    final player = _createPlayer();
    _player = player;

    _playerStateSubscription =
        player.onPlayerStateChanged.listen((state) {
      _playingController.add(state == PlayerState.playing);
    });

    _positionSubscription =
        player.onPositionChanged.listen(_positionController.add);

    _durationSubscription =
        player.onDurationChanged.listen(_durationController.add);

    _completedSubscription =
        player.onPlayerComplete.listen((_) {
      _playingController.add(false);
      _completedController.add(null);
    });
  }

  @override
  Stream<void> get completed => _completedController.stream;

  @override
  Future<void> dispose() async {
    await _disposePlayer();

    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
  }

  @override
  Stream<Duration> get duration => _durationController.stream;

  @override
  Future<void> play(
    String filePath, {
    Duration position = Duration.zero,
  }) async {
    _initializePlayer();

    try {
      await _player!.play(
        DeviceFileSource(filePath),
        position: position,
      );
    } catch (_) {
      await _disposePlayer();
      rethrow;
    }
  }

  @override
  Stream<bool> get playing => _playingController.stream;

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> resume() async {
    await _player?.resume();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  Future<void> _disposePlayer() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _completedSubscription?.cancel();

    _playerStateSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;
    _completedSubscription = null;

    final player = _player;
    _player = null;

    await player?.dispose();
  }
}
