import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<bool> {
  static const _key = 'theme_dark';

  @override
  bool build() {
    // Read persisted value synchronously via SharedPreferences (already initialized)
    _load();
    return true; // default dark until persistence loads
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_key) ?? true;
    state = saved;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// `true` = dark mode, `false` = light mode
final themeRvProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);
