import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/score_calculator.dart';

class ScoreInputDialog extends StatefulWidget {
  final String playerName;
  final int roundNumber;
  final int? currentScore;
  final int maxScoreLimit;

  const ScoreInputDialog({
    super.key,
    required this.playerName,
    required this.roundNumber,
    required this.currentScore,
    this.maxScoreLimit = AppConstants.maxScore,
  });

  /// Returns null if user cancelled.
  /// Returns a record with isCleared = true if cleared.
  /// Returns an int score if saved.
  static Future<ScoreInputResult?> show({
    required BuildContext context,
    required String playerName,
    required int roundNumber,
    required int? currentScore,
    int maxScoreLimit = AppConstants.maxScore,
  }) {
    return showDialog<ScoreInputResult>(
      context: context,
      builder: (ctx) => ScoreInputDialog(
        playerName: playerName,
        roundNumber: roundNumber,
        currentScore: currentScore,
        maxScoreLimit: maxScoreLimit,
      ),
    );
  }

  @override
  State<ScoreInputDialog> createState() => _ScoreInputDialogState();
}

class ScoreInputResult {
  final int? score;
  final bool isCleared;

  const ScoreInputResult.value(this.score) : isCleared = false;
  const ScoreInputResult.clear()
      : score = null,
        isCleared = true;
}

class _ScoreInputDialogState extends State<ScoreInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentScore != null ? '${widget.currentScore}' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      // Empty input treated as clearing score
      Navigator.of(context).pop(const ScoreInputResult.clear());
      return;
    }

    final parsed = int.tryParse(text);
    if (parsed == null) {
      setState(() {
        _errorText = 'Please enter a valid whole number.';
      });
      return;
    }

    try {
      final validScore = ScoreCalculator.validateScore(
        parsed,
        max: widget.maxScoreLimit,
      );
      Navigator.of(context).pop(ScoreInputResult.value(validScore));
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onClear() {
    Navigator.of(context).pop(const ScoreInputResult.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.playerName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Round ${widget.roundNumber}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            // Dedicated numeric keypad on mobile devices with support for negative numbers
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: false,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0',
              errorText: _errorText,
              helperText: 'Accepts integers from ${AppConstants.minScore} to ${widget.maxScoreLimit}',
              helperMaxLines: 2,
            ),
            onSubmitted: (_) => _onSave(),
          ),
          const SizedBox(height: 12),
          // Quick shortcut buttons for common card score increments
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildQuickChip(0),
              _buildQuickChip(1),
              _buildQuickChip(2),
              _buildQuickChip(3),
              _buildQuickChip(5),
              _buildQuickChip(10),
            ],
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        if (widget.currentScore != null)
          TextButton.icon(
            onPressed: _onClear,
            icon: Icon(Icons.clear, size: 18, color: colorScheme.error),
            label: Text(
              'Clear Score',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildQuickChip(int value) {
    return ActionChip(
      label: Text('$value'),
      onPressed: () {
        _controller.text = '$value';
        setState(() => _errorText = null);
      },
    );
  }
}
