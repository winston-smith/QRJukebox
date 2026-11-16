import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/pages/player_page.dart';
import 'package:qr_jukebox/widgets/player_error_view.dart';

import '../fakes/fake_audio_playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the player when playback succeeds', (tester) async {
    final fakeService = FakeAudioPlaybackService();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

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
              File('/unused/00001_test.mp3'),
          audioPlaybackService: fakeService,
          animatedTitle: false,
        ),
      ),
    );

    // Playback is still pending.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Playback succeeds.
    fakeService.playCompleters[0].complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(PlayerErrorView), findsNothing);

    // Verify that the player UI is displayed.
    expect(find.text('unused'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(fakeService.dispose);
  });

  testWidgets('allows to pause and resume playback', (tester) async {
    final fakeService = FakeAudioPlaybackService();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

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
              File('/unused/00001_test.mp3'),
          audioPlaybackService: fakeService,
          animatedTitle: false,
        ),
      ),
    );

    await tester.pump();
    fakeService.playCompleters[0].complete();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('playPauseButton')));
    await tester.pump();

    // Assert:
    expect(fakeService.pauseCalls, 1);
    expect(fakeService.resumeCalls, 0);

    await tester.tap(find.byKey(const Key('playPauseButton')));
    await tester.pump();

    // Assert:
    expect(fakeService.pauseCalls, 1);
    expect(fakeService.resumeCalls, 1);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(fakeService.dispose);
  });

  testWidgets('displays error when track cannot be found', (tester) async {
    final fakeService = FakeAudioPlaybackService();
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
          audioPlaybackService: fakeService,
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

    addTearDown(fakeService.dispose);
  });

  testWidgets('shows an error when the audio file cannot be played',
      (tester) async {
    final fakeService = FakeAudioPlaybackService();

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
          audioPlaybackService: fakeService,
          animatedTitle: false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // First playback attempt fails.
    fakeService.playCompleters[0].completeError(
      StateError('Simulated playback failure'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(PlayerErrorView), findsOneWidget);
    expect(
      find.textContaining('The audio file could not be played.'),
      findsOneWidget,
    );

    addTearDown(fakeService.dispose);
  });

  testWidgets('retries playback through the service after failure',
      (tester) async {
    final fakeService = FakeAudioPlaybackService();

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
          audioPlaybackService: fakeService,
          animatedTitle: false,
        ),
      ),
    );

    // First playback attempt is still pending.
    await tester.pump();

    expect(fakeService.playCompleters, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // First playback attempt fails.
    fakeService.playCompleters[0].completeError(
      StateError('Simulated playback failure'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayerErrorView), findsOneWidget);

    // Retry playback.
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(fakeService.playCompleters, hasLength(2));
    expect(
      fakeService.playedFiles[0],
      fakeService.playedFiles[1],
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Second playback attempt also fails.
    fakeService.playCompleters[1].completeError(
      StateError('Simulated playback failure'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayerErrorView), findsOneWidget);
    expect(fakeService.playedFiles, hasLength(2));

    addTearDown(fakeService.dispose);
  });
}
