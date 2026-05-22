import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_entry.dart';
import '../services/api_service.dart';
import '../theme/rpg_theme.dart';

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

class AuthState {
  final AppUser? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isLogged => user != null;

  AuthState copyWith({AppUser? user, bool? loading, String? error, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    await ApiService.init();
    if (!ApiService.isLoggedIn) return const AuthState(loading: false);
    try {
      final data = await ApiService.getMe();
      await ApiService.loadAndCacheRatingConfigs();
      return AuthState(user: AppUser.fromJson(data), loading: false);
    } catch (_) {
      await ApiService.clearTokens();
      return const AuthState(loading: false);
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ApiService.login(username, password);
      await ApiService.saveTokenPair(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      await ApiService.loadAndCacheRatingConfigs();
      final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      return AsyncData(AuthState(user: user, loading: false));
    });
  }

  Future<void> register(String username, String password, {String? displayName}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ApiService.register(username, password, displayName: displayName);
      await ApiService.saveTokenPair(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      await ApiService.loadAndCacheRatingConfigs();
      final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      return AsyncData(AuthState(user: user, loading: false));
    });
  }

  Future<void> logout() async {
    await ApiService.logout();
    state = const AsyncData(AuthState(loading: false));
  }

  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final data = await ApiService.getMe();
      state = AsyncData(current.copyWith(user: AppUser.fromJson(data)));
    } catch (_) {}
  }
}

final authRvProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
