import 'package:flutter/material.dart';
import '../../../../shared/models/game_player.dart';

enum GameOverAction {
  viewScoreboard,
  newGame,
  openHistory,
}

class GameOverDialog extends StatelessWidget {
  final String gameTypeName;
  final int? thresholdValue;
  final List<GamePlayer> winningPlayers;
  final Map<String, int> totals;
  final VoidCallback onViewScoreboard;
  final VoidCallback onNewGame;
  final VoidCallback onOpenHistory;

  const GameOverDialog({
    super.key,
    required this.gameTypeName,
    this.thresholdValue,
    required this.winningPlayers,
    required this.totals,
    required this.onViewScoreboard,
    required this.onNewGame,
    required this.onOpenHistory,
  });

  static Future<void> show({
    required BuildContext context,
    required String gameTypeName,
    required int? thresholdValue,
    required List<GamePlayer> winningPlayers,
    required Map<String, int> totals,
    required VoidCallback onViewScoreboard,
    required VoidCallback onNewGame,
    required VoidCallback onOpenHistory,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameOverDialog(
        gameTypeName: gameTypeName,
        thresholdValue: thresholdValue,
        winningPlayers: winningPlayers,
        totals: totals,
        onViewScoreboard: onViewScoreboard,
        onNewGame: onNewGame,
        onOpenHistory: onOpenHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final winnerTitle = winningPlayers.length > 1
        ? 'Winners Qualified!'
        : '${winningPlayers.firstOrNull?.name ?? "Player"} Wins!';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trophy and celebration icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 56,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'GAME OVER',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            winnerTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (thresholdValue != null)
            Text(
              'Reached the $thresholdValue-point target in $gameTypeName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          const SizedBox(height: 20),
          // Winner Card(s)
          ...winningPlayers.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${totals[p.id] ?? 0} pts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onNewGame();
              },
              icon: const Icon(Icons.replay),
              label: const Text('Start New Game / Rematch'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onViewScoreboard();
                    },
                    child: const Text('View Board'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenHistory();
                    },
                    child: const Text('Open History'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
