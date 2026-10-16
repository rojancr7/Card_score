/// Application-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Card Score';
  static const String appTagline = 'Digital Card Game Scorekeeper';

  // Score limits
  static const int minScore = -9999;
  static const int maxScore = 9999;

  // Defaults
  static const int defaultPlayerCount = 4;
  static const List<String> defaultPlayerNames = [
    'Player 1',
    'Player 2',
    'Player 3',
    'Player 4',
  ];

  // Built-in Game Type IDs and Names
  static const String larraId = 'builtin_larra';
  static const String callbreakId = 'builtin_callbreak';
  static const String marriageId = 'builtin_marriage';
  static const String customGameId = 'builtin_custom';

  static const String larraName = 'Larra';
  static const String callbreakName = 'Callbreak';
  static const String marriageName = 'Marriage';
  static const String customName = 'Other / Custom';

  // Initial threshold for Larra
  static const int larraDefaultThreshold = 20;

  // Assets
  static const String gameOverSoundAsset = 'audio/game_over.wav';
}
