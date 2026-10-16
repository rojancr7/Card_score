import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/models/game_player.dart';
import '../../../shared/models/score_entry.dart';

/// Pure domain logic for score calculation and game threshold evaluation
class ScoreCalculator {
  ScoreCalculator._();

  /// Calculates cumulative total for each player based on recorded score entries.
  /// Players with no recorded scores receive a total of 0.
  static Map<String, int> calculateTotals({
    required List<GamePlayer> players,
    required List<ScoreEntry> scores,
  }) {
    final Map<String, int> totals = {
      for (final player in players) player.id: 0,
    };

    for (final entry in scores) {
      if (entry.score != null && totals.containsKey(entry.playerId)) {
        totals[entry.playerId] = totals[entry.playerId]! + entry.score!;
      }
    }

    return totals;
  }

  /// Evaluates whether any player has reached or exceeded the configured threshold.
  /// Returns a list of qualifying winner player IDs.
  /// If the game has no threshold enabled, returns an empty list.
  static List<String> evaluateWinners({
    required Map<String, int> totals,
    required bool hasThreshold,
    required int? thresholdValue,
  }) {
    if (!hasThreshold || thresholdValue == null) {
      return const [];
    }

    final qualifyingWinners = <String>[];
    for (final entry in totals.entries) {
      if (entry.value >= thresholdValue) {
        qualifyingWinners.add(entry.key);
      }
    }

    return qualifyingWinners;
  }

  /// Determines if a score change warrants transitioning the game status.
  /// Returns `true` if winners are present, `false` otherwise.
  static bool shouldFinishGame({
    required Map<String, int> totals,
    required bool hasThreshold,
    required int? thresholdValue,
  }) {
    final winners = evaluateWinners(
      totals: totals,
      hasThreshold: hasThreshold,
      thresholdValue: thresholdValue,
    );
    return winners.isNotEmpty;
  }

  /// Validates a player name. Throws [ValidationException] if invalid.
  static String validatePlayerName(String? name) {
    if (name == null || name.trim().isEmpty) {
      throw const ValidationException('Player name cannot be empty.');
    }
    final trimmed = name.trim();
    if (trimmed.length > 30) {
      throw const ValidationException('Player name cannot exceed 30 characters.');
    }
    return trimmed;
  }

  /// Validates an entered score against defined min and max limits.
  static int validateScore(
    int score, {
    int min = AppConstants.minScore,
    int max = AppConstants.maxScore,
  }) {
    if (score < min || score > max) {
      throw ValidationException('Score must be between $min and $max.');
    }
    return score;
  }
}
