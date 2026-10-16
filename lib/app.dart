import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/games/presentation/game_types_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/scoreboard/presentation/scoreboard_screen.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'shared/widgets/responsive_scaffold.dart';

class CardScoreApp extends ConsumerStatefulWidget {
  const CardScoreApp({super.key});

  @override
  ConsumerState<CardScoreApp> createState() => _CardScoreAppState();
}

class _CardScoreAppState extends ConsumerState<CardScoreApp> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'Card Score',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: ResponsiveScaffold(
        currentIndex: _navIndex,
        onNavigationIndexChanged: (index) {
          setState(() => _navIndex = index);
        },
        children: [
          ScoreboardScreen(
            onOpenHistory: () {
              setState(() => _navIndex = 2);
            },
          ),
          const GameTypesScreen(),
          HistoryScreen(
            onOpenScoreboard: () {
              setState(() => _navIndex = 0);
            },
          ),
          const SettingsScreen(),
        ],
      ),
    );
  }
}
