import 'package:audioplayers/audioplayers.dart';
import '../constants/app_constants.dart';

/// Abstract audio service interface allowing easy mocking and injection for tests
abstract class AudioService {
  Future<void> playGameOverAlert();
  bool get isSoundEnabled;
  set isSoundEnabled(bool value);
  void dispose();
}

/// Production implementation of [AudioService] using audioplayers and local assets
class AppAudioService implements AudioService {
  final AudioPlayer _player;
  bool _soundEnabled;
  DateTime? _lastPlayedTime;

  AppAudioService({
    AudioPlayer? player,
    bool soundEnabled = true,
  })  : _player = player ?? AudioPlayer(),
        _soundEnabled = soundEnabled;

  @override
  bool get isSoundEnabled => _soundEnabled;

  @override
  set isSoundEnabled(bool value) {
    _soundEnabled = value;
  }

  @override
  Future<void> playGameOverAlert() async {
    if (!_soundEnabled) return;

    // Debounce to prevent multiple triggers in short burst (e.g. multiple listeners)
    final now = DateTime.now();
    if (_lastPlayedTime != null &&
        now.difference(_lastPlayedTime!).inMilliseconds < 1500) {
      return;
    }
    _lastPlayedTime = now;

    try {
      await _player.stop();
      await _player.play(AssetSource(AppConstants.gameOverSoundAsset));
    } catch (_) {
      // Audio playback errors (e.g. headless CI or missing OS audio driver)
      // should never crash the scorekeeper.
    }
  }

  @override
  void dispose() {
    _player.dispose();
  }
}

/// Fake audio service for unit & widget tests without audio device requirements
class NoOpAudioService implements AudioService {
  @override
  bool isSoundEnabled;
  int playCount = 0;

  NoOpAudioService({this.isSoundEnabled = true});

  @override
  Future<void> playGameOverAlert() async {
    if (isSoundEnabled) {
      playCount++;
    }
  }

  @override
  void dispose() {}
}
