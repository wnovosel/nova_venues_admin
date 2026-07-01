import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const kApiBase = 'https://nova-venue.com';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});
  @override String toString() => message;
}

class AdminApiClient {
  String? _sessionCookie;
  final _storage = const FlutterSecureStorage();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBase/platform/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'email': email, 'password': password},
    );
    // Extract session cookie from response
    final cookie = res.headers['set-cookie'];
    if (cookie != null && res.statusCode < 400) {
      _sessionCookie = cookie.split(';').first;
      await _storage.write(key: 'admin_session', value: _sessionCookie);
      return true;
    }
    return false;
  }

  Future<void> restoreSession() async {
    _sessionCookie = await _storage.read(key: 'admin_session');
  }

  Future<void> logout() async {
    _sessionCookie = null;
    await _storage.delete(key: 'admin_session');
  }

  bool get isAuthenticated => _sessionCookie != null;

  // ── Morning Brief ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMorningData() =>
      _get('/platform/morning/api/data');

  // ── Inbox ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getInbox() =>
      _getAdmin('/inbox');

  Future<Map<String, dynamic>> getInboxMessage(int id) =>
      _getAdmin('/inbox/msg/$id');

  // ── Events ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEvents() =>
      _getAdmin('/events');

  Future<Map<String, dynamic>> getEventDetail(String id) =>
      _getAdmin('/events/$id/edit');

  Future<Map<String, dynamic>> cancelEvent(String id) =>
      _postAdmin('/events/$id/cancel', {});

  Future<Map<String, dynamic>> toggleSoldOut(String id) =>
      _postAdmin('/events/$id/toggle-soldout', {});

  // ── Rentals ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRentals() =>
      _getAdmin('/rentals');

  Future<Map<String, dynamic>> getRentalDetail(String id) =>
      _getAdmin('/rentals/$id');

  Future<Map<String, dynamic>> confirmRental(String id, Map<String, dynamic> data) =>
      _postAdmin('/rentals/$id/confirm', data);

  Future<Map<String, dynamic>> declineRental(String id) =>
      _postAdmin('/rentals/$id/decline', {});

  Future<Map<String, dynamic>> addRentalNote(String id, String note) =>
      _postAdmin('/rentals/$id/notes', {'note': note});

  // ── Marketing ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMarketingQueue() =>
      _getAdmin('/marketing');

  // ── HTTP plumbing ─────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_sessionCookie != null) 'Cookie': _sessionCookie!,
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

  Future<Map<String, dynamic>> _getAdmin(String path) =>
      _get('/nova-admin$path');

  Future<Map<String, dynamic>> _postAdmin(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/nova-admin$path'),
        headers: {..._headers, 'Content-Type': 'application/json'},
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
    if (res.statusCode == 401 || res.statusCode == 302) {
      throw const ApiException('Session expired. Please log in again.', statusCode: 401);
    }
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) return body;
      return {'data': body};
    } catch (_) {
      // HTML response — extract JSON if embedded, else return empty
      return {};
    }
  }
}
