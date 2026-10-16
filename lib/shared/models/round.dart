/// Represents a round in a game session
class Round {
  final String id;
  final String gameId;
  final int roundNumber;
  final DateTime createdAt;

  const Round({
    required this.id,
    required this.gameId,
    required this.roundNumber,
    required this.createdAt,
  });

  Round copyWith({
    String? id,
    String? gameId,
    int? roundNumber,
    DateTime? createdAt,
  }) {
    return Round(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      roundNumber: roundNumber ?? this.roundNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_id': gameId,
      'round_number': roundNumber,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Round.fromMap(Map<String, dynamic> map) {
    return Round(
      id: map['id'] as String,
      gameId: map['game_id'] as String,
      roundNumber: map['round_number'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Round &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          gameId == other.gameId &&
          roundNumber == other.roundNumber;

  @override
  int get hashCode => id.hashCode ^ gameId.hashCode ^ roundNumber.hashCode;
}
