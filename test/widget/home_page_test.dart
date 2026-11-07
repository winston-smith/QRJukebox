import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/main.dart';
import 'package:qr_jukebox/pages/home_page.dart';

void main() {
  group('Home Page', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    group('UI', () {
      testWidgets('displays correctly with empty settings', (tester) async {
        await pumpMyWidget( tester, HomePage(prefs: prefs) );

        // find app title in AppBar
        final appBar = find.byType(AppBar);
        expect(appBar, findsOneWidget);
        expect(
          find.descendant( of: appBar, matching: find.text('QR Jukebox') ),
          findsOneWidget,
        );

        // Settings button
        expect(find.byKey(const Key('settingsButton')), findsOneWidget);

        // Main branding
        expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);

        // Main actions
        expect(find.byKey(const Key('scanQRButton')), findsOneWidget);
        expect(find.byKey(const Key('enterURLButton')), findsOneWidget);

        // Media folder is not configured
        expect( find.text('No media folder configured'), findsOneWidget );

        // Setup button should be available
        expect(find.byKey(const Key('mediaFolderSetupButton')), findsOneWidget);
      });

      testWidgets('displays media folder and skips setup button with custom settings', (tester) async {
        prefs.setString('mediaRootPath', '/foo/bar');
        await pumpMyWidget( tester, HomePage(prefs: prefs) );

        final text = tester.widget<Text>(
          find.byKey(const Key('mediaFolderText')),
        );
        expect(text.data, 'bar');

        // Setup button should be not be visible
        expect(find.byKey(const Key('mediaFolderSetupButton')), findsNothing);
      });
    });

    group('Interactions', () {
      testWidgets('navigates to settings page and returns back home', (tester) async {
        await tester.pumpWidget(QRJukeboxApp(prefs: prefs));

        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();

        final appBarSettings = find.byType(AppBar);
        expect(appBarSettings, findsOneWidget);
        expect(
          find.descendant( of: appBarSettings, matching: find.text('Settings') ),
          findsOneWidget,
        );

        await tester.pageBack();
        await tester.pumpAndSettle();

        final appBarHome = find.byType(AppBar);
        expect(appBarHome, findsOneWidget);
        expect(
          find.descendant( of: appBarHome, matching: find.text('QR Jukebox') ),
          findsOneWidget,
        );
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
