import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';

/// Database service managing SQLite schema, migrations, and transactions
class DatabaseService {
  static const String _dbName = 'card_score.db';
  static const int _dbVersion = 1;

  Database? _db;

  /// Optional injected database instance (useful for unit tests with in-memory DB)
  DatabaseService({Database? db}) : _db = db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  static void initializeFfiIfRequired() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _initDatabase() async {
    try {
      initializeFfiIfRequired();

      String dbPath;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final docDir = await getApplicationSupportDirectory();
        final dbDir = Directory(join(docDir.path, 'CardScore'));
        if (!dbDir.existsSync()) {
          dbDir.createSync(recursive: true);
        }
        dbPath = join(dbDir.path, _dbName);
      } else if (!kIsWeb) {
        final databasesPath = await getDatabasesPath();
        dbPath = join(databasesPath, _dbName);
      } else {
        dbPath = inMemoryDatabasePath;
      }

      return await openDatabase(
        dbPath,
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stack) {
      throw AppDatabaseException('Failed to initialize local database: $e', stack);
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Game Types table
    batch.execute('''
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

    // 2. Games table
    batch.execute('''
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

    // 3. Game Players table
    batch.execute('''
      CREATE TABLE game_players (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        name TEXT NOT NULL,
        player_order INTEGER NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
      )
    ''');

    // 4. Rounds table
    batch.execute('''
      CREATE TABLE rounds (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        round_number INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
      )
    ''');

    // 5. Score Entries table
    batch.execute('''
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

    // 6. Application Settings table (key-value store)
    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Pre-seed Built-in Game Types
    final now = DateTime.now().millisecondsSinceEpoch;

    // Larra (default 20 points threshold)
    batch.insert('game_types', {
      'id': AppConstants.larraId,
      'name': AppConstants.larraName,
      'has_threshold': 1,
      'threshold_value': AppConstants.larraDefaultThreshold,
      'is_active': 1,
      'is_built_in': 1,
      'created_at': now,
    });

    // Callbreak (no default threshold, user configurable)
    batch.insert('game_types', {
      'id': AppConstants.callbreakId,
      'name': AppConstants.callbreakName,
      'has_threshold': 0,
      'threshold_value': null,
      'is_active': 1,
      'is_built_in': 1,
      'created_at': now,
    });

    // Marriage (no default threshold, user configurable)
    batch.insert('game_types', {
      'id': AppConstants.marriageId,
      'name': AppConstants.marriageName,
      'has_threshold': 0,
      'threshold_value': null,
      'is_active': 1,
      'is_built_in': 1,
      'created_at': now,
    });

    // Other / Custom Game
    batch.insert('game_types', {
      'id': AppConstants.customGameId,
      'name': AppConstants.customName,
      'has_threshold': 0,
      'threshold_value': null,
      'is_active': 1,
      'is_built_in': 1,
      'created_at': now,
    });

    // Pre-seed Default Settings
    batch.insert('app_settings', {'key': 'theme_mode', 'value': 'system'});
    batch.insert('app_settings', {'key': 'sound_enabled', 'value': 'true'});
    batch.insert('app_settings', {'key': 'default_game_type_id', 'value': AppConstants.larraId});
    batch.insert('app_settings', {'key': 'max_score_limit', 'value': '${AppConstants.maxScore}'});

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration framework: sequential schema upgrades
    // For example:
    // if (oldVersion < 2) { ... }
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
