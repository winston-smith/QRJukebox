import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:qr_jukebox/infrastructure/audioplayers_audio_playback_service.dart';
import 'package:qr_jukebox/infrastructure/default_pack_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/qr_jukebox_app.dart';
import 'package:qr_jukebox/services/app_version.dart';

// ─── Entry Point ───────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();

  final keepAwake = prefs.getBool('keepAwake') ?? true;
  WakelockPlus.toggle(enable: keepAwake);

  final audioPlaybackService = AudioplayersAudioPlaybackService(
    () => AudioPlayer(),
  );

  await AppVersion.init();

  runApp(QRJukeboxApp(
    prefs: prefs,
    audioPlaybackService: audioPlaybackService,
    packStorage: DefaultPackStorage(),
  ));
}
