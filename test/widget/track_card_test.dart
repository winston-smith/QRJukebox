import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_jukebox/widgets/track_card.dart';

void main() {
  group('TrackCard', () {
    const qrData = 'https://www.hitstergame.com/de/00042';

    Future<void> pumpTrackCard(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackCard(
                data: qrData,
                gamePack: 'hitster-10',
                trackNumber: '00042',
                artist: 'Queen',
                title: 'Bohemian Rhapsody',
                year: 1975,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('displays QR code, game pack and track number', (tester) async {
      await pumpTrackCard(tester);

      expect(find.byType(QrImageView), findsOneWidget);

      expect(find.text('hitster-10 · #00042'), findsOneWidget);

      expect(find.text('Queen'), findsNothing);
      expect(find.text('Bohemian Rhapsody'), findsNothing);
    });

    testWidgets('flips to song information and back to QR code',
        (tester) async {
      await pumpTrackCard(tester);

      // Flip to the information side.
      await tester.tap(find.byType(TrackCard));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Queen'), findsOneWidget);
      expect(find.text('1975'), findsOneWidget);
      expect(find.text('Bohemian Rhapsody'), findsOneWidget);

      // Flip back to the QR code.
      await tester.tap(find.byType(TrackCard));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('hitster-10 · #00042'), findsOneWidget);
    });
  });
}
