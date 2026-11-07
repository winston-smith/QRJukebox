import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/main.dart';

void main() {
  group('Settings Page', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    
    group('UI', () {

      testWidgets('displays settings page correctly with empty settings', (tester) async {
        await pumpMyWidget( tester, SettingsPage(prefs: prefs) );

        // find 'Settings' in AppBar
        expect(find.byType(AppBar), findsOneWidget);
        expect( find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Settings'),
          ), findsOneWidget );

        expect(find.text('Device Settings'), findsOneWidget );
        expect(find.byKey(const Key('keepAwakeSwitch')), findsOneWidget);
        expect(find.text('Playback Settings'), findsOneWidget );
        expect(find.byKey(const Key('showStopwatchSwitch')), findsOneWidget);
        expect(find.byKey(const Key('playbackOffsetTextField')), findsOneWidget);
        expect(find.text('Media Folder'), findsOneWidget );
        expect(find.byKey(const Key('mediaFolderTextField')), findsOneWidget);
        expect(find.byKey(const Key('savePathButton')), findsOneWidget);
        expect(find.text('Expected Folder Structure'), findsOneWidget );

      });

      testWidgets('displays custom setting correctly', (tester) async {
        prefs.setString('mediaRootPath', 'my folder');
        prefs.setBool('keepAwake', true);
        prefs.setBool('showStopwatch', true);
        await pumpMyWidget( tester, SettingsPage(prefs: prefs) );

        final keepAwakeSwitch = tester.widget<SwitchListTile>(
          find.byKey(const Key('keepAwakeSwitch'))
        );
        expect(keepAwakeSwitch.value, true);

        final showStopwatchSwitch = tester.widget<SwitchListTile>(
          find.byKey(const Key('showStopwatchSwitch'))
        );
        expect(showStopwatchSwitch.value, true);

        final textField = tester.widget<TextField>(
          find.byKey(const Key('mediaFolderTextField')),
        );

        expect(textField.controller?.text, 'my folder');
      });
    });


    group('Interactions', () {

      testWidgets('saves keepAwake setting when switch is changed', (tester) async {
        await tester.pumpWidget(QRJukeboxApp(prefs: prefs));

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        // Switch initially has its default value (on)
        expect(
          tester.widget<SwitchListTile>(
            find.byKey(const Key('keepAwakeSwitch')),
          ).value,
          true,
        );

      // Turn it off
      await tester.tap(find.byKey(const Key('keepAwakeSwitch')));
      await tester.pumpAndSettle();

      // Verify the UI
      expect(
        tester.widget<SwitchListTile>(
          find.byKey(const Key('keepAwakeSwitch')),
        ).value,
        false,
      );

        // Verify persistence
        expect(prefs.getBool('keepAwake'), false);
      });

      testWidgets('saves showStopwatch setting when switch is changed', (tester) async {
        await tester.pumpWidget(QRJukeboxApp(prefs: prefs));

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        final stopwatchSwitch = find.byKey(
          const Key('showStopwatchSwitch'),
        );

        await tester.tap(stopwatchSwitch);
        await tester.pumpAndSettle();

        expect(prefs.getBool('showStopwatch'), true);
      });

      testWidgets('saves playback offset when value is changed', (tester) async {
        await tester.pumpWidget(QRJukeboxApp(prefs: prefs));

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
        await tester.pumpWidget(QRJukeboxApp(prefs: prefs));

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        final pathField = find.byKey(const Key('mediaFolderTextField'));

        await tester.ensureVisible(pathField);
        await tester.enterText(pathField, '/music/hitster');

        await tester.tap(find.byKey(const Key('savePathButton')));
        await tester.pumpAndSettle();

        expect(prefs.getString('mediaRootPath'), '/music/hitster');
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('hitster'), findsOneWidget);
        expect(find.byKey(const Key('mediaFolderSetupButton')), findsNothing);
      });

    });

  });
}

Future<void> pumpMyWidget(
  WidgetTester tester,
  Widget myWidget
) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3.0;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: myWidget));
}
