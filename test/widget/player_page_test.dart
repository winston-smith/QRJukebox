import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/pages/player_page.dart';
import 'package:qr_jukebox/widgets/player_error_view.dart';
import 'package:audioplayers/audioplayers.dart';

class FailingAudioPlayer implements AudioPlayer {
  final Completer<void> playCompleter = Completer<void>();

  int disposeCalls = 0;

  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();

  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();

  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();

  @override
  Stream<void> get onPlayerComplete => const Stream.empty();

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) {
    return playCompleter.future;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('displays error when track cannot be found', (tester) async {
    const parsed = (
      host: 'www.hitstergame.com',
      folders: ['de'],
      trackId: '00001',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          parsed: parsed,
          mediaRoot: '/unused',
          prefs: await SharedPreferences.getInstance(),
          trackFileFinder: ({
            required mediaRoot,
            required host,
            required folders,
            required trackId,
          }) async {
            return null;
          },
          animatedTitle: false,
        ),
      ),
    );

    // Process the asynchronous track lookup and resulting setState.
    await tester.pump();
    await tester.pump();

    expect(find.byType(PlayerErrorView), findsOneWidget);
    expect(find.textContaining('Track not found.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
  });

  testWidgets('shows an error when the audio file cannot be played',
      (tester) async {
    final fakePlayer = FailingAudioPlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          parsed: (
            host: 'www.hitstergame.com',
            folders: ['de'],
            trackId: '00001',
          ),
          mediaRoot: '/unused',
          prefs: await SharedPreferences.getInstance(),
          trackFileFinder: ({
            required mediaRoot,
            required host,
            required folders,
            required trackId,
          }) async =>
              File('/unused/00001_broken.mp3'),
          audioPlayerFactory: () => fakePlayer,
          animatedTitle: false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // First playback attempt fails.
    fakePlayer.playCompleter.completeError(
      StateError('Simulated playback failure'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(PlayerErrorView), findsOneWidget);
    expect(
      find.textContaining('The audio file could not be played.'),
      findsOneWidget,
    );
    expect(fakePlayer.disposeCalls, 1);
  });

  testWidgets('retries playback with a new player after failure',
      (tester) async {
    final players = <FailingAudioPlayer>[];

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          parsed: (
            host: 'www.hitstergame.com',
            folders: ['de'],
            trackId: '00001',
          ),
          mediaRoot: '/unused',
          prefs: await SharedPreferences.getInstance(),
          trackFileFinder: ({
            required mediaRoot,
            required host,
            required folders,
            required trackId,
          }) async =>
              File('/unused/00001_broken.mp3'),
          audioPlayerFactory: () {
            final player = FailingAudioPlayer();
            players.add(player);
            return player;
          },
          animatedTitle: false,
        ),
      ),
    );

    // First playback attempt is still pending.
    await tester.pump();

    expect(players, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // First playback attempt fails.
    players[0].playCompleter.completeError(
      StateError('Simulated playback failure'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayerErrorView), findsOneWidget);
    expect(players[0].disposeCalls, 1);

    // Retry playback.
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(players, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Second playback attempt also fails.
    players[1].playCompleter.completeError(
      StateError('Simulated playback failure'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayerErrorView), findsOneWidget);
    expect(players[1].disposeCalls, 1);
  });
}