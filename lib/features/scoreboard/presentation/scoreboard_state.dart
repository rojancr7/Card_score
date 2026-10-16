import '../../../shared/models/game.dart';
import '../../../shared/models/game_player.dart';
import '../../../shared/models/round.dart';
import '../../../shared/models/score_entry.dart';

class ScoreboardState {
  final Game? game;
  final List<GamePlayer> players;
  final List<Round> rounds;
  final List<ScoreEntry> scores;
  final Map<String, int> totals;
  final List<String> winningPlayerIds;
  final bool isLoading;
  final String? errorMessage;
  final bool showGameOverDialog;
  final bool hasSoundPlayedForCurrentFinish;

  const ScoreboardState({
    this.game,
    this.players = const [],
    this.rounds = const [],
    this.scores = const [],
    this.totals = const {},
    this.winningPlayerIds = const [],
    this.isLoading = false,
    this.errorMessage,
    this.showGameOverDialog = false,
    this.hasSoundPlayedForCurrentFinish = false,
  });

  /// Quick helper to lookup score for a given round & player
  int? getScore(String roundId, String playerId) {
    for (final entry in scores) {
      if (entry.roundId == roundId && entry.playerId == playerId) {
        return entry.score;
      }
    }
    return null;
  }

  /// Check whether an entry exists (to differentiate null/unrecorded from not found)
  bool hasEntry(String roundId, String playerId) {
    return scores.any((e) => e.roundId == roundId && e.playerId == playerId);
  }

  ScoreboardState copyWith({
    Game? game,
    List<GamePlayer>? players,
    List<Round>? rounds,
    List<ScoreEntry>? scores,
    Map<String, int>? totals,
    List<String>? winningPlayerIds,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? showGameOverDialog,
    bool? hasSoundPlayedForCurrentFinish,
  }) {
    return ScoreboardState(
      game: game ?? this.game,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      scores: scores ?? this.scores,
      totals: totals ?? this.totals,
      winningPlayerIds: winningPlayerIds ?? this.winningPlayerIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      showGameOverDialog: showGameOverDialog ?? this.showGameOverDialog,
      hasSoundPlayedForCurrentFinish:
          hasSoundPlayedForCurrentFinish ?? this.hasSoundPlayedForCurrentFinish,
    );
  }
}
