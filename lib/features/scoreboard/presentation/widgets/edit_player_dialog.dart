import 'package:flutter/material.dart';
import '../../domain/score_calculator.dart';

class EditPlayerDialog extends StatefulWidget {
  final String currentName;
  final int playerNumber; // 1, 2, 3, 4

  const EditPlayerDialog({
    super.key,
    required this.currentName,
    required this.playerNumber,
  });

  static Future<String?> show({
    required BuildContext context,
    required String currentName,
    required int playerNumber,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => EditPlayerDialog(
        currentName: currentName,
        playerNumber: playerNumber,
      ),
    );
  }

  @override
  State<EditPlayerDialog> createState() => _EditPlayerDialogState();
}

class _EditPlayerDialogState extends State<EditPlayerDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    try {
      final validName = ScoreCalculator.validatePlayerName(_controller.text);
      Navigator.of(context).pop(validName);
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Player ${widget.playerNumber} Name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Player Name',
          hintText: 'e.g. Alice',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _onSave(),
      ),
      actions: [
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
}
