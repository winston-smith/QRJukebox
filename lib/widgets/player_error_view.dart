import 'package:flutter/material.dart';

class PlayerErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onScanAgain;

  const PlayerErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 72,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red)
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('retryButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('rescanButton'),
            onPressed: onScanAgain,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}