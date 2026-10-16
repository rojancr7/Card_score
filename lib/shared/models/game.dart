import 'dart:convert';

enum GameStatus {
  active,
  finished,
}

/// Represents a specific game session
class Game {
  final String id;
  final String? gameTypeId;
  final String gameTypeName; // Historical snapshot
  final bool hasThreshold; // Snapshot of threshold rule
  final int? thresholdValue; // Snapshot of threshold value
  final GameStatus status;
  final List<String> winningPlayerIds; // List of qualifying winner player IDs
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finishedAt;

  const Game({
    required this.id,
    this.gameTypeId,
    required this.gameTypeName,
    required this.hasThreshold,
    this.thresholdValue,
    this.status = GameStatus.active,
    this.winningPlayerIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.finishedAt,
  });

  bool get isFinished => status == GameStatus.finished;
  bool get isActive => status == GameStatus.active;

  Game copyWith({
    String? id,
    String? gameTypeId,
    String? gameTypeName,
    bool? hasThreshold,
    int? thresholdValue,
    GameStatus? status,
    List<String>? winningPlayerIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? finishedAt,
  }) {
    return Game(
      id: id ?? this.id,
      gameTypeId: gameTypeId ?? this.gameTypeId,
      gameTypeName: gameTypeName ?? this.gameTypeName,
      hasThreshold: hasThreshold ?? this.hasThreshold,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      status: status ?? this.status,
      winningPlayerIds: winningPlayerIds ?? this.winningPlayerIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_type_id': gameTypeId,
      'game_type_name': gameTypeName,
      'has_threshold': hasThreshold ? 1 : 0,
      'threshold_value': thresholdValue,
      'status': status.name,
      'winning_player_ids': jsonEncode(winningPlayerIds),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'finished_at': finishedAt?.millisecondsSinceEpoch,
    };
  }

  factory Game.fromMap(Map<String, dynamic> map) {
    List<String> winners = [];
    final winnersRaw = map['winning_player_ids'];
    if (winnersRaw is String && winnersRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(winnersRaw);
        if (decoded is List) {
          winners = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        winners = [];
      }
    }

    return Game(
      id: map['id'] as String,
      gameTypeId: map['game_type_id'] as String?,
      gameTypeName: map['game_type_name'] as String,
      hasThreshold: (map['has_threshold'] as int?) == 1,
      thresholdValue: map['threshold_value'] as int?,
      status: (map['status'] as String?) == 'finished'
          ? GameStatus.finished
          : GameStatus.active,
      winningPlayerIds: winners,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      finishedAt: map['finished_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['finished_at'] as int)
          : null,
    );
  }
}
