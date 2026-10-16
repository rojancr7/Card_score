import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/game.dart';
import '../../../shared/models/game_player.dart';
import '../../../shared/models/game_type.dart';
import '../../../shared/models/round.dart';
import '../../../shared/models/score_entry.dart';

abstract class GameRepository {
  Future<List<GameType>> getAllGameTypes();
  Future<GameType?> getGameType(String id);
  Future<void> saveGameType(GameType type);
  Future<void> deleteGameType(String id);

  Future<Game?> getActiveGame();
  Future<Game?> getGameById(String gameId);
  Future<List<Game>> getHistoricalGames({String? searchQuery, String? gameTypeId, GameStatus? statusFilter});
  Future<List<GamePlayer>> getPlayersForGame(String gameId);
  Future<List<Round>> getRoundsForGame(String gameId);
  Future<List<ScoreEntry>> getScoresForGame(String gameId);

  Future<Game> createNewGame({
    required GameType gameType,
    List<String>? playerNames,
  });

  Future<void> updatePlayerName(String playerId, String newName);
  Future<Round> addRound(String gameId, int roundNumber);
  Future<void> deleteRound(String roundId);
  Future<void> setScore({
    required String roundId,
    required String gameId,
    required String playerId,
    required int? score,
  });

  Future<void> updateGameStatus(String gameId, GameStatus status, List<String> winningPlayerIds);
  Future<void> resetGame(String gameId, {required bool keepPlayerNames});
  Future<void> deleteGame(String gameId);

  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}

class SqliteGameRepository implements GameRepository {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  SqliteGameRepository(this._dbService);

  @override
  Future<List<GameType>> getAllGameTypes() async {
    final db = await _dbService.database;
    final results = await db.query(
      'game_types',
      orderBy: 'is_built_in DESC, created_at ASC',
    );
    return results.map((map) => GameType.fromMap(map)).toList();
  }

  @override
  Future<GameType?> getGameType(String id) async {
    final db = await _dbService.database;
    final results = await db.query(
      'game_types',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return GameType.fromMap(results.first);
  }

  @override
  Future<void> saveGameType(GameType type) async {
    final db = await _dbService.database;
    await db.insert(
      'game_types',
      type.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteGameType(String id) async {
    final db = await _dbService.database;
    // Built-in game types should not be deleted
    final existing = await getGameType(id);
    if (existing != null && existing.isBuiltIn) {
      throw const ValidationException('Built-in game types cannot be deleted.');
    }
    // Delete game type. Due to foreign key ON DELETE SET NULL, historical games are preserved.
    await db.delete(
      'game_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Game?> getActiveGame() async {
    final db = await _dbService.database;
    final results = await db.query(
      'games',
      where: 'status = ?',
      whereArgs: [GameStatus.active.name],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Game.fromMap(results.first);
  }

  @override
  Future<Game?> getGameById(String gameId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'games',
      where: 'id = ?',
      whereArgs: [gameId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Game.fromMap(results.first);
  }

  @override
  Future<List<Game>> getHistoricalGames({
    String? searchQuery,
    String? gameTypeId,
    GameStatus? statusFilter,
  }) async {
    final db = await _dbService.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (gameTypeId != null && gameTypeId.isNotEmpty) {
      whereClauses.add('game_type_id = ?');
      whereArgs.add(gameTypeId);
    }

    if (statusFilter != null) {
      whereClauses.add('status = ?');
      whereArgs.add(statusFilter.name);
    }

    String? where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'games',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC',
    );

    var games = results.map((map) => Game.fromMap(map)).toList();

    // If searching by player name, filter by checking associated players
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final queryLower = searchQuery.trim().toLowerCase();
      final filteredGames = <Game>[];
      for (final game in games) {
        final players = await getPlayersForGame(game.id);
        final matches = players.any((p) => p.name.toLowerCase().contains(queryLower));
        if (matches) {
          filteredGames.add(game);
        }
      }
      return filteredGames;
    }

    return games;
  }

  @override
  Future<List<GamePlayer>> getPlayersForGame(String gameId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'game_players',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'player_order ASC',
    );
    return results.map((map) => GamePlayer.fromMap(map)).toList();
  }

  @override
  Future<List<Round>> getRoundsForGame(String gameId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'rounds',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'round_number ASC',
    );
    return results.map((map) => Round.fromMap(map)).toList();
  }

  @override
  Future<List<ScoreEntry>> getScoresForGame(String gameId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'score_entries',
      where: 'game_id = ?',
      whereArgs: [gameId],
    );
    return results.map((map) => ScoreEntry.fromMap(map)).toList();
  }

  @override
  Future<Game> createNewGame({
    required GameType gameType,
    List<String>? playerNames,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();
    final gameId = _uuid.v4();

    final names = (playerNames != null && playerNames.length == 4)
        ? playerNames
        : AppConstants.defaultPlayerNames;

    final game = Game(
      id: gameId,
      gameTypeId: gameType.id,
      gameTypeName: gameType.name,
      hasThreshold: gameType.hasThreshold,
      thresholdValue: gameType.thresholdValue,
      status: GameStatus.active,
      winningPlayerIds: const [],
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // 1. Insert Game
      await txn.insert('games', game.toMap());

      // 2. Insert 4 Players with stable IDs
      final playerIds = <String>[];
      for (int i = 0; i < 4; i++) {
        final pId = _uuid.v4();
        playerIds.add(pId);
        final player = GamePlayer(
          id: pId,
          gameId: gameId,
          name: names[i].trim().isEmpty ? 'Player ${i + 1}' : names[i].trim(),
          playerOrder: i,
        );
        await txn.insert('game_players', player.toMap());
      }

      // 3. Insert Round 1
      final round1Id = _uuid.v4();
      final round1 = Round(
        id: round1Id,
        gameId: gameId,
        roundNumber: 1,
        createdAt: now,
      );
      await txn.insert('rounds', round1.toMap());

      // 4. Insert 4 empty score entries for Round 1
      for (final pId in playerIds) {
        final sId = _uuid.v4();
        final score = ScoreEntry(
          id: sId,
          roundId: round1Id,
          gameId: gameId,
          playerId: pId,
          score: null, // explicitly unrecorded
        );
        await txn.insert('score_entries', score.toMap());
      }
    });

    return game;
  }

  @override
  Future<void> updatePlayerName(String playerId, String newName) async {
    final db = await _dbService.database;
    await db.update(
      'game_players',
      {'name': newName.trim()},
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }

  @override
  Future<Round> addRound(String gameId, int roundNumber) async {
    final db = await _dbService.database;
    final now = DateTime.now();
    final roundId = _uuid.v4();

    final round = Round(
      id: roundId,
      gameId: gameId,
      roundNumber: roundNumber,
      createdAt: now,
    );

    await db.transaction((txn) async {
      // Insert round
      await txn.insert('rounds', round.toMap());

      // Query game players
      final playerMaps = await txn.query(
        'game_players',
        where: 'game_id = ?',
        whereArgs: [gameId],
      );

      // Create empty score entries for each player
      for (final pMap in playerMaps) {
        final pId = pMap['id'] as String;
        final score = ScoreEntry(
          id: _uuid.v4(),
          roundId: roundId,
          gameId: gameId,
          playerId: pId,
          score: null,
        );
        await txn.insert('score_entries', score.toMap());
      }

      // Update game's updatedAt
      await txn.update(
        'games',
        {'updated_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [gameId],
      );
    });

    return round;
  }

  @override
  Future<void> deleteRound(String roundId) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      final roundQuery = await txn.query(
        'rounds',
        where: 'id = ?',
        whereArgs: [roundId],
        limit: 1,
      );
      if (roundQuery.isEmpty) return;
      final gameId = roundQuery.first['game_id'] as String;

      // Delete round (foreign key cascade deletes score entries)
      await txn.delete(
        'rounds',
        where: 'id = ?',
        whereArgs: [roundId],
      );

      // Renumber remaining rounds sequentially
      final remainingRounds = await txn.query(
        'rounds',
        where: 'game_id = ?',
        whereArgs: [gameId],
        orderBy: 'round_number ASC, created_at ASC',
      );

      for (int i = 0; i < remainingRounds.length; i++) {
        final rId = remainingRounds[i]['id'] as String;
        await txn.update(
          'rounds',
          {'round_number': i + 1},
          where: 'id = ?',
          whereArgs: [rId],
        );
      }

      await txn.update(
        'games',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [gameId],
      );
    });
  }

  @override
  Future<void> setScore({
    required String roundId,
    required String gameId,
    required String playerId,
    required int? score,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // Find existing entry
      final existing = await txn.query(
        'score_entries',
        where: 'round_id = ? AND player_id = ?',
        whereArgs: [roundId, playerId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await txn.update(
          'score_entries',
          {'score': score},
          where: 'round_id = ? AND player_id = ?',
          whereArgs: [roundId, playerId],
        );
      } else {
        final entry = ScoreEntry(
          id: _uuid.v4(),
          roundId: roundId,
          gameId: gameId,
          playerId: playerId,
          score: score,
        );
        await txn.insert('score_entries', entry.toMap());
      }

      // Update game updated_at
      await txn.update(
        'games',
        {'updated_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [gameId],
      );
    });
  }

  @override
  Future<void> updateGameStatus(
    String gameId,
    GameStatus status,
    List<String> winningPlayerIds,
  ) async {
    final db = await _dbService.database;
    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'status': status.name,
      'winning_player_ids': Game(
        id: '',
        gameTypeName: '',
        hasThreshold: false,
        winningPlayerIds: winningPlayerIds,
        createdAt: now,
        updatedAt: now,
      ).toMap()['winning_player_ids'],
      'updated_at': now.millisecondsSinceEpoch,
    };

    if (status == GameStatus.finished) {
      updateData['finished_at'] = now.millisecondsSinceEpoch;
    } else {
      updateData['finished_at'] = null;
    }

    await db.update(
      'games',
      updateData,
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  @override
  Future<void> resetGame(String gameId, {required bool keepPlayerNames}) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // 1. Delete all rounds (cascades to scores)
      await txn.delete(
        'rounds',
        where: 'game_id = ?',
        whereArgs: [gameId],
      );

      // 2. Handle player names
      final players = await txn.query(
        'game_players',
        where: 'game_id = ?',
        whereArgs: [gameId],
        orderBy: 'player_order ASC',
      );

      final playerIds = <String>[];
      for (int i = 0; i < players.length; i++) {
        final pId = players[i]['id'] as String;
        playerIds.add(pId);
        if (!keepPlayerNames) {
          await txn.update(
            'game_players',
            {'name': 'Player ${i + 1}'},
            where: 'id = ?',
            whereArgs: [pId],
          );
        }
      }

      // 3. Reset game status & timestamps
      await txn.update(
        'games',
        {
          'status': GameStatus.active.name,
          'winning_player_ids': '[]',
          'updated_at': now.millisecondsSinceEpoch,
          'finished_at': null,
        },
        where: 'id = ?',
        whereArgs: [gameId],
      );

      // 4. Create fresh Round 1
      final round1Id = _uuid.v4();
      final round1 = Round(
        id: round1Id,
        gameId: gameId,
        roundNumber: 1,
        createdAt: now,
      );
      await txn.insert('rounds', round1.toMap());

      // 5. Create empty scores for Round 1
      for (final pId in playerIds) {
        final score = ScoreEntry(
          id: _uuid.v4(),
          roundId: round1Id,
          gameId: gameId,
          playerId: pId,
          score: null,
        );
        await txn.insert('score_entries', score.toMap());
      }
    });
  }

  @override
  Future<void> deleteGame(String gameId) async {
    final db = await _dbService.database;
    // Foreign keys with CASCADE will delete players, rounds, and scores
    await db.delete(
      'games',
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  @override
  Future<AppSettings> getSettings() async {
    final db = await _dbService.database;
    final results = await db.query('app_settings');
    final Map<String, String> map = {
      for (final row in results) row['key'] as String: row['value'] as String,
    };
    return AppSettings.fromMap(map);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final db = await _dbService.database;
    final batch = db.batch();
    for (final entry in settings.toMap().entries) {
      batch.insert(
        'app_settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
