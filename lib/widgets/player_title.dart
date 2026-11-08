import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class PlayerTitle extends StatelessWidget {
  final String text;
  final bool animated;

  const PlayerTitle({
    super.key,
    required this.text,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.normal,
            );

    if (!animated) {
      return Text(
        text,
        style: style,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SizedBox(
      height: 24,
      child: Marquee(
        text: text,
        style: style,
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        blankSpace: 50.0,
        velocity: 30.0,
        pauseAfterRound: const Duration(seconds: 2),
        startPadding: 0.0,
        accelerationDuration: const Duration(seconds: 1),
        accelerationCurve: Curves.linear,
        decelerationDuration: const Duration(milliseconds: 500),
        decelerationCurve: Curves.easeOut,
      ),
    );
  }
}