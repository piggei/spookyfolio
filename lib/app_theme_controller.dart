import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI preference only: never store session credentials here.
class AppThemeController extends ChangeNotifier {
  AppThemeController({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const preferenceKey = 'spookyfolio.themeMode';
  final SharedPreferencesAsync _preferences;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  static ThemeMode fromValue(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String toValue(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  Future<void> load() async {
    try {
      final stored = await _preferences.getString(preferenceKey);
      _mode = fromValue(stored);
      notifyListeners();
    } catch (_) {
      // Missing/unavailable preferences do not prevent the app from starting.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    final previous = _mode;
    _mode = mode;
    notifyListeners();
    try {
      await _preferences.setString(preferenceKey, toValue(mode));
    } catch (_) {
      _mode = previous;
      notifyListeners();
      rethrow;
    }
  }
}
