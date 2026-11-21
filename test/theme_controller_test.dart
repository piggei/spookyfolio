import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:spookyfolio/app_theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('defaults to system and persists user selections', () async {
    final controller = AppThemeController();
    await controller.load();
    expect(controller.mode, ThemeMode.system);
    await controller.setMode(ThemeMode.light);
    final another = AppThemeController();
    await another.load();
    expect(another.mode, ThemeMode.light);
    await another.setMode(ThemeMode.dark);
    final third = AppThemeController();
    await third.load();
    expect(third.mode, ThemeMode.dark);
    await third.setMode(ThemeMode.system);
    final fourth = AppThemeController();
    await fourth.load();
    expect(fourth.mode, ThemeMode.system);
  });

  test('invalid stored value falls back to system', () async {
    final storage = SharedPreferencesAsync();
    await storage.setString(AppThemeController.preferenceKey, 'unknown');
    final controller = AppThemeController();
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });
}
