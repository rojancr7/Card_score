import 'package:flutter/material.dart';
import '../../../../shared/models/game_type.dart';

class NewGameDialogResult {
  final GameType gameType;
  final List<String> playerNames;

  const NewGameDialogResult({
    required this.gameType,
    required this.playerNames,
  });
}

class NewGameDialog extends StatefulWidget {
  final List<GameType> availableGameTypes;
  final GameType? initialGameType;
  final List<String> currentNames;

  const NewGameDialog({
    super.key,
    required this.availableGameTypes,
    this.initialGameType,
    required this.currentNames,
  });

  static Future<NewGameDialogResult?> show({
    required BuildContext context,
    required List<GameType> availableGameTypes,
    GameType? initialGameType,
    required List<String> currentNames,
  }) {
    return showDialog<NewGameDialogResult>(
      context: context,
      builder: (ctx) => NewGameDialog(
        availableGameTypes: availableGameTypes,
        initialGameType: initialGameType,
        currentNames: currentNames,
      ),
    );
  }

  @override
  State<NewGameDialog> createState() => _NewGameDialogState();
}

class _NewGameDialogState extends State<NewGameDialog> {
  late GameType _selectedType;
  late final List<TextEditingController> _nameControllers;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialGameType ??
        (widget.availableGameTypes.isNotEmpty
            ? widget.availableGameTypes.first
            : GameType(
                id: 'default',
                name: 'Larra',
                hasThreshold: true,
                thresholdValue: 20,
                createdAt: DateTime.now(),
              ));

    _nameControllers = List.generate(4, (i) {
      final defaultName = i < widget.currentNames.length
          ? widget.currentNames[i]
          : 'Player ${i + 1}';
      return TextEditingController(text: defaultName);
    });
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStart() {
    final names = _nameControllers.asMap().entries.map((entry) {
      final text = entry.value.text.trim();
      return text.isEmpty ? 'Player ${entry.key + 1}' : text;
    }).toList();

    Navigator.of(context).pop(
      NewGameDialogResult(
        gameType: _selectedType,
        playerNames: names,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Start New Game'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Game Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<GameType>(
                    isExpanded: true,
                    value: widget.availableGameTypes.any((t) => t.id == _selectedType.id)
                        ? widget.availableGameTypes.firstWhere((t) => t.id == _selectedType.id)
                        : _selectedType,
                    items: widget.availableGameTypes.map((type) {
                      final targetInfo = type.hasThreshold && type.thresholdValue != null
                          ? ' (${type.thresholdValue} pts target)'
                          : ' (No target)';
                      return DropdownMenuItem<GameType>(
                        value: type,
                        child: Text('${type.name}$targetInfo'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedType = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Players (4 Required)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: _nameControllers[i],
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person, size: 20, color: colorScheme.primary),
                      labelText: 'Player ${i + 1}',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _onStart,
          child: const Text('Start Game'),
        ),
      ],
    );
  }
}
