import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_jukebox/domain/repositories/installed_pack_repository.dart';
import 'package:qr_jukebox/domain/repositories/media_source_repository.dart';
import 'package:qr_jukebox/domain/services/pack_storage.dart';
import 'package:qr_jukebox/infrastructure/default_installed_pack_repository.dart';
import 'package:qr_jukebox/infrastructure/default_media_source_repository.dart';
import 'package:qr_jukebox/services/audio_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/screens/home_page.dart';

class QRJukeboxApp extends StatefulWidget {
  final SharedPreferences prefs;
  final AudioPlaybackService audioPlaybackService;
  final PackStorage packStorage;

  const QRJukeboxApp({
    super.key,
    required this.prefs,
    required this.audioPlaybackService,
    required this.packStorage,
  });

  static QRJukeboxAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<QRJukeboxAppState>();

  @override
  State<QRJukeboxApp> createState() => QRJukeboxAppState();
}

class QRJukeboxAppState extends State<QRJukeboxApp> {
  late final MediaSourceRepository _mediaSourceRepository;
  late final InstalledPackRepository _installedPackRepository;
  bool _dependenciesReady = false;

  static const _defaultSeedColor = Color(0xFF6750A4);

  @override
  void initState() {
    super.initState();

    _initializeDependencies();
  }

  Future<void> _initializeDependencies() async {
    _mediaSourceRepository = DefaultMediaSourceRepository(
      prefs: widget.prefs,
    );

    final packsDirectory = await widget.packStorage.getPacksDirectory();
    if (!mounted) {
      return;
    }

    _installedPackRepository = DefaultInstalledPackRepository(
      packsDirectory: packsDirectory,
    );

    setState(() {
      _dependenciesReady = true;
    });
  }

  void reloadTheme() {
    setState(() {});
  }

  ColorScheme _toFlutterColorScheme(dynamic scheme) {
    return ColorScheme(
      brightness: scheme.brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      secondary: scheme.secondary,
      onSecondary: scheme.onSecondary,
      secondaryContainer: scheme.secondaryContainer,
      onSecondaryContainer: scheme.onSecondaryContainer,
      tertiary: scheme.tertiary,
      onTertiary: scheme.onTertiary,
      tertiaryContainer: scheme.tertiaryContainer,
      onTertiaryContainer: scheme.onTertiaryContainer,
      error: scheme.error,
      onError: scheme.onError,
      errorContainer: scheme.errorContainer,
      onErrorContainer: scheme.onErrorContainer,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      outline: scheme.outline,
      outlineVariant: scheme.outlineVariant,
      shadow: scheme.shadow,
      scrim: scheme.scrim,
      inverseSurface: scheme.inverseSurface,
      onInverseSurface: scheme.onInverseSurface,
      inversePrimary: scheme.inversePrimary,
      surfaceTint: scheme.surfaceTint,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_dependenciesReady) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final themeModeStr = widget.prefs.getString('themeMode') ?? 'system';
    final ThemeMode themeMode;
    switch (themeModeStr) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        themeMode = ThemeMode.system;
        break;
    }

    final useDynamicColor = widget.prefs.getBool('useDynamicColor') ?? true;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (useDynamicColor && lightDynamic != null && darkDynamic != null) {
          lightColorScheme = _toFlutterColorScheme(lightDynamic.harmonized());
          darkColorScheme = _toFlutterColorScheme(darkDynamic.harmonized());
        } else {
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultSeedColor,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultSeedColor,
            brightness: Brightness.dark,
          );
        }

        darkColorScheme = darkColorScheme.copyWith(
          surface: Colors.black,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0C0C0C),
          surfaceContainer: const Color(0xFF141414),
          surfaceContainerHigh: const Color(0xFF1C1C1C),
          surfaceContainerHighest: const Color(0xFF242424),
        );

        return MaterialApp(
          title: 'QR Jukebox',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: Colors.black,
            canvasColor: Colors.black,
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: HomePage(
            prefs: widget.prefs,
            audioPlaybackService: widget.audioPlaybackService,
            mediaSourceRepository: _mediaSourceRepository,
            installedPackRepository: _installedPackRepository,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(widget.audioPlaybackService.dispose());
    super.dispose();
  }
}
