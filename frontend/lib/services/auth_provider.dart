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
      } catch (_) {
        await ApiService.clearToken();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final data = await ApiService.login(username, password);
    await ApiService.saveToken(data['access_token']);
    _user = AppUser.fromJson(data['user']);
    notifyListeners();
  }

  Future<void> register(String username, String password, {String? displayName}) async {
    final data = await ApiService.register(username, password, displayName: displayName);
    await ApiService.saveToken(data['access_token']);
    _user = AppUser.fromJson(data['user']);
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }
}
