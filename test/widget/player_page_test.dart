import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/pages/player_page.dart';
import 'package:qr_jukebox/widgets/player_error_view.dart';

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
}