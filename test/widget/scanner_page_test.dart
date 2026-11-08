import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:qr_jukebox/pages/scanner_page.dart';

class ScannerTestHost extends StatefulWidget {
  const ScannerTestHost({super.key});

  @override
  State<ScannerTestHost> createState() => _ScannerTestHostState();
}

class _ScannerTestHostState extends State<ScannerTestHost> {
  String? _scannedText;

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerPage(),
      ),
    );

    setState(() {
      _scannedText = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _openScanner,
            child: const Text('Open scanner'),
          ),
          if (_scannedText != null)
            Text(_scannedText!),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('displays the QR code scanner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScannerPage(),
      ),
    );

    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.byType(ReaderWidget), findsOneWidget);
  });

  testWidgets('returns the scanned text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScannerTestHost(),
      ),
    );

    // Open the scanner.
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();

    // Get the ReaderWidget and simulate a successful scan.
    final reader = tester.widget<ReaderWidget>(
      find.byType(ReaderWidget),
    );

    reader.onScan?.call(
      Code(
        text: 'hello world',
        isValid: true,
      ),
    );

    await tester.pumpAndSettle();

    // The scanner was closed and the result was returned.
    expect(find.byType(ScannerPage), findsNothing);
    expect(find.text('hello world'), findsOneWidget);
  });

}