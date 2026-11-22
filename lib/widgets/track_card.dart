import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _QrCodeView extends StatelessWidget {
  final String data;
  final double size;

  const _QrCodeView({
    required this.data,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return QrImageView(
      data: data,
      size: size,
      backgroundColor: cs.primaryContainer,
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: cs.onPrimaryContainer,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: cs.onPrimaryContainer,
      ),
    );
  }
}

class TrackCard extends StatefulWidget {
  final String data;
  final String? artist;
  final String? title;
  final int? year;
  final String gamePack;
  final String trackNumber;
  final double size;

  const TrackCard({
    super.key,
    required this.data,
    this.artist,
    this.title,
    this.year,
    required this.gamePack,
    required this.trackNumber,
    this.size = 200,
  });

  @override
  State<TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<TrackCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rotation = Tween<double>(
      begin: 0,
      end: pi,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (_controller.isCompleted) {
          _controller.reverse();
        } else {
          _controller.forward();
        }
      },
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (context, child) {
          final isShowingInfo = _rotation.value >= pi / 2;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_rotation.value);

          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: Container(
              width: widget.size,
              height: widget.size,
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
              child: isShowingInfo
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: _buildInfo(cs),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QrCodeView(
                            data: widget.data,
                            size: widget.size * 0.68,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.gamePack} · #${widget.trackNumber}',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfo(ColorScheme cs) {
    return Padding(
      key: const ValueKey('track-info'),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            widget.artist ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 14,
            ),
          ),
          Text(
            widget.year?.toString() ?? '—',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.title ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
