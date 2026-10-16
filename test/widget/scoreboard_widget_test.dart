import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:card_score/app.dart';
import 'package:card_score/core/audio/audio_service.dart';
import 'package:card_score/core/constants/app_constants.dart';
import 'package:card_score/core/database/database_service.dart';
import 'package:card_score/features/scoreboard/data/game_repository.dart';
import 'package:card_score/features/scoreboard/presentation/scoreboard_controller.dart';
import 'package:card_score/features/scoreboard/presentation/widgets/score_input_dialog.dart';
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

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbService = DatabaseService(db: db);
    await db.execute('PRAGMA foreign_keys = ON');

    // Create tables
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
    await repository.saveGameType(
      GameType(
        id: AppConstants.callbreakId,
        name: AppConstants.callbreakName,
        hasThreshold: false,
        isBuiltIn: true,
        createdAt: DateTime.now(),
      ),
    );

    audioService = NoOpAudioService();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        gameRepositoryProvider.overrideWithValue(repository),
        audioServiceProvider.overrideWithValue(audioService),
      ],
      child: const CardScoreApp(),
    );
  }

  Future<void> pumpAndLoad(WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(CardScoreApp)));
    await tester.runAsync(() async {
      await container.read(scoreboardControllerProvider.notifier).initialize();
    });
    await tester.pump();
  }

  Future<void> runAsyncStep(WidgetTester tester, [int millis = 300]) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration(milliseconds: millis));
    });
    await tester.pump();
  }

  testWidgets('Scoreboard loads initial game with Larra, 4 players, and sticky total row',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpAndLoad(tester);

    // Verify badges
    expect(find.text(AppConstants.larraName), findsOneWidget);
    expect(find.text('20 pts target'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Verify initial players
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Player 3'), findsOneWidget);
    expect(find.text('Player 4'), findsOneWidget);

    // Verify Round 1
    expect(find.text('R1'), findsOneWidget);

    // Verify empty cells show dash '—' (4 player cells)
    expect(find.text('—'), findsNWidgets(4));

    // Verify Total row exists
    expect(find.text('TOTAL'), findsOneWidget);

    // Verify Add Round button exists
    expect(find.text('Add Round'), findsOneWidget);
  });

  testWidgets('Tapping score cell opens ScoreInputDialog and saving updates score and total',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpAndLoad(tester);

    // Tap the first score cell '—'
    final firstScoreCell = find.text('—').first;
    await tester.tap(firstScoreCell);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.byType(ScoreInputDialog), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ScoreInputDialog), matching: find.text('Round 1')),
      findsOneWidget,
    );

    // Tap quick chip 5
    await tester.tap(find.widgetWithText(ActionChip, '5'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle(); // Dismisses dialog
    await runAsyncStep(tester);

    // Score cell should now display 5
    expect(find.text('5'), findsNWidgets(2)); // Once in the cell, once in the TOTAL row!
  });

  testWidgets('Adding rounds appends R2 and updates round counter', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpAndLoad(tester);

    expect(find.text('Round 1'), findsOneWidget);

    // Tap + Add Round
    await tester.tap(find.text('Add Round'));
    await runAsyncStep(tester);

    expect(find.text('R2'), findsOneWidget);
    expect(find.text('Round 2'), findsOneWidget);
  });

  testWidgets('Reaching 20 points in Larra shows Game Over dialog and plays alert sound',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpAndLoad(tester);

    // Tap first score cell
    await tester.tap(find.text('—').first);
    await tester.pumpAndSettle();

    // Enter 20 in the score dialog
    final inputField = find.byType(TextField);
    await tester.enterText(inputField, '20');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle(); // Dismiss dialog
    await runAsyncStep(tester, 300);

    // Game Over dialog should be displayed
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('Player 1 Wins!'), findsOneWidget);
    expect(find.text('Reached the 20-point target in Larra'), findsOneWidget);

    // Audio sound alert should have been called
    expect(audioService.playCount, 1);
  });

  testWidgets('Can navigate across all 4 tabs via bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpAndLoad(tester);

    // Verify on Scoreboard
    expect(find.text('Larra'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(CardScoreApp)));

    // Tap Game Types tab
    await tester.tap(find.text('Game Types'));
    await tester.pump();
    await tester.runAsync(() async {
      await container.read(gameTypesControllerProvider.notifier).loadGameTypes();
    });
    await tester.pump();
    expect(find.text('Add Game Type'), findsOneWidget);
    expect(find.text('Callbreak'), findsOneWidget);

    // Tap History tab
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.runAsync(() async {
      await container.read(historyControllerProvider.notifier).loadHistory();
    });
    await tester.pump();
    expect(find.text('Game History'), findsOneWidget);

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await runAsyncStep(tester);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Game Over Sound Alert'), findsOneWidget);
  });
}
