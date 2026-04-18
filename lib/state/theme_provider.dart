import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Default to dark mode

  bool get isDarkMode => _isDarkMode;

  ThemeProvider(SharedPreferences prefs) {
    _init(prefs);
  }

  void _init(SharedPreferences prefs) {
    // If 'theme_is_dark' key doesn't exist, we default to true.
    _isDarkMode = prefs.getBool('theme_is_dark') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark', value);
  }
}
