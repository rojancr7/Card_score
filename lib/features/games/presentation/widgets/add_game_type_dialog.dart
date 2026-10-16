import 'package:flutter/material.dart';

class AddGameTypeDialogResult {
  final String name;
  final bool hasThreshold;
  final int? thresholdValue;

  const AddGameTypeDialogResult({
    required this.name,
    required this.hasThreshold,
    this.thresholdValue,
  });
}

class AddGameTypeDialog extends StatefulWidget {
  const AddGameTypeDialog({super.key});

  static Future<AddGameTypeDialogResult?> show(BuildContext context) {
    return showDialog<AddGameTypeDialogResult>(
      context: context,
      builder: (ctx) => const AddGameTypeDialog(),
    );
  }

  @override
  State<AddGameTypeDialog> createState() => _AddGameTypeDialogState();
}

class _AddGameTypeDialogState extends State<AddGameTypeDialog> {
  final _nameController = TextEditingController();
  final _thresholdController = TextEditingController(text: '20');
  bool _hasThreshold = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _onSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Game name cannot be empty.');
      return;
    }

    int? threshold;
    if (_hasThreshold) {
      threshold = int.tryParse(_thresholdController.text.trim());
      if (threshold == null || threshold <= 0) {
        setState(() => _errorText = 'Threshold must be a positive integer.');
        return;
      }
    }

    Navigator.of(context).pop(
      AddGameTypeDialogResult(
        name: name,
        hasThreshold: _hasThreshold,
        thresholdValue: threshold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Add Custom Game Type'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Game Name',
                hintText: 'e.g. Teen Patti, Rummy, Yaniv',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Winning Threshold',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Game automatically ends when a player reaches this score',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              value: _hasThreshold,
              onChanged: (val) {
                setState(() => _hasThreshold = val);
              },
            ),
            if (_hasThreshold) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Points',
                  hintText: 'e.g. 20, 50, 100',
                  suffixText: 'points',
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _onSave,
          child: const Text('Add Game'),
        ),
      ],
    );
  }
}
