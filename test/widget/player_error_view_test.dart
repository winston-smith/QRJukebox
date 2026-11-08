import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_jukebox/widgets/player_error_view.dart';

void main() {
  testWidgets('displays correctly', (tester) async {
    final errorMsg = "test error message";
    var retryCalled = false;
    var scanAgainCalled = false;

    await tester.pumpWidget(MaterialApp(home: PlayerErrorView(
      message: errorMsg,
      onRetry: () => retryCalled = true,
      onScanAgain: () => scanAgainCalled = true,
    ) ) );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    final finder = find.text(errorMsg);
    expect(finder, findsOneWidget);
    final errorText = tester.widget<Text>(finder);
    expect(errorText.style?.color, Colors.red);

    expect(find.byKey(const Key('retryButton')), findsOneWidget);
    expect(find.byKey(const Key('rescanButton')), findsOneWidget);

    // tap 'Try again' button
    await tester.tap(find.byKey(const Key('retryButton')));
    expect(retryCalled, isTrue);

    // tap 'Scan again' button
    await tester.tap(find.byKey(const Key('rescanButton')));
    expect(scanAgainCalled, isTrue);
  });

}