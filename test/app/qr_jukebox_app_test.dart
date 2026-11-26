import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_jukebox/app/qr_jukebox_app.dart';

import '../fakes/fake_audio_playback_service.dart';
import '../fakes/fake_pack_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakePackStorage packStorage;
  late FakeAudioPlaybackService audioPlaybackService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    packStorage = FakePackStorage();
    audioPlaybackService = FakeAudioPlaybackService();
  });

  testWidgets('shows loading indicator while dependencies are initialized',
      (tester) async {
    await tester.pumpWidget(
      QRJukeboxApp(
        prefs: prefs,
        audioPlaybackService: audioPlaybackService,
        packStorage: packStorage,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('QR Jukebox'), findsNothing);
  });

  testWidgets('shows HomePage after dependencies are initialized',
      (tester) async {
    await tester.pumpWidget(
      QRJukeboxApp(
        prefs: prefs,
        audioPlaybackService: audioPlaybackService,
        packStorage: packStorage,
      ),
    );

    packStorage.completer.complete(Directory('/fake/packs'));

    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });

    await tester.pump();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('disposes audio playback service when app is disposed',
      (tester) async {
    await tester.pumpWidget(
      QRJukeboxApp(
        prefs: prefs,
        audioPlaybackService: audioPlaybackService,
        packStorage: packStorage,
      ),
    );

    packStorage.completer.complete(Directory('/fake/packs'));

    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });

    await tester.pump();

    await tester.pumpWidget(const SizedBox());

    expect(audioPlaybackService.disposeCalls, 1);
  });
}
