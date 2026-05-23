import 'package:shared_preferences/shared_preferences.dart';

/// Persists user preferences for settings screen.
///
/// Keys:
///   - `ringtone_uri` — default ringtone URI for new alarms
///   - `ringtone_title` — display name of the default ringtone
class SettingsPreferencesService {
  SettingsPreferencesService._();

  static const _keyRingtoneUri = 'ringtone_uri';
  static const _keyRingtoneTitle = 'ringtone_title';

  static const defaultRingtoneUri = 'default';
  static const defaultRingtoneTitle = '默认';

  /// Load the saved default ringtone, or fall back to [defaultRingtoneUri].
  static Future<String> getRingtoneUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRingtoneUri) ?? defaultRingtoneUri;
  }

  /// Load the saved default ringtone title, or fall back to [defaultRingtoneTitle].
  static Future<String> getRingtoneTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRingtoneTitle) ?? defaultRingtoneTitle;
  }

  /// Save the default ringtone selection.
  static Future<void> setRingtone(String uri, String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRingtoneUri, uri);
    await prefs.setString(_keyRingtoneTitle, title);
  }
}
