import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_settings.dart';
import '../../scoreboard/presentation/scoreboard_controller.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return const AppSettings();
  }

  Future<void> loadSettings() async {
    try {
      final repository = ref.read(gameRepositoryProvider);
      final audioService = ref.read(audioServiceProvider);

      final loaded = await repository.getSettings();
      audioService.isSoundEnabled = loaded.soundEnabled;
      state = loaded;
    } catch (_) {
      // Use current in-memory settings if load fails
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final updated = state.copyWith(themeMode: mode);
    state = updated;
    await ref.read(gameRepositoryProvider).saveSettings(updated);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    ref.read(audioServiceProvider).isSoundEnabled = enabled;
    final updated = state.copyWith(soundEnabled: enabled);
    state = updated;
    await ref.read(gameRepositoryProvider).saveSettings(updated);
  }

  Future<void> setDefaultGameType(String gameTypeId) async {
    final updated = state.copyWith(defaultGameTypeId: gameTypeId);
    state = updated;
    await ref.read(gameRepositoryProvider).saveSettings(updated);
  }
}
