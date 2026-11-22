import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/app/qr_jukebox_app.dart';
import 'package:qr_jukebox/screens/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_audio_playback_service.dart';
import '../fakes/fake_file_picker.dart';

void main() {
  group('Settings Page', () {
    late SharedPreferences prefs;
    final originalFilePicker = FilePickerPlatform.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      FilePickerPlatform.instance =
          FakeFilePicker(directoryPath: '/my/music/folder');
    });

    group('UI', () {
      testWidgets('displays settings page correctly with empty settings',
          (tester) async {
        await pumpMyWidget(tester, SettingsPage(prefs: prefs),
            size: const Size(1179, 6000));

        // find 'Settings' in AppBar
        expect(find.byType(AppBar), findsOneWidget);
        expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Settings'),
            ),
            findsOneWidget);

        expect(find.text('Device Settings'), findsOneWidget);
        expect(find.byKey(const Key('keepAwakeSwitch')), findsOneWidget);
        expect(find.text('Playback Settings'), findsOneWidget);
        expect(find.byKey(const Key('showStopwatchSwitch')), findsOneWidget);
        expect(
            find.byKey(const Key('playbackOffsetTextField')), findsOneWidget);
        expect(find.byKey(const Key('chooseMediaFolder')), findsOneWidget);

        expect(find.text('No folder selected!'), findsOneWidget);

        expect(find.text('Expected folder structure:'), findsOneWidget);
      });

      testWidgets('displays custom setting correctly', (tester) async {
        await prefs.setString('mediaRootPath', 'my folder');
        await prefs.setBool('keepAwake', true);
        await prefs.setBool('showStopwatch', true);

        await pumpMyWidget(tester, SettingsPage(prefs: prefs),
            size: const Size(1179, 6000));

        final keepAwakeSwitch = tester
            .widget<SwitchListTile>(find.byKey(const Key('keepAwakeSwitch')));
        expect(keepAwakeSwitch.value, true);

        final showStopwatchSwitch = tester.widget<SwitchListTile>(
            find.byKey(const Key('showStopwatchSwitch')));
        expect(showStopwatchSwitch.value, true);

        expect(
          find.byKey(const Key('chooseMediaFolder')),
          findsOneWidget,
        );

        expect(
          find.text('Selected folder: my folder'),
          findsOneWidget,
        );
      });
    });

    group('Interactions', () {
      testWidgets('saves keepAwake setting when switch is changed',
          (tester) async {
        await tester.pumpWidget(QRJukeboxApp(
          prefs: prefs,
          audioPlaybackService: FakeAudioPlaybackService(),
        ));

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        // Switch initially has its default value (on)
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('keepAwakeSwitch')),
              )
              .value,
          true,
        );

        // Turn it off
        await tester.tap(find.byKey(const Key('keepAwakeSwitch')));
        await tester.pumpAndSettle();

        // Verify the UI
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('keepAwakeSwitch')),
              )
              .value,
          false,
        );

        // Verify persistence
        expect(prefs.getBool('keepAwake'), false);
      });

      testWidgets('saves showStopwatch setting when switch is changed',
          (tester) async {
        await tester.pumpWidget(QRJukeboxApp(
          prefs: prefs,
          audioPlaybackService: FakeAudioPlaybackService(),
        ));

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        final stopwatchSwitch = find.byKey(
          const Key('showStopwatchSwitch'),
        );

        await tester.tap(stopwatchSwitch);
        await tester.pumpAndSettle();

        expect(prefs.getBool('showStopwatch'), true);
      });

      testWidgets('saves playback offset when value is changed',
          (tester) async {
        await tester.pumpWidget(QRJukeboxApp(
          prefs: prefs,
          audioPlaybackService: FakeAudioPlaybackService(),
        ));

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        final offsetField = find.byKey(
          const Key('playbackOffsetTextField'),
        );

        await tester.ensureVisible(offsetField);
        await tester.enterText(offsetField, '30');
        await tester.pumpAndSettle();

        expect(prefs.getInt('playbackStartOffset'), 30);
      });

      testWidgets('saves media folder and updates homepage', (tester) async {
        tester.view.physicalSize = const Size(1179, 6000);
        tester.view.devicePixelRatio = 3.0;

        await tester.pumpWidget(
          QRJukeboxApp(
            prefs: prefs,
            audioPlaybackService: FakeAudioPlaybackService(),
          ),
        );

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('chooseMediaFolder')));
        await tester.pumpAndSettle();

        expect(prefs.getString('mediaRootPath'), '/my/music/folder');

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('folder'), findsOneWidget);
        expect(find.byKey(const Key('mediaFolderSetupButton')), findsNothing);

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      });
    });

    tearDown(() {
      FilePickerPlatform.instance = originalFilePicker;
    });
  });
}

Future<void> pumpMyWidget(
  WidgetTester tester,
  Widget myWidget, {
  Size size = const Size(1179, 2556),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: myWidget));
}
