import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_jukebox/infrastructure/audioplayers_audio_playback_service.dart';
import 'package:qr_jukebox/services/audio_playback_service.dart';
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
  
  final audioPlaybackService = AudioplayersAudioPlaybackService(
    () => AudioPlayer(),
  );

  runApp(QRJukeboxApp(
    prefs: prefs,
    audioPlaybackService: audioPlaybackService,
  ));
}

// ─── App Root ──────────────────────────────────────────────────────────────


class QRJukeboxApp extends StatefulWidget {
  final SharedPreferences prefs;
  final AudioPlaybackService audioPlaybackService;

  const QRJukeboxApp({
    super.key,
    required this.prefs,
    required this.audioPlaybackService,
  });

  @override
  State<QRJukeboxApp> createState() => _QRJukeboxAppState();
}


class _QRJukeboxAppState extends State<QRJukeboxApp> {
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
      home: HomePage(
        prefs: widget.prefs,
        audioPlaybackService: widget.audioPlaybackService,
      ),
    );
  }

  @override
  void dispose() {
    widget.audioPlaybackService.dispose();
    super.dispose();
  }
}
