import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../shared/models/game.dart';
import '../../../shared/models/game_player.dart';
import '../../../shared/models/game_type.dart';
import '../../../shared/models/round.dart';
import '../../../shared/models/score_entry.dart';
import '../data/game_repository.dart';
import '../domain/score_calculator.dart';
import 'scoreboard_state.dart';

// Providers
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteGameRepository(dbService);
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AppAudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

final scoreboardControllerProvider =
    NotifierProvider<ScoreboardController, ScoreboardState>(
  ScoreboardController.new,
);

class ScoreboardController extends Notifier<ScoreboardState> {
  GameRepository? _overrideRepository;
  AudioService? _overrideAudioService;

  ScoreboardController({
    GameRepository? repository,
    AudioService? audioService,
  })  : _overrideRepository = repository,
        _overrideAudioService = audioService;

  GameRepository get _repository =>
      _overrideRepository ?? ref.read(gameRepositoryProvider);
  AudioService get _audioService =>
      _overrideAudioService ?? ref.read(audioServiceProvider);

  @override
  ScoreboardState build() {
    return const ScoreboardState();
  }

  /// Initializes the scoreboard with either a specified game or the latest active game.
  Future<void> initialize({String? loadGameId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      Game? game;
      if (loadGameId != null) {
        game = await _repository.getGameById(loadGameId);
      } else {
        game = await _repository.getActiveGame();
      }

      if (game == null) {
        // Create initial game with default settings
        final defaultType = await _repository.getGameType(AppConstants.larraId) ??
            GameType(
              id: AppConstants.larraId,
              name: AppConstants.larraName,
              hasThreshold: true,
              thresholdValue: AppConstants.larraDefaultThreshold,
              createdAt: DateTime.now(),
            );
        game = await _repository.createNewGame(gameType: defaultType);
      }

      if (!ref.mounted) return;
      await _loadGameDetails(game, isFreshlyFinished: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize scoreboard: $e',
      );
    }
  }

  Future<void> _loadGameDetails(Game game, {bool isFreshlyFinished = false}) async {
    final players = await _repository.getPlayersForGame(game.id);
    final rounds = await _repository.getRoundsForGame(game.id);
    final scores = await _repository.getScoresForGame(game.id);

    final totals = ScoreCalculator.calculateTotals(
      players: players,
      scores: scores,
    );

    final winners = ScoreCalculator.evaluateWinners(
      totals: totals,
      hasThreshold: game.hasThreshold,
      thresholdValue: game.thresholdValue,
    );

    final isAlreadyFinished = game.isFinished;

    if (!ref.mounted) return;
    state = state.copyWith(
      game: game,
      players: players,
      rounds: rounds,
      scores: scores,
      totals: totals,
      winningPlayerIds: game.winningPlayerIds.isNotEmpty ? game.winningPlayerIds : winners,
      isLoading: false,
      showGameOverDialog: isFreshlyFinished,
      hasSoundPlayedForCurrentFinish: isAlreadyFinished || isFreshlyFinished,
      clearError: true,
    );
  }

  /// Renames a player and updates state
  Future<void> renamePlayer(String playerId, String newName) async {
    try {
      final validatedName = ScoreCalculator.validatePlayerName(newName);
      await _repository.updatePlayerName(playerId, validatedName);

      final updatedPlayers = state.players.map((p) {
        if (p.id == playerId) {
          return p.copyWith(name: validatedName);
        }
        return p;
      }).toList();

      state = state.copyWith(players: updatedPlayers, clearError: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// Adds a new round to the current game
  Future<void> addRound() async {
    final game = state.game;
    if (game == null) return;

    if (game.isFinished) {
      state = state.copyWith(
        errorMessage: 'Cannot add rounds to a finished game. Reopen or reset the game first.',
      );
      return;
    }

    try {
      final nextRoundNumber = state.rounds.length + 1;
      final newRound = await _repository.addRound(game.id, nextRoundNumber);
      final updatedRounds = [...state.rounds, newRound];

      // Refresh scores
      final updatedScores = await _repository.getScoresForGame(game.id);

      if (!ref.mounted) return;
      state = state.copyWith(
        rounds: updatedRounds,
        scores: updatedScores,
        clearError: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: 'Failed to add round: $e');
    }
  }

  /// Deletes a round and recalculates totals and winning status
  Future<void> deleteRound(String roundId) async {
    final game = state.game;
    if (game == null) return;

    try {
      await _repository.deleteRound(roundId);

      // Reload rounds and scores
      final updatedRounds = await _repository.getRoundsForGame(game.id);
      final updatedScores = await _repository.getScoresForGame(game.id);

      final newTotals = ScoreCalculator.calculateTotals(
        players: state.players,
        scores: updatedScores,
      );

      final winners = ScoreCalculator.evaluateWinners(
        totals: newTotals,
        hasThreshold: game.hasThreshold,
        thresholdValue: game.thresholdValue,
      );

      Game updatedGame = game;
      bool showGameOver = state.showGameOverDialog;
      bool soundPlayed = state.hasSoundPlayedForCurrentFinish;

      if (game.isFinished && winners.isEmpty) {
        // Revert to active game
        await _repository.updateGameStatus(game.id, GameStatus.active, []);
        updatedGame = game.copyWith(status: GameStatus.active, winningPlayerIds: []);
        showGameOver = false;
        soundPlayed = false;
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        game: updatedGame,
        rounds: updatedRounds,
        scores: updatedScores,
        totals: newTotals,
        winningPlayerIds: winners,
        showGameOverDialog: showGameOver,
        hasSoundPlayedForCurrentFinish: soundPlayed,
        clearError: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: 'Failed to delete round: $e');
    }
  }

  /// Records, updates, or clears a score for a specific round and player.
  /// Automatically recalculates totals and triggers game-over transitions.
  Future<void> setScore({
    required String roundId,
    required String playerId,
    required int? score,
  }) async {
    final game = state.game;
    if (game == null) return;

    try {
      if (score != null) {
        ScoreCalculator.validateScore(score);
      }

      await _repository.setScore(
        roundId: roundId,
        gameId: game.id,
        playerId: playerId,
        score: score,
      );

      // Update in-memory scores
      final updatedScores = List<ScoreEntry>.from(state.scores);
      final index = updatedScores.indexWhere(
        (s) => s.roundId == roundId && s.playerId == playerId,
      );

      if (index >= 0) {
        updatedScores[index] = updatedScores[index].copyWith(
          score: score,
          clearScore: score == null,
        );
      } else {
        updatedScores.add(
          ScoreEntry(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
            roundId: roundId,
            gameId: game.id,
            playerId: playerId,
            score: score,
          ),
        );
      }

      // Recalculate totals
      final newTotals = ScoreCalculator.calculateTotals(
        players: state.players,
        scores: updatedScores,
      );

      // Evaluate winners
      final winners = ScoreCalculator.evaluateWinners(
        totals: newTotals,
        hasThreshold: game.hasThreshold,
        thresholdValue: game.thresholdValue,
      );

      Game updatedGame = game;
      bool showGameOver = state.showGameOverDialog;
      bool soundPlayed = state.hasSoundPlayedForCurrentFinish;

      if (winners.isNotEmpty && !game.isFinished) {
        // Transition to finished
        await _repository.updateGameStatus(game.id, GameStatus.finished, winners);
        updatedGame = game.copyWith(
          status: GameStatus.finished,
          winningPlayerIds: winners,
        );
        showGameOver = true;

        if (!soundPlayed) {
          _audioService.playGameOverAlert();
          soundPlayed = true;
        }
      } else if (winners.isEmpty && game.isFinished) {
        // Score correction reduced total below threshold -> Revert to active
        await _repository.updateGameStatus(game.id, GameStatus.active, []);
        updatedGame = game.copyWith(
          status: GameStatus.active,
          winningPlayerIds: [],
        );
        showGameOver = false;
        soundPlayed = false;
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        game: updatedGame,
        scores: updatedScores,
        totals: newTotals,
        winningPlayerIds: winners,
        showGameOverDialog: showGameOver,
        hasSoundPlayedForCurrentFinish: soundPlayed,
        clearError: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// Resets the current game (clearing rounds/scores back to Round 1)
  Future<void> resetCurrentGame({required bool keepPlayerNames}) async {
    final game = state.game;
    if (game == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.resetGame(game.id, keepPlayerNames: keepPlayerNames);
      final refreshedGame = await _repository.getGameById(game.id);
      if (refreshedGame != null) {
        if (!ref.mounted) return;
        await _loadGameDetails(refreshedGame, isFreshlyFinished: false);
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to reset game: $e',
      );
    }
  }

  /// Starts a new game with the chosen game type and optional player names
  Future<void> startNewGame({
    required GameType gameType,
    List<String>? playerNames,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newGame = await _repository.createNewGame(
        gameType: gameType,
        playerNames: playerNames,
      );
      if (!ref.mounted) return;
      await _loadGameDetails(newGame, isFreshlyFinished: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to start new game: $e',
      );
    }
  }

  /// Manually finishes an active game (useful for games without winning thresholds)
  Future<void> finishGameManually() async {
    final game = state.game;
    if (game == null || game.isFinished) return;

    try {
      final winners = ScoreCalculator.evaluateWinners(
        totals: state.totals,
        hasThreshold: game.hasThreshold,
        thresholdValue: game.thresholdValue,
      );

      await _repository.updateGameStatus(game.id, GameStatus.finished, winners);
      final updatedGame = game.copyWith(
        status: GameStatus.finished,
        winningPlayerIds: winners,
      );

      _audioService.playGameOverAlert();

      if (!ref.mounted) return;
      state = state.copyWith(
        game: updatedGame,
        winningPlayerIds: winners,
        showGameOverDialog: true,
        hasSoundPlayedForCurrentFinish: true,
        clearError: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: 'Failed to finish game: $e');
    }
  }

  void dismissGameOverDialog() {
    state = state.copyWith(showGameOverDialog: false);
  }

  void clearErrorMessage() {
    state = state.copyWith(clearError: true);
  }
}
