import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/game.dart';
import '../../games/presentation/game_types_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import 'scoreboard_controller.dart';
import 'widgets/game_over_dialog.dart';
import 'widgets/new_game_dialog.dart';
import 'widgets/reset_dialog.dart';
import 'widgets/score_table_widget.dart';

class ScoreboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenHistory;

  const ScoreboardScreen({
    super.key,
    required this.onOpenHistory,
  });

  @override
  ConsumerState<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends ConsumerState<ScoreboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scoreboardControllerProvider.notifier).initialize();
    });
  }

  void _checkAndShowGameOverDialog() {
    final state = ref.read(scoreboardControllerProvider);
    if (state.showGameOverDialog && state.game != null) {
      final winningPlayers = state.players
          .where((p) => state.winningPlayerIds.contains(p.id))
          .toList();

      GameOverDialog.show(
        context: context,
        gameTypeName: state.game!.gameTypeName,
        thresholdValue: state.game!.thresholdValue,
        winningPlayers: winningPlayers,
        totals: state.totals,
        onViewScoreboard: () {
          ref.read(scoreboardControllerProvider.notifier).dismissGameOverDialog();
        },
        onNewGame: () {
          ref.read(scoreboardControllerProvider.notifier).dismissGameOverDialog();
          _showNewGameDialog();
        },
        onOpenHistory: () {
          ref.read(scoreboardControllerProvider.notifier).dismissGameOverDialog();
          widget.onOpenHistory();
        },
      );
    }
  }

  Future<void> _showNewGameDialog() async {
    final gameTypesState = ref.read(gameTypesControllerProvider);
    final scoreboardState = ref.read(scoreboardControllerProvider);

    final currentNames = scoreboardState.players.map((p) => p.name).toList();

    final result = await NewGameDialog.show(
      context: context,
      availableGameTypes: gameTypesState.gameTypes,
      currentNames: currentNames,
    );

    if (result != null) {
      await ref.read(scoreboardControllerProvider.notifier).startNewGame(
            gameType: result.gameType,
            playerNames: result.playerNames,
          );
    }
  }

  Future<void> _showResetDialog() async {
    final choice = await ResetDialog.show(context);
    if (!mounted) return;

    if (choice == ResetChoice.keepNames) {
      await ref
          .read(scoreboardControllerProvider.notifier)
          .resetCurrentGame(keepPlayerNames: true);
    } else if (choice == ResetChoice.defaultNames) {
      await ref
          .read(scoreboardControllerProvider.notifier)
          .resetCurrentGame(keepPlayerNames: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scoreboardControllerProvider, (prev, next) {
      if (next.showGameOverDialog && !(prev?.showGameOverDialog ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowGameOverDialog();
        });
      }
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final state = ref.watch(scoreboardControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (state.isLoading && state.game == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final game = state.game;
    if (game == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No active game found.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(scoreboardControllerProvider.notifier).initialize(),
              child: const Text('Start Game'),
            ),
          ],
        ),
      );
    }

    final isFinished = game.isFinished;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // TOP STATUS & CONTROLS BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Game Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          game.gameTypeName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Target Badge if configured
                      if (game.hasThreshold && game.thresholdValue != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flag, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${game.thresholdValue} pts target',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      // Status Badge (Active or Finished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFinished
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFinished ? Icons.check_circle : Icons.play_circle_fill,
                              size: 14,
                              color: isFinished ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFinished ? 'FINISHED' : 'ACTIVE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isFinished ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Action buttons row
                  Row(
                    children: [
                      Text(
                        'Round ${state.rounds.length}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      // Reset Game Action
                      OutlinedButton.icon(
                        onPressed: _showResetDialog,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Finish Game Action (if active)
                      if (!isFinished) ...[
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(scoreboardControllerProvider.notifier)
                              .finishGameManually(),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Finish'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // New Game Action
                      FilledButton.icon(
                        onPressed: _showNewGameDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Game'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // MAIN SCOREBOARD TABLE
            Expanded(
              child: ScoreTableWidget(
                players: state.players,
                rounds: state.rounds,
                scores: state.scores,
                totals: state.totals,
                winningPlayerIds: state.winningPlayerIds,
                isGameFinished: isFinished,
                maxScoreLimit: settings.maxScoreLimit,
                onRenamePlayer: (playerId, newName) {
                  ref
                      .read(scoreboardControllerProvider.notifier)
                      .renamePlayer(playerId, newName);
                },
                onSetScore: (roundId, playerId, score) {
                  ref
                      .read(scoreboardControllerProvider.notifier)
                      .setScore(roundId: roundId, playerId: playerId, score: score);
                },
                onDeleteRound: (roundId) {
                  ref
                      .read(scoreboardControllerProvider.notifier)
                      .deleteRound(roundId);
                },
              ),
            ),
          ],
        ),
      ),
      // FLOATING ACTION BUTTON: + ADD ROUND
      floatingActionButton: isFinished
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                ref.read(scoreboardControllerProvider.notifier).addRound();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Round'),
            ),
    );
  }
}
