import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const kApiBase      = 'https://nova-venue.com';
const kSupabaseUrl  = 'https://umgsxpdtwoehomqcagvd.supabase.co';
const kSupabaseKey  = 'sb_publishable_icPM2xuhjXOhGluB514rpg_h63K3ofb';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});
  @override String toString() => message;
}

class AdminApiClient {
  String? _token;
  String? _refreshToken;
  final _storage = const FlutterSecureStorage();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': kSupabaseKey,
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      _token = body['access_token'];
      _refreshToken = body['refresh_token'];
      if (_token != null) {
        await _storage.write(key: 'admin_token', value: _token);
        if (_refreshToken != null) {
          await _storage.write(key: 'admin_refresh', value: _refreshToken);
        }
        return true;
      }
    }
    return false;
  }

  Future<void> restoreSession() async {
    _token = await _storage.read(key: 'admin_token');
    _refreshToken = await _storage.read(key: 'admin_refresh');
  }

  Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    await _storage.deleteAll();
  }

  bool get isAuthenticated => _token != null;

  // ── Morning Brief ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMorningData() =>
      _get('/api/v1/admin/brief');

  // ── Inbox ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getInbox() =>
      _get('/api/v1/admin/inbox');

  Future<Map<String, dynamic>> getEmailDetail(int id) =>
      _get('/api/v1/admin/inbox/email/$id');

  Future<Map<String, dynamic>> replyEmail(int id, String body) =>
      _post('/api/v1/admin/inbox/email/$id/reply', {'body': body});

  Future<Map<String, dynamic>> composeEmail(String to, String subject, String body) =>
      _post('/api/v1/admin/inbox/email/compose', {'to': to, 'subject': subject, 'body': body});

  // ── Events ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEvents() =>
      _get('/api/v1/admin/events');

  Future<Map<String, dynamic>> getEventAttendees(int id) =>
      _get('/api/v1/admin/events/$id/attendees');

  Future<Map<String, dynamic>> cancelEvent(String id) =>
      _post('/api/v1/admin/events/$id/status', {'status': 'cancelled'});

  Future<Map<String, dynamic>> toggleSoldOut(String id) =>
      _post('/api/v1/admin/events/$id/status', {'toggle_soldout': true});

  // ── Rentals ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRentals() =>
      _get('/api/v1/admin/rentals');

  Future<Map<String, dynamic>> confirmRental(String id, Map<String, dynamic> data) =>
      _post('/api/v1/admin/rentals/$id/status', {'status': 'confirmed'});

  Future<Map<String, dynamic>> declineRental(String id) =>
      _post('/api/v1/admin/rentals/$id/status', {'status': 'declined'});

  Future<Map<String, dynamic>> addRentalNote(String id, String note) =>
      _post('/api/v1/admin/rentals/$id/status', {'note': note});

  // ── Marketing ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMarketingQueue() =>
      _get('/api/v1/admin/brief');

  // ── HTTP plumbing ─────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase$path'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      return _handle(res);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on TimeoutException {
      throw const ApiException('Request timed out.');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return _handle(res);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on TimeoutException {
      throw const ApiException('Request timed out.');
    }
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode == 401) {
      throw const ApiException('Session expired. Please log in again.', statusCode: 401);
    }
    if (res.statusCode == 403) {
      throw const ApiException('Access denied.', statusCode: 403);
    }
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) return body;
      return {'data': body};
    } catch (_) {
      return {};
    }
  }
}
