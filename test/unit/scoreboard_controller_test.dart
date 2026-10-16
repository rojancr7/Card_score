import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:card_score/core/audio/audio_service.dart';
import 'package:card_score/core/constants/app_constants.dart';
import 'package:card_score/core/database/database_service.dart';
import 'package:card_score/features/scoreboard/data/game_repository.dart';
import 'package:card_score/features/scoreboard/presentation/scoreboard_controller.dart';
import 'package:card_score/shared/models/game.dart';
import 'package:card_score/shared/models/game_type.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late DatabaseService dbService;
  late SqliteGameRepository repository;
  late NoOpAudioService audioService;
  late ProviderContainer container;
  late ScoreboardController controller;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbService = DatabaseService(db: db);
    await db.execute('PRAGMA foreign_keys = ON');

    // Schema
    await db.execute('''
      CREATE TABLE game_types (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        has_threshold INTEGER NOT NULL DEFAULT 0,
        threshold_value INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_built_in INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE games (
        id TEXT PRIMARY KEY,
        game_type_id TEXT,
        game_type_name TEXT NOT NULL,
        has_threshold INTEGER NOT NULL,
        threshold_value INTEGER,
        status TEXT NOT NULL,
        winning_player_ids TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        finished_at INTEGER,
        FOREIGN KEY (game_type_id) REFERENCES game_types (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE game_players (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        name TEXT NOT NULL,
        player_order INTEGER NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE rounds (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        round_number INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE score_entries (
        id TEXT PRIMARY KEY,
        round_id TEXT NOT NULL,
        game_id TEXT NOT NULL,
        player_id TEXT NOT NULL,
        score INTEGER,
        FOREIGN KEY (round_id) REFERENCES rounds (id) ON DELETE CASCADE,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES game_players (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    repository = SqliteGameRepository(dbService);
    await repository.saveGameType(
      GameType(
        id: AppConstants.larraId,
        name: AppConstants.larraName,
        hasThreshold: true,
        thresholdValue: AppConstants.larraDefaultThreshold,
        isBuiltIn: true,
        createdAt: DateTime.now(),
      ),
    );

    audioService = NoOpAudioService();

    container = ProviderContainer(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        gameRepositoryProvider.overrideWithValue(repository),
        audioServiceProvider.overrideWithValue(audioService),
      ],
    );

    controller = container.read(scoreboardControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('ScoreboardController Tests', () {
    test('Initialize creates new default game when none exists', () async {
      await controller.initialize();

      final state = container.read(scoreboardControllerProvider);
      expect(state.game, isNotNull);
      expect(state.game!.gameTypeName, AppConstants.larraName);
      expect(state.players.length, 4);
      expect(state.rounds.length, 1);
      expect(state.rounds.first.roundNumber, 1);
      expect(state.scores.length, 4);
      expect(state.showGameOverDialog, isFalse);
    });

    test('Rename player updates state and database', () async {
      await controller.initialize();
      final p1 = container.read(scoreboardControllerProvider).players.first;

      await controller.renamePlayer(p1.id, 'Rohan');

      expect(container.read(scoreboardControllerProvider).players.first.name, 'Rohan');

      final dbPlayers = await repository.getPlayersForGame(container.read(scoreboardControllerProvider).game!.id);
      expect(dbPlayers.first.name, 'Rohan');
    });

    test('Add round appends new round and empty score entries', () async {
      await controller.initialize();
      await controller.addRound();

      final state = container.read(scoreboardControllerProvider);
      expect(state.rounds.length, 2);
      expect(state.rounds[1].roundNumber, 2);
      expect(state.scores.length, 8); // 4 for R1 + 4 for R2
    });

    test('Entering scores recalculates totals and triggers game-over sound exactly once', () async {
      await controller.initialize();
      final p1 = container.read(scoreboardControllerProvider).players[0];
      final r1 = container.read(scoreboardControllerProvider).rounds[0];

      // Enter score 10 in Round 1
      await controller.setScore(roundId: r1.id, playerId: p1.id, score: 10);
      expect(container.read(scoreboardControllerProvider).totals[p1.id], 10);
      expect(container.read(scoreboardControllerProvider).game!.status, GameStatus.active);
      expect(audioService.playCount, 0);

      // Add Round 2 and enter 10 (Total: 20 -> Larra threshold reached!)
      await controller.addRound();
      final r2 = container.read(scoreboardControllerProvider).rounds[1];
      await controller.setScore(roundId: r2.id, playerId: p1.id, score: 10);

      final stateAfterScore = container.read(scoreboardControllerProvider);
      expect(stateAfterScore.totals[p1.id], 20);
      expect(stateAfterScore.game!.status, GameStatus.finished);
      expect(stateAfterScore.winningPlayerIds, [p1.id]);
      expect(stateAfterScore.showGameOverDialog, isTrue);
      expect(audioService.playCount, 1);

      // Further score edit during finished state should not re-play audio sound if already played
      await controller.setScore(roundId: r2.id, playerId: p1.id, score: 15);
      expect(container.read(scoreboardControllerProvider).totals[p1.id], 25);
      expect(audioService.playCount, 1);
    });

    test('Score correction dropping total below threshold reverts game to active', () async {
      await controller.initialize();
      final p1 = container.read(scoreboardControllerProvider).players[0];
      final r1 = container.read(scoreboardControllerProvider).rounds[0];

      // Reach 20 -> finished
      await controller.setScore(roundId: r1.id, playerId: p1.id, score: 20);
      expect(container.read(scoreboardControllerProvider).game!.status, GameStatus.finished);
      expect(audioService.playCount, 1);

      // Correct score to 18 -> reverts to active
      await controller.setScore(roundId: r1.id, playerId: p1.id, score: 18);
      final correctedState = container.read(scoreboardControllerProvider);
      expect(correctedState.totals[p1.id], 18);
      expect(correctedState.game!.status, GameStatus.active);
      expect(correctedState.winningPlayerIds, isEmpty);
      expect(correctedState.showGameOverDialog, isFalse);
    });

    test('Deleting round updates totals and state', () async {
      await controller.initialize();
      final p1 = container.read(scoreboardControllerProvider).players[0];
      final r1 = container.read(scoreboardControllerProvider).rounds[0];

      await controller.setScore(roundId: r1.id, playerId: p1.id, score: 5);
      await controller.addRound();
      final r2 = container.read(scoreboardControllerProvider).rounds[1];
      await controller.setScore(roundId: r2.id, playerId: p1.id, score: 7);

      expect(container.read(scoreboardControllerProvider).totals[p1.id], 12);

      await controller.deleteRound(r2.id);
      final stateAfterDelete = container.read(scoreboardControllerProvider);
      expect(stateAfterDelete.rounds.length, 1);
      expect(stateAfterDelete.totals[p1.id], 5);
    });

    test('Reset current game preserves configured player names', () async {
      await controller.initialize();
      final p1 = container.read(scoreboardControllerProvider).players[0];
      await controller.renamePlayer(p1.id, 'Alice In Wonderland');
      await controller.setScore(
        roundId: container.read(scoreboardControllerProvider).rounds[0].id,
        playerId: p1.id,
        score: 15,
      );

      await controller.resetCurrentGame(keepPlayerNames: true);

      final resetState = container.read(scoreboardControllerProvider);
      expect(resetState.players[0].name, 'Alice In Wonderland');
      expect(resetState.rounds.length, 1);
      expect(resetState.totals[p1.id], 0);
      expect(resetState.game!.status, GameStatus.active);
    });
  });
}
