import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<HopeSettingsController> loadedSettings() async {
    final settings = HopeSettingsController();
    await settings.load();
    return settings;
  }

  test('starts in ThemeMode.dark, matching the dark-first HOPE default', () async {
    final settings = await loadedSettings();
    final theme = ThemeController(settings);

    expect(theme.mode, ThemeMode.dark);
    expect(theme.isDark, isTrue);
  });

  test('picks up a persisted theme preference on construction', () async {
    SharedPreferences.setMockInitialValues({'theme': 'dark'});
    final settings = HopeSettingsController();
    await settings.load();

    final theme = ThemeController(settings);

    expect(theme.mode, ThemeMode.dark);
    expect(theme.isDark, isTrue);
  });

  test(
    'setMode updates the mode and writes it back through settings',
    () async {
      final settings = await loadedSettings();
      final theme = ThemeController(settings);

      await theme.setMode(ThemeMode.light);

      expect(theme.mode, ThemeMode.light);
      expect(settings.theme, 'light');
    },
  );

  test(
    'setMode with the current mode is a no-op (no redundant persistence)',
    () async {
      final settings = await loadedSettings();
      final theme = ThemeController(settings);
      var notifications = 0;
      theme.addListener(() => notifications++);

      await theme.setMode(ThemeMode.dark);

      expect(notifications, 0);
    },
  );

  test(
    'toggle flips between dark and light, treating dark as the default',
    () async {
      final settings = await loadedSettings();
      final theme = ThemeController(settings);
      expect(theme.mode, ThemeMode.dark);

      await theme.toggle();
      expect(theme.mode, ThemeMode.light);

      await theme.toggle();
      expect(theme.mode, ThemeMode.dark);
    },
  );

  test(
      'changing the theme via settings directly is reflected on the '
      'controller through its listener', () async {
    final settings = await loadedSettings();
    final theme = ThemeController(settings);

    await settings.setTheme('light');

    expect(theme.mode, ThemeMode.light);
  });

  test('dispose stops listening to settings without throwing', () async {
    final settings = await loadedSettings();
    final theme = ThemeController(settings);
    theme.dispose();

    // Should not throw or resurrect the disposed controller's listeners.
    await settings.setTheme('light');
  });
}