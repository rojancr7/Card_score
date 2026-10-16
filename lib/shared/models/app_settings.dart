import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Represents local application preferences
class AppSettings {
  final ThemeMode themeMode;
  final bool soundEnabled;
  final String defaultGameTypeId;
  final int maxScoreLimit;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.soundEnabled = true,
    this.defaultGameTypeId = AppConstants.larraId,
    this.maxScoreLimit = AppConstants.maxScore,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? soundEnabled,
    String? defaultGameTypeId,
    int? maxScoreLimit,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      defaultGameTypeId: defaultGameTypeId ?? this.defaultGameTypeId,
      maxScoreLimit: maxScoreLimit ?? this.maxScoreLimit,
    );
  }

  Map<String, String> toMap() {
    return {
      'theme_mode': themeMode.name,
      'sound_enabled': soundEnabled.toString(),
      'default_game_type_id': defaultGameTypeId,
      'max_score_limit': maxScoreLimit.toString(),
    };
  }

  factory AppSettings.fromMap(Map<String, String> map) {
    ThemeMode mode = ThemeMode.system;
    if (map['theme_mode'] == 'light') mode = ThemeMode.light;
    if (map['theme_mode'] == 'dark') mode = ThemeMode.dark;

    return AppSettings(
      themeMode: mode,
      soundEnabled: map['sound_enabled'] != 'false',
      defaultGameTypeId: map['default_game_type_id'] ?? AppConstants.larraId,
      maxScoreLimit: int.tryParse(map['max_score_limit'] ?? '') ?? AppConstants.maxScore,
    );
  }
}
