import 'package:flutter/material.dart';
import '../../../../shared/models/game_player.dart';
import '../../../../shared/models/round.dart';
import '../../../../shared/models/score_entry.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import 'edit_player_dialog.dart';
import 'score_input_dialog.dart';

class ScoreTableWidget extends StatelessWidget {
  final List<GamePlayer> players;
  final List<Round> rounds;
  final List<ScoreEntry> scores;
  final Map<String, int> totals;
  final List<String> winningPlayerIds;
  final bool isGameFinished;
  final int maxScoreLimit;
  final Function(String playerId, String newName) onRenamePlayer;
  final Function(String roundId, String playerId, int? score) onSetScore;
  final Function(String roundId) onDeleteRound;

  const ScoreTableWidget({
    super.key,
    required this.players,
    required this.rounds,
    required this.scores,
    required this.totals,
    required this.winningPlayerIds,
    required this.isGameFinished,
    required this.maxScoreLimit,
    required this.onRenamePlayer,
    required this.onSetScore,
    required this.onDeleteRound,
  });

  int? _lookupScore(String roundId, String playerId) {
    for (final entry in scores) {
      if (entry.roundId == roundId && entry.playerId == playerId) {
        return entry.score;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final totalBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Table layout with fixed round column and flexible 4 player columns
        const double roundColWidth = 72.0;
        final double availableForPlayers = constraints.maxWidth - roundColWidth - 40;
        final double playerColWidth = (availableForPlayers / 4).clamp(70.0, 200.0);
        final double totalTableWidth = roundColWidth + (playerColWidth * 4) + 40;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: totalTableWidth > constraints.maxWidth ? totalTableWidth : constraints.maxWidth,
            child: Column(
              children: [
                // 1. STICKY / FIXED HEADER ROW (Players)
                Container(
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(
                      top: BorderSide(color: borderColor, width: 1.5),
                      bottom: BorderSide(color: borderColor, width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildHeaderCell(
                        title: 'Round',
                        width: roundColWidth,
                        colorScheme: colorScheme,
                        alignment: Alignment.center,
                      ),
                      for (int i = 0; i < players.length; i++)
                        Expanded(
                          child: _buildPlayerHeaderCell(
                            context: context,
                            player: players[i],
                            playerNumber: i + 1,
                            isWinner: winningPlayerIds.contains(players[i].id),
                            colorScheme: colorScheme,
                          ),
                        ),
                      // Space for delete round action column
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // 2. SCROLLABLE ROUNDS LIST
                Expanded(
                  child: rounds.isEmpty
                      ? Center(
                          child: Text(
                            'No rounds yet. Tap "+ Add Round" to start recording scores.',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: rounds.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            color: borderColor,
                          ),
                          itemBuilder: (context, index) {
                            final round = rounds[index];
                            final isEven = index.isEven;
                            final rowBg = isEven
                                ? (isDark ? const Color(0xFF141E33) : Colors.white)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));

                            return Container(
                              color: rowBg,
                              height: 52,
                              child: Row(
                                children: [
                                  // Round Number
                                  SizedBox(
                                    width: roundColWidth,
                                    child: Center(
                                      child: Text(
                                        'R${round.roundNumber}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 4 Player Score Cells
                                  for (final player in players)
                                    Expanded(
                                      child: _buildScoreCell(
                                        context: context,
                                        round: round,
                                        player: player,
                                        score: _lookupScore(round.id, player.id),
                                        colorScheme: colorScheme,
                                      ),
                                    ),
                                  // Delete Round Action Button
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: colorScheme.error.withValues(alpha: 0.6),
                                      ),
                                      tooltip: 'Delete Round ${round.roundNumber}',
                                      onPressed: () async {
                                        final confirmed = await ConfirmDialog.show(
                                          context: context,
                                          title: 'Delete Round ${round.roundNumber}?',
                                          message:
                                              'Are you sure you want to delete this round? All entered scores for this round will be lost.',
                                          confirmLabel: 'Delete Round',
                                          isDestructive: true,
                                        );
                                        if (confirmed) {
                                          onDeleteRound(round.id);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // 3. STICKY TOTALS FOOTER ROW
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: totalBg,
                    border: Border(
                      top: BorderSide(color: borderColor, width: 2),
                      bottom: BorderSide(color: borderColor, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: roundColWidth,
                        child: const Center(
                          child: Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      for (final player in players)
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (winningPlayerIds.contains(player.id))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4.0),
                                    child: Icon(Icons.star, size: 16, color: Colors.amber),
                                  ),
                                Text(
                                  '${totals[player.id] ?? 0}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: winningPlayerIds.contains(player.id)
                                        ? Colors.amber
                                        : colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell({
    required String title,
    required double width,
    required ColorScheme colorScheme,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      alignment: alignment,
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildPlayerHeaderCell({
    required BuildContext context,
    required GamePlayer player,
    required int playerNumber,
    required bool isWinner,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: () async {
        final newName = await EditPlayerDialog.show(
          context: context,
          currentName: player.name,
          playerNumber: playerNumber,
        );
        if (newName != null && newName.isNotEmpty) {
          onRenamePlayer(player.id, newName);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isWinner)
                  const Padding(
                    padding: EdgeInsets.only(right: 4.0),
                    child: Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                  ),
                Flexible(
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isWinner ? Colors.amber : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.edit,
                  size: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'P$playerNumber',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCell({
    required BuildContext context,
    required Round round,
    required GamePlayer player,
    required int? score,
    required ColorScheme colorScheme,
  }) {
    // Distinguish between empty score (null) and explicit zero (0)
    final bool isEmpty = score == null;
    final String displayText = isEmpty ? '—' : '$score';

    return InkWell(
      onTap: () async {
        final result = await ScoreInputDialog.show(
          context: context,
          playerName: player.name,
          roundNumber: round.roundNumber,
          currentScore: score,
          maxScoreLimit: maxScoreLimit,
        );

        if (result != null) {
          if (result.isCleared) {
            onSetScore(round.id, player.id, null);
          } else {
            onSetScore(round.id, player.id, result.score);
          }
        }
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isEmpty
                ? Colors.transparent
                : colorScheme.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w700,
              fontSize: 16,
              color: isEmpty
                  ? colorScheme.onSurface.withValues(alpha: 0.3)
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
