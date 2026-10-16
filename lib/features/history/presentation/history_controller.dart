import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/game.dart';
import '../../../shared/models/game_player.dart';
import '../../scoreboard/domain/score_calculator.dart';
import '../../scoreboard/presentation/scoreboard_controller.dart';

class HistoryGameItem {
  final Game game;
  final List<GamePlayer> players;
  final int roundCount;
  final Map<String, int> totals;

  const HistoryGameItem({
    required this.game,
    required this.players,
    required this.roundCount,
    required this.totals,
  });
}

class HistoryState {
  final List<HistoryGameItem> items;
  final bool isLoading;
  final String? searchQuery;
  final String? selectedGameTypeId;
  final GameStatus? statusFilter;
  final bool sortAscending; // false = newest first, true = oldest first
  final String? errorMessage;

  const HistoryState({
    this.items = const [],
    this.isLoading = false,
    this.searchQuery,
    this.selectedGameTypeId,
    this.statusFilter,
    this.sortAscending = false,
    this.errorMessage,
  });

  HistoryState copyWith({
    List<HistoryGameItem>? items,
    bool? isLoading,
    String? searchQuery,
    bool clearSearch = false,
    String? selectedGameTypeId,
    bool clearGameType = false,
    GameStatus? statusFilter,
    bool clearStatus = false,
    bool? sortAscending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      selectedGameTypeId: clearGameType ? null : (selectedGameTypeId ?? this.selectedGameTypeId),
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      sortAscending: sortAscending ?? this.sortAscending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(
  HistoryController.new,
);

class HistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    return const HistoryState();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(gameRepositoryProvider);
      final games = await repository.getHistoricalGames(
        searchQuery: state.searchQuery,
        gameTypeId: state.selectedGameTypeId,
        statusFilter: state.statusFilter,
      );

      final items = <HistoryGameItem>[];
      for (final game in games) {
        final players = await repository.getPlayersForGame(game.id);
        final rounds = await repository.getRoundsForGame(game.id);
        final scores = await repository.getScoresForGame(game.id);
        final totals = ScoreCalculator.calculateTotals(
          players: players,
          scores: scores,
        );

        items.add(
          HistoryGameItem(
            game: game,
            players: players,
            roundCount: rounds.length,
            totals: totals,
          ),
        );
      }

      // Sort
      if (state.sortAscending) {
        items.sort((a, b) => a.game.updatedAt.compareTo(b.game.updatedAt));
      } else {
        items.sort((a, b) => b.game.updatedAt.compareTo(a.game.updatedAt));
      }

      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load game history: $e',
      );
    }
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(
      searchQuery: query,
      clearSearch: query == null || query.isEmpty,
    );
    loadHistory();
  }

  void setGameTypeFilter(String? gameTypeId) {
    state = state.copyWith(
      selectedGameTypeId: gameTypeId,
      clearGameType: gameTypeId == null,
    );
    loadHistory();
  }

  void setStatusFilter(GameStatus? status) {
    state = state.copyWith(
      statusFilter: status,
      clearStatus: status == null,
    );
    loadHistory();
  }

  void toggleSortOrder() {
    state = state.copyWith(sortAscending: !state.sortAscending);
    loadHistory();
  }

  Future<void> deleteGame(String gameId) async {
    try {
      final repository = ref.read(gameRepositoryProvider);
      await repository.deleteGame(gameId);
      await loadHistory();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete game: $e');
    }
  }
}
