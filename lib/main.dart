import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'pages/home_page.dart';

// ─── Entry Point ───────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();
  
  final keepAwake = prefs.getBool('keepAwake') ?? true;
  WakelockPlus.toggle(enable: keepAwake);
  
  runApp(QRJukeboxApp(prefs: prefs));
}

// ─── App Root ──────────────────────────────────────────────────────────────

class QRJukeboxApp extends StatelessWidget {
  final SharedPreferences prefs;
  const QRJukeboxApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Jukebox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2200FF),
        ),
        useMaterial3: true,
      ),
      home: HomePage(prefs: prefs),
    );
  }
}
