import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _accentColorKey = 'accent_color';
  static const String _pngOptimizationEnabledKey = 'png_optimization_enabled';
  static const String _pngCompressionLevelKey = 'png_compression_level';

  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = Colors.blue;
  bool _pngOptimizationEnabled = false;
  int _pngCompressionLevel = 0; // 0-9 (0=no compression, 9=max compression)

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  bool get pngOptimizationEnabled => _pngOptimizationEnabled;
  int get pngCompressionLevel => _pngCompressionLevel;

  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme mode
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Load accent color
    final colorValue = prefs.getInt(_accentColorKey) ?? Colors.blue.value;
    _accentColor = Color(colorValue);

    // Load PNG optimization settings
    _pngOptimizationEnabled =
        prefs.getBool(_pngOptimizationEnabledKey) ?? false;
    _pngCompressionLevel = prefs.getInt(_pngCompressionLevelKey) ?? 0;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.value);
    notifyListeners();
  }

  Future<void> setPngOptimizationEnabled(bool enabled) async {
    _pngOptimizationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pngOptimizationEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setPngCompressionLevel(int level) async {
    // Ensure level is between 0 and 9
    _pngCompressionLevel = level.clamp(0, 9);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pngCompressionLevelKey, _pngCompressionLevel);
    notifyListeners();
  }

  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: Brightness.light,
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
