import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/screens/player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/widgets/player_error_view.dart';

import '../fakes/fake_audio_playback_service.dart';

class FakeScannerPage extends StatelessWidget {
  const FakeScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        key: const Key('simulate-scan'),
        onPressed: () {
          Navigator.pop(
            context,
            'https://www.example.com/de/00002',
          );
        },
        child: const Text('Simulate scan'),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Player Page', () {

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
              raw: 'www.hitstergame.com/de/00001',
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
      expect( fakeService.playedFiles, ['/unused/00001_test.mp3']);

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
              raw: 'www.hitstergame.com/de/00001',
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

    testWidgets('scans again and plays the newly scanned track', (
      tester,
    ) async {
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
              raw: 'www.hitstergame.com/de/00001',
            ),
            mediaRoot: '/unused',
            prefs: await SharedPreferences.getInstance(),
            trackFileFinder: ({
              required mediaRoot,
              required host,
              required folders,
              required trackId,
            }) async => File('/unused/$trackId.mp3'),
            audioPlaybackService: fakeService,
            scannerBuilder: () => const FakeScannerPage(),
          ),
        ),
      );

      // Initial track starts.
      await tester.pump();

      expect(fakeService.playCompleters, hasLength(1));

      // Complete initial playback.
      fakeService.playCompleters[0].complete();
      await tester.pumpAndSettle();

      // Open scanner.
      await tester.tap(find.byKey(const Key('scan-again')));
      await tester.pumpAndSettle();

      expect(find.byType(FakeScannerPage), findsOneWidget);
      expect(find.text('Simulate scan'), findsOneWidget);

      // Subscribe before triggering the second playback.
      final secondPlay = fakeService.playCalls.firstWhere(
        (file) => file == '/unused/00002.mp3',
      );

      // Simulate scanning a different track.
      await tester.tap(find.byKey(const Key('simulate-scan')));
      await tester.pump();

      expect(await secondPlay, '/unused/00002.mp3');

      expect(
        fakeService.playedFiles,
        ['/unused/00001.mp3', '/unused/00002.mp3'],
      );
    });
    
    testWidgets('stops playback when the scanned track cannot be found', (
      tester,
    ) async {
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
              raw: 'www.hitstergame.com/de/00001',
            ),
            mediaRoot: '/unused',
            prefs: await SharedPreferences.getInstance(),
            trackFileFinder: ({
              required mediaRoot,
              required host,
              required folders,
              required trackId,
            }) async {
              if (trackId == '00002') {
                return null;
              }

              return File('/unused/$trackId.mp3');
            },
            audioPlaybackService: fakeService,
            scannerBuilder: () => const FakeScannerPage(),
          ),
        ),
      );

      // Initial track starts.
      await tester.pump();

      expect(fakeService.playCompleters, hasLength(1));

      // Complete initial playback.
      fakeService.playCompleters[0].complete();
      await tester.pumpAndSettle();

      // Open scanner.
      await tester.tap(find.byKey(const Key('scan-again')));
      await tester.pumpAndSettle();

      expect(find.byType(FakeScannerPage), findsOneWidget);

      // Scan a track that does not exist.
      await tester.tap(find.byKey(const Key('simulate-scan')));
      await tester.pumpAndSettle();

      expect(fakeService.stopCalls, 2);
      expect(fakeService.playedFiles, ['/unused/00001.mp3']);
    });

    testWidgets('displays error when track cannot be found', (tester) async {
      final fakeService = FakeAudioPlaybackService();
      const parsed = (
        host: 'www.hitstergame.com',
        folders: ['de'],
        trackId: '00001',
        raw: 'www.hitstergame.com/de/00001',
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
              raw: 'www.hitstergame.com/de/00001',
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
              raw: 'www.hitstergame.com/de/00001',
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

    testWidgets('stops playback when navigating back to the homepage',
        (tester) async {
      final fakeService = FakeAudioPlaybackService();
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-player'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerPage(
                          parsed: (
                            host: 'www.hitstergame.com',
                            folders: ['de'],
                            trackId: '00001',
                            raw: 'www.hitstergame.com/de/00001',
                          ),
                          mediaRoot: '/unused',
                          prefs: prefs,
                          trackFileFinder: ({
                            required mediaRoot,
                            required host,
                            required folders,
                            required trackId,
                          }) async =>
                              File('/unused/00001_test.mp3'),
                          audioPlaybackService: fakeService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open player'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the player page.
      await tester.tap(find.byKey(const Key('open-player')));
      await tester.pump();

      expect(fakeService.playCompleters, hasLength(1));

      // Complete playback.
      fakeService.playCompleters[0].complete();
      await tester.pumpAndSettle();

      expect(fakeService.playedFiles, ['/unused/00001_test.mp3']);

      // The initial stop() happens before playback starts.
      expect(fakeService.stopCalls, 1);

      // Navigate back to the homepage.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Open player'), findsOneWidget);

      // Playback should have been stopped when leaving the player.
      expect(fakeService.stopCalls, 2);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(fakeService.dispose);
    });

  });
}
