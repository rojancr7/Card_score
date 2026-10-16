import 'package:flutter/material.dart';

enum ResetChoice {
  keepNames,
  defaultNames,
  cancel,
}

class ResetDialog extends StatelessWidget {
  const ResetDialog({super.key});

  static Future<ResetChoice> show(BuildContext context) async {
    final result = await showDialog<ResetChoice>(
      context: context,
      builder: (ctx) => const ResetDialog(),
    );
    return result ?? ResetChoice.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.refresh, color: Colors.orange),
          SizedBox(width: 8),
          Text('Reset Current Game'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will clear all rounds and scores for the current game and reset the scoreboard back to Round 1.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your saved history and previous games will NOT be deleted.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'How would you like to handle player names?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ResetChoice.cancel),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(ResetChoice.defaultNames),
          child: const Text('Reset Names'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ResetChoice.keepNames),
          child: const Text('Keep Names'),
        ),
      ],
    );
  }
}
