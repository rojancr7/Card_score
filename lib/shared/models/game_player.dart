/// Represents a player in a game session
class GamePlayer {
  final String id;
  final String gameId;
  final String name;
  final int playerOrder; // 0, 1, 2, 3

  const GamePlayer({
    required this.id,
    required this.gameId,
    required this.name,
    required this.playerOrder,
  });

  GamePlayer copyWith({
    String? id,
    String? gameId,
    String? name,
    int? playerOrder,
  }) {
    return GamePlayer(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      name: name ?? this.name,
      playerOrder: playerOrder ?? this.playerOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_id': gameId,
      'name': name,
      'player_order': playerOrder,
    };
  }

  factory GamePlayer.fromMap(Map<String, dynamic> map) {
    return GamePlayer(
      id: map['id'] as String,
      gameId: map['game_id'] as String,
      name: map['name'] as String,
      playerOrder: map['player_order'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamePlayer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          gameId == other.gameId &&
          name == other.name &&
          playerOrder == other.playerOrder;

  @override
  int get hashCode =>
      id.hashCode ^ gameId.hashCode ^ name.hashCode ^ playerOrder.hashCode;
}
