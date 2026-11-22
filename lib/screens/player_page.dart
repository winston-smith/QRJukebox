import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:qr_jukebox/services/audio_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:qr_jukebox/services/track_finder.dart';
import 'package:qr_jukebox/widgets/player_error_view.dart';
import 'package:qr_jukebox/widgets/player_title.dart';
import 'package:qr_jukebox/app/fullscreen_cover.dart';
import 'package:qr_jukebox/utils/formatting.dart';
import 'package:qr_jukebox/utils/url_parser.dart';
import 'package:qr_jukebox/screens/scanner_page.dart';

typedef ScannerBuilder = Widget Function();

class PlayerPage extends StatefulWidget {
  final ParsedTrackUrl parsed;
  final String mediaRoot;
  final SharedPreferences prefs;
  final TrackFileFinder trackFileFinder;
  final bool animatedTitle;
  final AudioPlaybackService audioPlaybackService;
  final ScannerBuilder scannerBuilder;

  const PlayerPage({
    super.key,
    required this.parsed,
    required this.mediaRoot,
    required this.prefs,
    required this.audioPlaybackService,
    this.trackFileFinder = findTrackFile,
    this.animatedTitle = true,
    this.scannerBuilder = _defaultScannerBuilder,
  });

  static Widget _defaultScannerBuilder() => const ScannerPage();

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  File? _file;
  AudioMetadata? _tags;
  bool _loading = true;
  bool _completed = false;
  String? _error;
  String? _gameName;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  final Stopwatch _stopwatch = Stopwatch();

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completedSubscription;

  @override
  void initState() {
    super.initState();

    _playingSubscription =
        widget.audioPlaybackService.playing.listen((playing) {
      if (!mounted) return;

        setState(() {
        _playing = playing;
        if (playing) _completed = false;
        });
    });

    _positionSubscription =
        widget.audioPlaybackService.position.listen((position) {
      if (!mounted) return;

      setState(() {
        _pos = position;
      });
    });

    _durationSubscription =
        widget.audioPlaybackService.duration.listen((duration) {
      if (!mounted) return;

      setState(() {
        _dur = duration;
      });
    });

    _completedSubscription =
        widget.audioPlaybackService.completed.listen((_) {
      if (!mounted) return;

      setState(() {
        _playing = false;
        _completed = true;
        _pos = Duration.zero;
      });
    });

    _stopwatch.start();
    _loadAndPlay();
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completedSubscription?.cancel();

    super.dispose();
  }

  Future<void> _loadAndPlay() async {
    setState(() { _loading = true; _error = null; });

    if (Platform.isAndroid) {
      if (!await _ensurePermission()) {
        if (mounted) {
          setState(() {
            _error =
            'Storage access denied.\n\nPlease allow storage permission in Android settings.';
            _loading = false;
          });
        }
        return;
      }
    }
    final file = await widget.trackFileFinder(
      mediaRoot: widget.mediaRoot,
      host: widget.parsed.host,
      folders: widget.parsed.folders,
      trackId: widget.parsed.trackId,
    );

    // Stop previous playback before handling the scanned track.
    await widget.audioPlaybackService.stop();

    if (!mounted) return;

    if (file == null) {
      final fullPath = [widget.parsed.host, ...widget.parsed.folders].join('/');
      setState(() {
        _error = 'Track not found.\n\n'
            'Searched in:\n'
            '${widget.mediaRoot}/$fullPath/\n\n'
            'Filename must start with\n"${widget.parsed.trackId}".';
        _loading = false;
      });
      return;
    }

    final folderName = p.basename(file.parent.path);
    final underscoreIdx = folderName.indexOf('_');

    AudioMetadata? tags;
    try {
      tags = readMetadata(file, getImage: true);
    } catch (_) {}

    setState(() {
      _file = file;
      _tags = tags;
      _gameName = underscoreIdx != -1
          ? folderName.substring(underscoreIdx + 1)
          : folderName;
    });

    final startOffset = widget.prefs.getInt('playbackStartOffset') ?? 0;

    try {
      await widget.audioPlaybackService.play(
        file.path,
      position: Duration(seconds: startOffset),
    );

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to play audio file: $e');

      if (!mounted) return;

      setState(() {
        _error = 'The audio file could not be played.\n\n'
            'The file may be damaged or in an unsupported format.';
        _loading = false;
      });
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final newPos = _pos + Duration(seconds: seconds);
    await widget.audioPlaybackService.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> _scanAndPlay() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => widget.scannerBuilder()),
    );
    if (result != null && mounted) {
      final parsed = parseUrl(result);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL format')),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerPage(
            parsed: parsed,
            mediaRoot: widget.mediaRoot,
            prefs: widget.prefs,
            audioPlaybackService: widget.audioPlaybackService,
            trackFileFinder: widget.trackFileFinder,
            scannerBuilder: widget.scannerBuilder,
            animatedTitle: widget.animatedTitle,
          ),
        ),
      );
    }
  }

  Future<bool> _ensurePermission() async {
    if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
      return true;
    }
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<void> _togglePlayPause() async {
    if (_playing) {
      await widget.audioPlaybackService.pause();
      return;
    }
    if (_file == null) return;
    if (_completed) {
      await widget.audioPlaybackService.play(_file!.path);
      return;
    }
    await widget.audioPlaybackService.resume();
  }


  void _showInfoDialog() {
    if (_file == null) return;

    final size = _file!.lengthSync();
    final sizeStr = formatBytes(size, 2);
    final trackDisplay =
        int.tryParse(widget.parsed.trackId.toString()) ?? widget.parsed.trackId;
    final hasCover = _tags?.pictures.isNotEmpty == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Track Information'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              if (hasCover)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenCover(
                            imageBytes: _tags!.pictures.first.bytes,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _tags!.pictures.first.bytes,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              _infoRow('Track #', trackDisplay.toString()),
              _infoRow('Game Set', _gameName ?? (widget.parsed.folders.isNotEmpty ? widget.parsed.folders.last : 'Root')),
              if (_tags?.title != null && _tags!.title!.isNotEmpty)
                _infoRow('Title', _tags!.title!),
              if (_tags?.artist != null && _tags!.artist!.isNotEmpty)
                _infoRow('Artist', _tags!.artist!),
              if (_tags?.album != null && _tags!.album!.isNotEmpty)
                _infoRow('Album', _tags!.album!),
              if (_tags?.year != null && _tags!.year!.year != 0)
                _infoRow('Year', _tags!.year!.year.toString()),
              _infoRow('File Size', sizeStr),
              _infoRow('File Name', p.basename(_file!.path)),
              _infoRow('Full Path', _file!.path),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trackDisplay = int.tryParse(widget.parsed.trackId.toString()) ?? widget.parsed.trackId;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(widget.audioPlaybackService.stop());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          title: PlayerTitle(
            text: '#$trackDisplay  ·  ${_gameName ?? (widget.parsed.folders.isNotEmpty ? widget.parsed.folders.last : 'Root')}',
            animated: widget.animatedTitle,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showInfoDialog,
              tooltip: 'Track Info',
            ),
          ],
        ),

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? PlayerErrorView(
                        message: _error!,
                        onRetry: _loadAndPlay,
                        onScanAgain: _scanAndPlay,
                      )
                    : _buildPlayer(cs),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(ColorScheme cs) {
    final maxMs = _dur.inMilliseconds.toDouble();
    final curMs =
    _pos.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);
    final trackDisplay = int.tryParse(widget.parsed.trackId.toString()) ?? widget.parsed.trackId;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          key: const Key('scan-again'),
          onTap: _scanAndPlay,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _playing ? Icons.music_note_rounded : Icons.music_note,
              size: 80,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Click to scan again',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.primary.withValues(alpha: 0.5),
          ),
        ),

        const SizedBox(height: 24),

        Text('Game Pack',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        Text(
          _gameName ?? (widget.parsed.folders.isNotEmpty ? widget.parsed.folders.last : 'Root'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text('Track #$trackDisplay',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey)),

        const SizedBox(height: 16),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.primary.withValues(alpha: 0.24),
            thumbColor: cs.primary,
            overlayColor: cs.primary.withValues(alpha: 0.12),
            trackHeight: 4.0,
          ),
          child: Slider(
            value: curMs,
            max: maxMs > 0 ? maxMs : 1.0,
            onChanged: (v) {
              if (maxMs > 0) {
                widget.audioPlaybackService.seek(Duration(milliseconds: v.toInt()));
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(_pos),
                  style: Theme.of(context).textTheme.bodySmall),
              Text(formatDuration(_dur),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key( 'rewindButton'),
              icon: const Icon(Icons.replay_10_rounded),
              onPressed: () => _seekRelative(-10),
              iconSize: 32,
              color: cs.primary,
            ),
            const SizedBox(width: 16),
            FilledButton(
              key: const Key( 'playPauseButton'),
              onPressed: _togglePlayPause,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(24),
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 48,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              key: const Key( 'forwardButton'),
              icon: const Icon(Icons.forward_10_rounded),
              onPressed: () => _seekRelative(10),
              iconSize: 32,
              color: cs.primary,
            ),
          ],
        ),

        if (widget.prefs.getBool('showStopwatch') ?? false) ...[
          const SizedBox(height: 32),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, _) {
              final elapsed = _stopwatch.elapsed;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: cs.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Spent time: ${formatDuration(elapsed)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
