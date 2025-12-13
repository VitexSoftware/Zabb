import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  static SoundService get instance => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<int, String> _severitySounds = {};
  String _defaultSoundFile = '';
  bool _notificationsEnabled = false;

  Future<void> initialize() async {
    await _loadSoundSettings();
  }

  Future<void> _loadSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
    _defaultSoundFile = prefs.getString('selected_sound_file') ?? '';

    _severitySounds.clear();
    for (int severity = 0; severity <= 5; severity++) {
      _severitySounds[severity] = prefs.getString('severity_sound_$severity') ?? '';
    }
  }

  Future<void> playSoundForSeverity(int severity) async {
    // Refresh settings in case they were changed in the UI
    await _loadSoundSettings();

    if (!_notificationsEnabled) {
      return;
    }

    final soundFile = _severitySounds[severity] ?? _defaultSoundFile;
    if (soundFile.isNotEmpty) {
      try {
        if (soundFile.startsWith('sounds/')) {
          await _audioPlayer.play(AssetSource(soundFile));
        } else {
          await _audioPlayer.play(DeviceFileSource(soundFile));
        }
      } catch (e) {
        print('Error playing notification sound: $e');
      }
    }
  }
}
