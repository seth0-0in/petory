import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kDefaultSeedColor = Color(0xFFFF8FA3);
const String _kSeedPrefsKey = 'theme_seed_color';
const String _kThemeModePrefsKey = 'theme_mode';

final ValueNotifier<Color> themeSeedNotifier = ValueNotifier<Color>(
  kDefaultSeedColor,
);

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

class ThemePreset {
  final String name;
  final Color color;
  const ThemePreset(this.name, this.color);
}

const List<ThemePreset> kThemePresets = [
  ThemePreset('코랄핑크', Color(0xFFFF8FA3)),
  ThemePreset('하늘', Color(0xFF6FB7E8)),
  ThemePreset('민트', Color(0xFF4FC3A1)),
  ThemePreset('라벤더', Color(0xFFB39DDB)),
  ThemePreset('살구', Color(0xFFFFB37A)),
  ThemePreset('라임', Color(0xFFAEDB6E)),
];

Future<void> loadSavedSeedColor() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getInt(_kSeedPrefsKey);
  if (stored != null) {
    themeSeedNotifier.value = Color(stored);
  }
}

Future<void> setSeedColor(Color color) async {
  themeSeedNotifier.value = color;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kSeedPrefsKey, color.toARGB32());
}

Future<void> loadSavedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_kThemeModePrefsKey);
  themeModeNotifier.value = _decodeThemeMode(stored);
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kThemeModePrefsKey, _encodeThemeMode(mode));
}

String _encodeThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

ThemeMode _decodeThemeMode(String? raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
