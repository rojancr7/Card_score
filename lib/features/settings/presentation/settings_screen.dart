import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../games/presentation/game_types_controller.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final gameTypesState = ref.watch(gameTypesControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // THEME SECTION
          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  subtitle: const Text('Match device theme settings'),
                  value: ThemeMode.system,
                  groupValue: settings.themeMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(settingsControllerProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
                Divider(height: 1, color: theme.dividerColor),
                RadioListTile<ThemeMode>(
                  title: const Text('Light Theme'),
                  value: ThemeMode.light,
                  groupValue: settings.themeMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(settingsControllerProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
                Divider(height: 1, color: theme.dividerColor),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark Theme'),
                  value: ThemeMode.dark,
                  groupValue: settings.themeMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(settingsControllerProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // AUDIO SECTION
          Text(
            'Audio & Notifications',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: SwitchListTile.adaptive(
              title: const Text('Game Over Sound Alert'),
              subtitle: const Text('Play chime sound when a player reaches the winning threshold'),
              value: settings.soundEnabled,
              onChanged: (enabled) {
                ref.read(settingsControllerProvider.notifier).setSoundEnabled(enabled);
              },
            ),
          ),
          const SizedBox(height: 24),

          // DEFAULT GAME TYPE SECTION
          Text(
            'Game Preferences',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.star_outline),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default Game Type',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          'Selected when opening a new match',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: gameTypesState.gameTypes.any((t) => t.id == settings.defaultGameTypeId)
                        ? settings.defaultGameTypeId
                        : (gameTypesState.gameTypes.isNotEmpty
                            ? gameTypesState.gameTypes.first.id
                            : null),
                    items: gameTypesState.gameTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type.id,
                        child: Text(type.name),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setDefaultGameType(newId);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ABOUT APP
          Text(
            'About',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.style, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Text(
                        'Card Score',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
  'Version 1.0.0+1\n'
  '100% Offline Card Game Scorekeeper\n'
  'Supports Larra, Callbreak, Marriage, and Custom Games\n\n'
  'Made by RB Company\n'
  'Special thanks to Rojan Bhattarai',
  style: TextStyle(
    fontSize: 13,
    height: 1.5,
    color: Colors.purple,
  ),
)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
