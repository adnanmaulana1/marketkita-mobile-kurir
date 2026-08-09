import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  static const _prefsToken = 'auth_token';
  static String? _token;

  static String? get token => _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefsToken);
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsToken, token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsToken);
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(AppConfig.baseUrl);
    var u = base.resolve(path);
    if (query != null && query.isNotEmpty) {
      u = u.replace(queryParameters: {...u.queryParameters, ...query});
    }
    return u;
  }

  static Map<String, String> _headers() {
    final h = <String, String>{'Accept': 'application/json'};
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  static Map<String, dynamic> _check(http.Response res) {
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      throw ApiException('Respons tidak valid dari server (${res.statusCode})');
    }
    if (res.statusCode >= 400) {
      final msg = (data is Map && data['msg'] != null) ? data['msg'].toString() : 'Terjadi kesalahan (${res.statusCode})';
      throw ApiException(msg);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(_uri(path), headers: _headers());
    return _check(res);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, String> body) async {
    final res = await http.post(_uri(path), headers: _headers(), body: body);
    return _check(res);
  }

  // ===== AUTH =====
  static Future<User> login(String email, String password) async {
    final res = await http.post(_uri('/api/auth/login'), body: {'email': email, 'password': password});
    final d = _check(res);
    await saveToken(d['token'] as String);
    return User.fromJson(d['user']);
  }

  static Future<User> register({
    required String nama,
    required String email,
    required String telepon,
    required String password,
    required String kendaraan,
  }) async {
    final res = await http.post(
      _uri('/api/auth/register'),
      body: {
        'nama': nama,
        'email': email,
        'telepon': telepon,
        'password': password,
        'role': 'kurir',
        'kendaraan': kendaraan,
      },
    );
    final d = _check(res);
    await saveToken(d['token'] as String);
    return User.fromJson(d['user']);
  }

  static Future<User> me() async {
    final res = await http.get(_uri('/api/auth/me'), headers: _headers());
    final d = _check(res);
    return User.fromJson(d['user']);
  }

  static Future<void> logout() async => clearToken();
}
