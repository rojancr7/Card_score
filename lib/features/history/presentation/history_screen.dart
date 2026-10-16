import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/game.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../games/presentation/game_types_controller.dart';
import '../../scoreboard/presentation/scoreboard_controller.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenScoreboard;

  const HistoryScreen({
    super.key,
    required this.onOpenScoreboard,
  });

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyControllerProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final gameTypesState = ref.watch(gameTypesControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        actions: [
          IconButton(
            icon: Icon(state.sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: state.sortAscending ? 'Oldest first' : 'Newest first',
            onPressed: () {
              ref.read(historyControllerProvider.notifier).toggleSortOrder();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(historyControllerProvider.notifier).loadHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH & FILTER BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by player name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(historyControllerProvider.notifier).setSearchQuery(null);
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    ref.read(historyControllerProvider.notifier).setSearchQuery(val);
                  },
                ),
                const SizedBox(height: 8),
                // Filter chips (Game Types & Status)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status filter chips
                      FilterChip(
                        label: const Text('All'),
                        selected: state.statusFilter == null,
                        onSelected: (_) =>
                            ref.read(historyControllerProvider.notifier).setStatusFilter(null),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Active'),
                        selected: state.statusFilter == GameStatus.active,
                        onSelected: (selected) => ref
                            .read(historyControllerProvider.notifier)
                            .setStatusFilter(selected ? GameStatus.active : null),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Finished'),
                        selected: state.statusFilter == GameStatus.finished,
                        onSelected: (selected) => ref
                            .read(historyControllerProvider.notifier)
                            .setStatusFilter(selected ? GameStatus.finished : null),
                      ),
                      const SizedBox(width: 12),
                      // Divider
                      Container(height: 20, width: 1, color: theme.dividerColor),
                      const SizedBox(width: 12),
                      // Game type dropdown / chips
                      for (final type in gameTypesState.gameTypes) ...[
                        FilterChip(
                          label: Text(type.name),
                          selected: state.selectedGameTypeId == type.id,
                          onSelected: (selected) => ref
                              .read(historyControllerProvider.notifier)
                              .setGameTypeFilter(selected ? type.id : null),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // HISTORY LIST
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No games match your filters.',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          final game = item.game;
                          final isFinished = game.isFinished;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: theme.dividerColor),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                // Resume / inspect this game in the scoreboard
                                await ref
                                    .read(scoreboardControllerProvider.notifier)
                                    .initialize(loadGameId: game.id);
                                widget.onOpenScoreboard();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Game type, date, status
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            game.gameTypeName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${item.roundCount} Rounds',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isFinished
                                                ? Colors.red.withValues(alpha: 0.12)
                                                : Colors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isFinished ? 'Finished' : 'Active',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isFinished ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatDate(game.updatedAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const Divider(height: 20),
                                    // Players and scores row
                                    Row(
                                      children: [
                                        for (final player in item.players)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  player.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: game.winningPlayerIds
                                                            .contains(player.id)
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color: game.winningPlayerIds
                                                            .contains(player.id)
                                                        ? Colors.amber
                                                        : colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (game.winningPlayerIds
                                                        .contains(player.id))
                                                      const Padding(
                                                        padding: EdgeInsets.only(right: 2.0),
                                                        child: Icon(
                                                          Icons.star,
                                                          size: 14,
                                                          color: Colors.amber,
                                                        ),
                                                      ),
                                                    Text(
                                                      '${item.totals[player.id] ?? 0}',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                        color: game.winningPlayerIds
                                                                .contains(player.id)
                                                            ? Colors.amber
                                                            : colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Bottom card actions: Rematch & Delete
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () async {
                                            // Start rematch with same players
                                            final gameTypes =
                                                ref.read(gameTypesControllerProvider).gameTypes;
                                            final matchingType = gameTypes.firstWhere(
                                              (t) => t.id == game.gameTypeId,
                                              orElse: () => gameTypes.first,
                                            );

                                            await ref
                                                .read(scoreboardControllerProvider.notifier)
                                                .startNewGame(
                                                  gameType: matchingType,
                                                  playerNames:
                                                      item.players.map((p) => p.name).toList(),
                                                );
                                            widget.onOpenScoreboard();
                                          },
                                          icon: const Icon(Icons.replay, size: 16),
                                          label: const Text('Rematch'),
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: colorScheme.error.withValues(alpha: 0.7),
                                          ),
                                          tooltip: 'Delete game',
                                          onPressed: () async {
                                            final confirmed = await ConfirmDialog.show(
                                              context: context,
                                              title: 'Delete this game?',
                                              message:
                                                  'This will permanently remove this game record from your history.',
                                              confirmLabel: 'Delete Game',
                                              isDestructive: true,
                                            );
                                            if (confirmed) {
                                              await ref
                                                  .read(historyControllerProvider.notifier)
                                                  .deleteGame(game.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
