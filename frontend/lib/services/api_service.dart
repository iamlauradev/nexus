import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/user_entry.dart';
import '../theme/rpg_theme.dart';

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8500',
  );

  static String? _token;
  static String? _refreshToken;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> saveTokenPair(String accessToken, String refreshToken) async {
    _token = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<void> clearTokens() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  static Future<void> logout() async {
    try {
      if (_token != null && _refreshToken != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: _headers,
          body: jsonEncode({'refresh_token': _refreshToken}),
        );
      }
    } catch (_) {}
    await clearTokens();
  }

  static bool get isLoggedIn => _token != null;
  static String? get token => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final data = jsonDecode(utf8.decode(r.bodyBytes));
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null) {
          await saveTokenPair(newAccess, newRefresh ?? _refreshToken!);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response r,
      {Future<http.Response> Function()? retry}) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    if (r.statusCode == 401 && _refreshToken != null && retry != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final r2 = await retry();
        if (r2.statusCode >= 200 && r2.statusCode < 300) {
          return jsonDecode(utf8.decode(r2.bodyBytes));
        }
        await clearTokens();
        throw ApiException('Sesión expirada', 401);
      } else {
        await clearTokens();
        throw ApiException('Sesión expirada', 401);
      }
    }
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    throw ApiException(body['detail'] ?? 'Error del servidor', r.statusCode);
  }

  static Future<List<dynamic>> _handleListResponse(http.Response r,
      {Future<http.Response> Function()? retry}) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    if (r.statusCode == 401 && _refreshToken != null && retry != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final r2 = await retry();
        if (r2.statusCode >= 200 && r2.statusCode < 300) {
          return jsonDecode(utf8.decode(r2.bodyBytes));
        }
        await clearTokens();
        throw ApiException('Sesión expirada', 401);
      } else {
        await clearTokens();
        throw ApiException('Sesión expirada', 401);
      }
    }
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    throw ApiException(body['detail'] ?? 'Error del servidor', r.statusCode);
  }

  // Auth
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _handleResponse(r);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse('$_baseUrl/auth/me');
    final r = await http.get(uri, headers: _headers);
    return _handleResponse(r, retry: () => http.get(uri, headers: _headers));
  }

  static Future<Map<String, dynamic>> register(String username, String password, {String? displayName}) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password, 'display_name': displayName}),
    );
    return _handleResponse(r);
  }

  static Future<Map<String, dynamic>> updateProfile({String? displayName, String? avatarUrl}) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    final uri = Uri.parse('$_baseUrl/auth/profile');
    final r = await http.put(uri, headers: _headers, body: jsonEncode(body));
    return _handleResponse(r, retry: () => http.put(uri, headers: _headers, body: jsonEncode(body)));
  }

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final uri = Uri.parse('$_baseUrl/auth/change-password');
    final body = jsonEncode({'current_password': currentPassword, 'new_password': newPassword});
    final r = await http.post(uri, headers: _headers, body: body);
    await _handleResponse(r, retry: () => http.post(uri, headers: _headers, body: body));
  }

  // Rating configs
  static Future<List<RatingConfig>> getRatingConfigs() async {
    final uri = Uri.parse('$_baseUrl/rating-configs/');
    final r = await http.get(uri, headers: _headers);
    final list = await _handleListResponse(r, retry: () => http.get(uri, headers: _headers));
    return list.map((j) => RatingConfig.fromJson(j)).toList();
  }

  static Future<RatingConfig> createRatingConfig(Map<String, dynamic> data) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/rating-configs/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return RatingConfig.fromJson(await _handleResponse(r));
  }

  static Future<RatingConfig> updateRatingConfig(int id, Map<String, dynamic> data) async {
    final r = await http.put(
      Uri.parse('$_baseUrl/rating-configs/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return RatingConfig.fromJson(await _handleResponse(r));
  }

  static Future<void> deleteRatingConfig(int id) async {
    final uri = Uri.parse('$_baseUrl/rating-configs/$id');
    final r = await http.delete(uri, headers: _headers);
    await _handleResponse(r, retry: () => http.delete(uri, headers: _headers));
  }

  /// Carga configs y actualiza el caché de la app
  static Future<void> loadAndCacheRatingConfigs() async {
    try {
      final configs = await getRatingConfigs();
      RatingConfigCache.update(configs.map((c) => {
        'key': c.key,
        'label': c.label,
        'color': c.color,
        'sort_order': c.sortOrder,
      }).toList());
    } catch (_) {}
  }

  // Media search
  static Future<List<SearchResult>> searchMetadata(String query, String type) async {
    final uri = Uri.parse('$_baseUrl/media/search?q=${Uri.encodeComponent(query)}&type=$type');
    final r = await http.get(uri, headers: _headers);
    final list = await _handleListResponse(r, retry: () => http.get(uri, headers: _headers));
    return list.map((j) => SearchResult.fromJson(j)).toList();
  }

  static Future<MediaItem> createMedia(Map<String, dynamic> data) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/media/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return MediaItem.fromJson(await _handleResponse(r));
  }

  static Future<List<MediaItem>> searchLocalMedia(String q, {String? type}) async {
    var url = '$_baseUrl/media/?q=${Uri.encodeComponent(q)}';
    if (type != null) url += '&type=$type';
    final uri = Uri.parse(url);
    final r = await http.get(uri, headers: _headers);
    final list = await _handleListResponse(r, retry: () => http.get(uri, headers: _headers));
    return list.map((j) => MediaItem.fromJson(j)).toList();
  }

  // Entries
  static Future<List<UserEntry>> getEntries({
    String? status,
    String? mediaType,
    String? rating,
    String? q,
    int limit = 100,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (status != null) 'status': status,
      if (mediaType != null) 'media_type': mediaType,
      if (rating != null) 'rating': rating,
      if (q != null) 'q': q,
    };
    final uri = Uri.parse('$_baseUrl/entries/').replace(queryParameters: params);
    final r = await http.get(uri, headers: _headers);
    final list = await _handleListResponse(r, retry: () => http.get(uri, headers: _headers));
    return list.map((j) => UserEntry.fromJson(j)).toList();
  }

  static Future<UserEntry> createEntry(Map<String, dynamic> data) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/entries/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return UserEntry.fromJson(await _handleResponse(r));
  }

  static Future<UserEntry> updateEntry(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/entries/$id');
    final body = jsonEncode(data);
    final r = await http.put(uri, headers: _headers, body: body);
    return UserEntry.fromJson(await _handleResponse(r,
        retry: () => http.put(uri, headers: _headers, body: body)));
  }

  static Future<void> deleteEntry(int id) async {
    final uri = Uri.parse('$_baseUrl/entries/$id');
    final r = await http.delete(uri, headers: _headers);
    await _handleResponse(r, retry: () => http.delete(uri, headers: _headers));
  }

  static Future<List<String>> getPlatforms() async {
    final uri = Uri.parse('$_baseUrl/entries/platforms');
    final r = await http.get(uri, headers: _headers);
    final list = await _handleListResponse(r, retry: () => http.get(uri, headers: _headers));
    return list.map((e) => e.toString()).toList();
  }

  static Future<Map<String, dynamic>> getStats({int? year}) async {
    final params = year != null ? {'year': year.toString()} : null;
    final uri = Uri.parse('$_baseUrl/entries/stats').replace(queryParameters: params);
    final r = await http.get(uri, headers: _headers);
    return _handleResponse(r, retry: () => http.get(uri, headers: _headers));
  }

  static Future<UserEntry> getRandomPick({String? mediaType, String? genre}) async {
    final params = <String, String>{
      if (mediaType != null) 'media_type': mediaType,
      if (genre != null) 'genre': genre,
    };
    final uri = Uri.parse('$_baseUrl/entries/random-pick').replace(queryParameters: params.isEmpty ? null : params);
    final r = await http.get(uri, headers: _headers);
    return UserEntry.fromJson(await _handleResponse(r, retry: () => http.get(uri, headers: _headers)));
  }

  static Future<Map<String, dynamic>> exportData() async {
    final uri = Uri.parse('$_baseUrl/entries/export');
    final r = await http.get(uri, headers: _headers);
    return _handleResponse(r, retry: () => http.get(uri, headers: _headers));
  }

  static Future<Map<String, dynamic>> importData(String format, String content) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/import'),
      headers: _headers,
      body: jsonEncode({'format': format, 'content': content}),
    );
    return _handleResponse(r);
  }

  static Future<MediaItem> updateCover(int mediaId, String coverUrl) async {
    final r = await http.patch(
      Uri.parse('$_baseUrl/media/$mediaId/cover'),
      headers: _headers,
      body: jsonEncode({'cover_url': coverUrl}),
    );
    return MediaItem.fromJson(await _handleResponse(r));
  }

  static Future<MediaItem> updateEmissionStatus(int mediaId, String? emissionStatus) async {
    final r = await http.patch(
      Uri.parse('$_baseUrl/media/$mediaId/emission-status'),
      headers: _headers,
      body: jsonEncode({'emission_status': emissionStatus ?? ''}),
    );
    return MediaItem.fromJson(await _handleResponse(r));
  }

  static Future<List<dynamic>> getEntryHistory(int entryId) async {
    final uri = Uri.parse('$_baseUrl/entries/$entryId/history');
    final r = await http.get(uri, headers: _headers);
    return _handleListResponse(r, retry: () => http.get(uri, headers: _headers));
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
