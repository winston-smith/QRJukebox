import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:qr_jukebox/infrastructure/audioplayers_audio_playback_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class FakeSource extends Fake implements Source {}

void main() {
  late MockAudioPlayer mockPlayer;

  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration> positionController;
  late StreamController<Duration> durationController;
  late StreamController<void> completedController;

  setUpAll(() {
    registerFallbackValue(FakeSource());
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockPlayer = MockAudioPlayer();

    playerStateController = StreamController<PlayerState>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    completedController = StreamController<void>.broadcast();

    when(() => mockPlayer.onPlayerStateChanged)
        .thenAnswer((_) => playerStateController.stream);

    when(() => mockPlayer.onPositionChanged)
        .thenAnswer((_) => positionController.stream);

    when(() => mockPlayer.onDurationChanged)
        .thenAnswer((_) => durationController.stream);

    when(() => mockPlayer.onPlayerComplete)
        .thenAnswer((_) => completedController.stream);

    when(() => mockPlayer.play(
          any(),
          position: Duration.zero,
        )).thenAnswer((_) async {});

    when(() => mockPlayer.pause()).thenAnswer((_) async {});

    when(() => mockPlayer.resume()).thenAnswer((_) async {});

    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

    when(() => mockPlayer.stop()).thenAnswer((_) async {});

    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
  });

  group('service tests', () {
    test('plays an audio file', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      await service.play('/music/test.mp3');

      final verification = verify(
        () => mockPlayer.play(
          captureAny(that: isA<DeviceFileSource>()),
          position: Duration.zero,
        ),
      );

      verification.called(1);

      final source = verification.captured.single as DeviceFileSource;
      expect(source.path, '/music/test.mp3');

      await service.dispose();
    });

    test('forwards playing state', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      final states = <bool>[];
      final subscription = service.playing.listen(states.add);

      await service.play('/music/test.mp3');

      playerStateController.add(PlayerState.playing);
      await Future<void>.delayed(Duration.zero);

      expect(states, [true]);

      await subscription.cancel();
      await service.dispose();
    });

    test('forwards position changes', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      final positions = <Duration>[];
      final subscription = service.position.listen(positions.add);

      await service.play('/music/test.mp3');

      const position = Duration(seconds: 42);
      positionController.add(position);

      await Future<void>.delayed(Duration.zero);

      expect(positions, [position]);

      await subscription.cancel();
      await service.dispose();
    });

    test('forwards duration changes', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      final durations = <Duration>[];
      final subscription = service.duration.listen(durations.add);

      await service.play('/music/test.mp3');

      const duration = Duration(minutes: 3, seconds: 25);
      durationController.add(duration);

      await Future<void>.delayed(Duration.zero);

      expect(durations, [duration]);

      await subscription.cancel();
      await service.dispose();
    });

    test('forwards completed event and stops playing', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      var completed = false;
      final states = <bool>[];

      final completedSubscription =
          service.completed.listen((_) => completed = true);
      final playingSubscription = service.playing.listen(states.add);

      await service.play('/music/test.mp3');

      // Zunächst beginnt die Wiedergabe.
      playerStateController.add(PlayerState.playing);

      // Anschließend meldet der Player das Wiedergabeende.
      completedController.add(null);

      await Future<void>.delayed(Duration.zero);

      expect(completed, isTrue);
      expect(states, [true, false]);

      await completedSubscription.cancel();
      await playingSubscription.cancel();
      await service.dispose();
    });

    test('disposes player when playback fails', () async {
      when(() => mockPlayer.play(
            any(),
            position: Duration.zero,
          )).thenThrow(StateError('Simulated playback failure'));

      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      await expectLater(
        service.play('/music/test.mp3'),
        throwsA(isA<StateError>()),
      );
      verify(() => mockPlayer.dispose()).called(1);

      await service.dispose();
    });

    test('creates a new player after playback failure', () async {
      final secondPlayer = MockAudioPlayer();

      when(() => mockPlayer.play(
            any(),
            position: Duration.zero,
          )).thenThrow(StateError('Simulated playback failure'));

      when(() => secondPlayer.play(
            any(),
            position: Duration.zero,
          )).thenAnswer((_) async {});

      when(() => secondPlayer.onPlayerStateChanged)
          .thenAnswer((_) => playerStateController.stream);

      when(() => secondPlayer.onPositionChanged)
          .thenAnswer((_) => positionController.stream);

      when(() => secondPlayer.onDurationChanged)
          .thenAnswer((_) => durationController.stream);

      when(() => secondPlayer.onPlayerComplete)
          .thenAnswer((_) => completedController.stream);

      when(() => secondPlayer.dispose()).thenAnswer((_) async {});

      var factoryCalls = 0;

      final service = AudioplayersAudioPlaybackService(() {
        factoryCalls++;
        return factoryCalls == 1 ? mockPlayer : secondPlayer;
      });

      await expectLater(
        service.play('/music/test.mp3'),
        throwsA(isA<StateError>()),
      );

      await service.play('/music/test.mp3');

      expect(factoryCalls, 2);

      verify(() => mockPlayer.dispose()).called(1);

      verify(() => secondPlayer.play(
            any(),
            position: Duration.zero,
          )).called(1);

      await service.dispose();
    });

    test('pauses playback', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      await service.play('/music/test.mp3');
      await service.pause();

      verify(() => mockPlayer.pause()).called(1);

      await service.dispose();
    });

    test('resumes playback', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      await service.play('/music/test.mp3');
      await service.resume();

      verify(() => mockPlayer.resume()).called(1);

      await service.dispose();
    });

    test('stops playback', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      await service.play('/music/test.mp3');
      await service.stop();

      verify(() => mockPlayer.stop()).called(1);

      await service.dispose();
    });

    test('seeks to the specified position', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      const position = Duration(seconds: 42);

      await service.play('/music/test.mp3');
      await service.seek(position);

      verify(() => mockPlayer.seek(position)).called(1);

      await service.dispose();
    });

    test('disposes player and closes streams', () async {
      final service = AudioplayersAudioPlaybackService(
        () => mockPlayer,
      );

      await service.play('/music/test.mp3');

      final playingDone = expectLater(
        service.playing,
        emitsDone,
      );
      final positionDone = expectLater(
        service.position,
        emitsDone,
      );
      final durationDone = expectLater(
        service.duration,
        emitsDone,
      );
      final completedDone = expectLater(
        service.completed,
        emitsDone,
      );

      await service.dispose();

      verify(() => mockPlayer.dispose()).called(1);

      await Future.wait([
        playingDone,
        positionDone,
        durationDone,
        completedDone,
      ]);
    });
  });
}
