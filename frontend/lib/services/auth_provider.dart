import 'package:flutter/foundation.dart';
import '../models/user_entry.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _loading = true;

  AppUser? get user => _user;
  bool get isLogged => _user != null;
  bool get loading => _loading;

  Future<void> init() async {
    await ApiService.init();
    if (ApiService.isLoggedIn) {
      try {
        final r = await ApiService.getMe();
        _user = AppUser.fromJson(r);
        await ApiService.loadAndCacheRatingConfigs();
      } catch (_) {
        await ApiService.clearTokens();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final data = await ApiService.login(username, password);
    await ApiService.saveTokenPair(
      data['access_token'] as String,
      (data['refresh_token'] as String?) ?? '',
    );
    _user = AppUser.fromJson(data['user']);
    await ApiService.loadAndCacheRatingConfigs();
    notifyListeners();
  }

  Future<void> register(String username, String password, {String? displayName}) async {
    final data = await ApiService.register(username, password, displayName: displayName);
    await ApiService.saveTokenPair(
      data['access_token'] as String,
      (data['refresh_token'] as String?) ?? '',
    );
    _user = AppUser.fromJson(data['user']);
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    notifyListeners();
  }
}
