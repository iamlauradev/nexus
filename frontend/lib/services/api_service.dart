import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/user_entry.dart';

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8500',
  );

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static bool get isLoggedIn => _token != null;
  static String? get token => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> _handleResponse(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    throw ApiException(body['detail'] ?? 'Error del servidor', r.statusCode);
  }

  static Future<List<dynamic>> _handleListResponse(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(utf8.decode(r.bodyBytes));
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
    final r = await http.get(Uri.parse('$_baseUrl/auth/me'), headers: _headers);
    return _handleResponse(r);
  }

  static Future<Map<String, dynamic>> register(String username, String password, {String? displayName}) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password, 'display_name': displayName}),
    );
    return _handleResponse(r);
  }

  // Media search
  static Future<List<SearchResult>> searchMetadata(String query, String type) async {
    final r = await http.get(
      Uri.parse('$_baseUrl/media/search?q=${Uri.encodeComponent(query)}&type=$type'),
      headers: _headers,
    );
    final list = await _handleListResponse(r);
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
    final r = await http.get(Uri.parse(url), headers: _headers);
    final list = await _handleListResponse(r);
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
    final list = await _handleListResponse(r);
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
    final r = await http.put(
      Uri.parse('$_baseUrl/entries/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return UserEntry.fromJson(await _handleResponse(r));
  }

  static Future<void> deleteEntry(int id) async {
    await http.delete(Uri.parse('$_baseUrl/entries/$id'), headers: _headers);
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await http.get(Uri.parse('$_baseUrl/entries/stats'), headers: _headers);
    return _handleResponse(r);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
