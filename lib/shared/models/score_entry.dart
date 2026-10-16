/// Represents a single player's score entry for a specific round.
/// [score] is null if unrecorded (empty), or an integer (including 0).
class ScoreEntry {
  final String id;
  final String roundId;
  final String gameId;
  final String playerId;
  final int? score;

  const ScoreEntry({
    required this.id,
    required this.roundId,
    required this.gameId,
    required this.playerId,
    this.score,
  });

  bool get hasScore => score != null;

  ScoreEntry copyWith({
    String? id,
    String? roundId,
    String? gameId,
    String? playerId,
    int? score,
    bool clearScore = false,
  }) {
    return ScoreEntry(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      gameId: gameId ?? this.gameId,
      playerId: playerId ?? this.playerId,
      score: clearScore ? null : (score ?? this.score),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round_id': roundId,
      'game_id': gameId,
      'player_id': playerId,
      'score': score,
    };
  }

  factory ScoreEntry.fromMap(Map<String, dynamic> map) {
    return ScoreEntry(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      gameId: map['game_id'] as String,
      playerId: map['player_id'] as String,
      score: map['score'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          roundId == other.roundId &&
          gameId == other.gameId &&
          playerId == other.playerId &&
          score == other.score;

  @override
  int get hashCode =>
      id.hashCode ^
      roundId.hashCode ^
      gameId.hashCode ^
      playerId.hashCode ^
      score.hashCode;
}
