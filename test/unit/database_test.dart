import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:card_score/core/database/database_service.dart';
import 'package:card_score/features/scoreboard/data/game_repository.dart';
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

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbService = DatabaseService(db: db);
    // Initialize schema and seed data manually for in-memory test db
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

    // Seed default test game type
    await repository.saveGameType(
      GameType(
        id: 'larra_test',
        name: 'Larra Test',
        hasThreshold: true,
        thresholdValue: 20,
        createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SqliteGameRepository Integration Tests', () {
    test('Create new game seeds 4 players and Round 1 with empty scores', () async {
      final larra = GameType(
        id: 'larra_test',
        name: 'Larra Test',
        hasThreshold: true,
        thresholdValue: 20,
        createdAt: DateTime.now(),
      );

      final game = await repository.createNewGame(
        gameType: larra,
        playerNames: ['Anna', 'Ben', 'Chris', 'David'],
      );

      expect(game.id, isNotEmpty);
      expect(game.gameTypeName, 'Larra Test');
      expect(game.hasThreshold, isTrue);
      expect(game.thresholdValue, 20);

      final players = await repository.getPlayersForGame(game.id);
      expect(players.length, 4);
      expect(players[0].name, 'Anna');
      expect(players[1].name, 'Ben');
      expect(players[2].name, 'Chris');
      expect(players[3].name, 'David');

      final rounds = await repository.getRoundsForGame(game.id);
      expect(rounds.length, 1);
      expect(rounds[0].roundNumber, 1);

      final scores = await repository.getScoresForGame(game.id);
      expect(scores.length, 4);
      expect(scores.every((s) => s.score == null), isTrue);
    });

    test('Renaming a player updates persistence', () async {
      final larra = GameType(
        id: 'larra_test',
        name: 'Larra Test',
        hasThreshold: true,
        thresholdValue: 20,
        createdAt: DateTime.now(),
      );

      final game = await repository.createNewGame(gameType: larra);
      final players = await repository.getPlayersForGame(game.id);

      await repository.updatePlayerName(players[0].id, 'Grandmaster Flash');

      final updatedPlayers = await repository.getPlayersForGame(game.id);
      expect(updatedPlayers[0].name, 'Grandmaster Flash');
    });

    test('Adding and deleting rounds maintains correct sequential order', () async {
      final larra = GameType(
        id: 'larra_test',
        name: 'Larra Test',
        hasThreshold: true,
        thresholdValue: 20,
        createdAt: DateTime.now(),
      );

      final game = await repository.createNewGame(gameType: larra);
      final r2 = await repository.addRound(game.id, 2);
      final r3 = await repository.addRound(game.id, 3);

      var rounds = await repository.getRoundsForGame(game.id);
      expect(rounds.length, 3);
      expect(rounds.map((r) => r.roundNumber).toList(), [1, 2, 3]);

      // Delete round 2 -> round 3 should renumber to 2
      await repository.deleteRound(r2.id);

      rounds = await repository.getRoundsForGame(game.id);
      expect(rounds.length, 2);
      expect(rounds[0].roundNumber, 1);
      expect(rounds[1].id, r3.id);
      expect(rounds[1].roundNumber, 2);
    });

    test('Setting scores persists and updates values', () async {
      final larra = GameType(
        id: 'larra_test',
        name: 'Larra Test',
        hasThreshold: true,
        thresholdValue: 20,
        createdAt: DateTime.now(),
      );

      final game = await repository.createNewGame(gameType: larra);
      final players = await repository.getPlayersForGame(game.id);
      final rounds = await repository.getRoundsForGame(game.id);

      await repository.setScore(
        roundId: rounds[0].id,
        gameId: game.id,
        playerId: players[0].id,
        score: 5,
      );

      var scores = await repository.getScoresForGame(game.id);
      final entry = scores.firstWhere((s) => s.playerId == players[0].id);
      expect(entry.score, 5);

      // Clear score (null)
      await repository.setScore(
        roundId: rounds[0].id,
        gameId: game.id,
        playerId: players[0].id,
        score: null,
      );

      scores = await repository.getScoresForGame(game.id);
      final cleared = scores.firstWhere((s) => s.playerId == players[0].id);
      expect(cleared.score, isNull);
    });

    test('Resetting game clears scores/rounds and resets to Round 1 while keeping player names', () async {
      final larra = GameType(
        id: 'larra_test',
        name: 'Larra Test',
        hasThreshold: true,
        thresholdValue: 20,
        createdAt: DateTime.now(),
      );

      final game = await repository.createNewGame(
        gameType: larra,
        playerNames: ['Custom 1', 'Custom 2', 'Custom 3', 'Custom 4'],
      );

      // Add round 2 and some scores
      final r2 = await repository.addRound(game.id, 2);
      final players = await repository.getPlayersForGame(game.id);
      await repository.setScore(
        roundId: r2.id,
        gameId: game.id,
        playerId: players[0].id,
        score: 15,
      );

      // Reset keeping names
      await repository.resetGame(game.id, keepPlayerNames: true);

      final resetRounds = await repository.getRoundsForGame(game.id);
      expect(resetRounds.length, 1);
      expect(resetRounds[0].roundNumber, 1);

      final resetScores = await repository.getScoresForGame(game.id);
      expect(resetScores.length, 4);
      expect(resetScores.every((s) => s.score == null), isTrue);

      final resetPlayers = await repository.getPlayersForGame(game.id);
      expect(resetPlayers[0].name, 'Custom 1');
    });

    test('Deleting game deletes historical record completely via cascade', () async {
      final larra = GameType(
        id: 'larra_test',
        name: 'Larra Test',
        hasThreshold: true,
        thresholdValue: 20,
        createdAt: DateTime.now(),
      );

      final game = await repository.createNewGame(gameType: larra);
      await repository.deleteGame(game.id);

      final queried = await repository.getGameById(game.id);
      expect(queried, isNull);

      final players = await repository.getPlayersForGame(game.id);
      expect(players, isEmpty);

      final rounds = await repository.getRoundsForGame(game.id);
      expect(rounds, isEmpty);

      final scores = await repository.getScoresForGame(game.id);
      expect(scores, isEmpty);
    });

    test('Deleting a custom game type preserves historical games (snapshot intact)', () async {
      final customType = GameType(
        id: 'custom_123',
        name: 'My Special Game',
        hasThreshold: true,
        thresholdValue: 100,
        isBuiltIn: false,
        createdAt: DateTime.now(),
      );

      await repository.saveGameType(customType);
      final game = await repository.createNewGame(gameType: customType);

      await repository.deleteGameType(customType.id);

      final loadedGame = await repository.getGameById(game.id);
      expect(loadedGame, isNotNull);
      expect(loadedGame!.gameTypeName, 'My Special Game');
      expect(loadedGame.hasThreshold, isTrue);
      expect(loadedGame.thresholdValue, 100);
      expect(loadedGame.gameTypeId, isNull); // ON DELETE SET NULL
    });
  });
}
