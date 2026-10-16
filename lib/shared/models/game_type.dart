/// Represents a game type (e.g. Larra, Callbreak, Marriage, Custom)
class GameType {
  final String id;
  final String name;
  final bool hasThreshold;
  final int? thresholdValue;
  final bool isActive;
  final bool isBuiltIn;
  final DateTime createdAt;

  const GameType({
    required this.id,
    required this.name,
    this.hasThreshold = false,
    this.thresholdValue,
    this.isActive = true,
    this.isBuiltIn = false,
    required this.createdAt,
  });

  GameType copyWith({
    String? id,
    String? name,
    bool? hasThreshold,
    int? thresholdValue,
    bool? isActive,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return GameType(
      id: id ?? this.id,
      name: name ?? this.name,
      hasThreshold: hasThreshold ?? this.hasThreshold,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      isActive: isActive ?? this.isActive,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'has_threshold': hasThreshold ? 1 : 0,
      'threshold_value': thresholdValue,
      'is_active': isActive ? 1 : 0,
      'is_built_in': isBuiltIn ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory GameType.fromMap(Map<String, dynamic> map) {
    return GameType(
      id: map['id'] as String,
      name: map['name'] as String,
      hasThreshold: (map['has_threshold'] as int?) == 1,
      thresholdValue: map['threshold_value'] as int?,
      isActive: (map['is_active'] as int?) == 1,
      isBuiltIn: (map['is_built_in'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameType &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          hasThreshold == other.hasThreshold &&
          thresholdValue == other.thresholdValue &&
          isActive == other.isActive &&
          isBuiltIn == other.isBuiltIn;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      hasThreshold.hashCode ^
      thresholdValue.hashCode ^
      isActive.hashCode ^
      isBuiltIn.hashCode;
}
