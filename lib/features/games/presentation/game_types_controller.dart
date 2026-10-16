import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../shared/models/game_type.dart';
import '../../scoreboard/presentation/scoreboard_controller.dart';

class GameTypesState {
  final List<GameType> gameTypes;
  final bool isLoading;
  final String? errorMessage;

  const GameTypesState({
    this.gameTypes = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  GameTypesState copyWith({
    List<GameType>? gameTypes,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GameTypesState(
      gameTypes: gameTypes ?? this.gameTypes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final gameTypesControllerProvider =
    NotifierProvider<GameTypesController, GameTypesState>(
  GameTypesController.new,
);

class GameTypesController extends Notifier<GameTypesState> {
  final Uuid _uuid = const Uuid();

  @override
  GameTypesState build() {
    return const GameTypesState();
  }

  Future<void> loadGameTypes() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(gameRepositoryProvider);
      final types = await repository.getAllGameTypes();
      state = state.copyWith(gameTypes: types, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load game types: $e',
      );
    }
  }

  Future<void> addCustomGameType({
    required String name,
    required bool hasThreshold,
    int? thresholdValue,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('Game type name cannot be empty.');
    }

    if (state.gameTypes.any((t) => t.name.toLowerCase() == trimmedName.toLowerCase())) {
      throw const ValidationException('A game type with this name already exists.');
    }

    if (hasThreshold) {
      if (thresholdValue == null || thresholdValue <= 0) {
        throw const ValidationException('Winning threshold must be greater than zero.');
      }
    }

    final newType = GameType(
      id: 'custom_${_uuid.v4()}',
      name: trimmedName,
      hasThreshold: hasThreshold,
      thresholdValue: hasThreshold ? thresholdValue : null,
      isActive: true,
      isBuiltIn: false,
      createdAt: DateTime.now(),
    );

    try {
      final repository = ref.read(gameRepositoryProvider);
      await repository.saveGameType(newType);
      await loadGameTypes();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save game type: $e');
      rethrow;
    }
  }

  Future<void> updateGameTypeThreshold({
    required String id,
    required bool hasThreshold,
    int? thresholdValue,
  }) async {
    if (hasThreshold && (thresholdValue == null || thresholdValue <= 0)) {
      throw const ValidationException('Winning threshold must be greater than zero.');
    }

    try {
      final repository = ref.read(gameRepositoryProvider);
      final existing = await repository.getGameType(id);
      if (existing == null) return;

      final updated = existing.copyWith(
        hasThreshold: hasThreshold,
        thresholdValue: hasThreshold ? thresholdValue : null,
      );

      await repository.saveGameType(updated);
      await loadGameTypes();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update game type: $e');
      rethrow;
    }
  }

  Future<void> deleteGameType(String id) async {
    try {
      final repository = ref.read(gameRepositoryProvider);
      await repository.deleteGameType(id);
      await loadGameTypes();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}
