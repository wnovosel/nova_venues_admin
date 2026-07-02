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
      _get('/api/v1/admin-inbox');

  Future<Map<String, dynamic>> getEmailDetail(int id) =>
      _get('/api/v1/admin-inbox');

  Future<Map<String, dynamic>> replyEmail(int id, String body) =>
      _post('/api/v1/admin/customers', {'body': body});

  Future<Map<String, dynamic>> composeEmail(String to, String subject, String body) =>
      _post('/api/v1/admin/customers', {'to': to, 'subject': subject, 'body': body});

  // ── Events ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEvents() =>
      _get('/api/v1/admin/events');

  // ── Rentals ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRentals() =>
      _get('/api/v1/admin/rentals');

  Future<Map<String, dynamic>> confirmRental(String id) =>
      _post('/api/v1/admin/rentals/$id/status', {});

  Future<Map<String, dynamic>> declineRental(String id) =>
      _post('/api/v1/admin/rentals/$id/status', {});

  Future<Map<String, dynamic>> addRentalNote(String id, String note) =>
      _post('/api/v1/admin/rentals/$id/status', {'note': note});

  // ── Marketing ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMarketingQueue() =>
      _get('/api/v1/admin/brief');


  // ── Dashboard ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard() =>
      _get('/api/v1/admin/dashboard');

  Future<Map<String, dynamic>> markVoicemailHandled(dynamic id) =>
      _post('/api/v1/admin/dashboard/voicemail/$id/handled', {});

  Future<Map<String, dynamic>> updateHireStatus(dynamic id, String status) =>
      _post('/api/v1/admin/dashboard/hire/$id/status', {'status': status});

  Future<Map<String, dynamic>> updateVendorStatus(dynamic id, String status) =>
      _post('/api/v1/admin/dashboard/vendor/$id/status', {'status': status});

  // ── Marketing snap ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getR2UploadUrl() =>
      _get('/api/v1/admin/brief');

  Future<Map<String, dynamic>> snapPost(String imageUrl, String platform, String action) =>
      _post('/api/v1/admin/brief',
          {'image_url': imageUrl, 'platform': platform, 'action': action});

  Future<Map<String, dynamic>> snapArchive(String imageUrl) =>
      _post('/api/v1/admin/brief', {'image_url': imageUrl});

  Future<void> uploadToR2(String uploadUrl, List<int> bytes) async {
    await http.put(Uri.parse(uploadUrl), body: bytes,
        headers: {'Content-Type': 'image/jpeg'});
  }

  Future<Map<String, dynamic>> approvePost(dynamic id) =>
      _post('/api/v1/admin/vendors/$id/status', {});


  Future<Map<String, dynamic>> getEventAttendees(int id) =>
      _get('/api/v1/admin/events/$id/attendees');

  Future<Map<String, dynamic>> getEventDetail(int id) =>
      _get('/api/v1/admin/events/$id');

  Future<Map<String, dynamic>> cancelEvent(String id) =>
      _post('/api/v1/admin/events/$id/cancel', {});

  Future<Map<String, dynamic>> toggleSoldOut(String id) =>
      _post('/api/v1/admin/events/$id/toggle-soldout', {});

  Future<Map<String, dynamic>> togglePublish(String id) =>
      _post('/api/v1/admin/events/$id/toggle-publish', {});

  Future<Map<String, dynamic>> checkIn(int eventId, dynamic ticketId) =>
      _post('/api/v1/admin/events/$eventId/checkin/$ticketId', {});

  Future<Map<String, dynamic>> undoCheckin(int eventId, dynamic ticketId) =>
      _post('/api/v1/admin/events/$eventId/attendees/$ticketId/undo-checkin', {});


  // ── Rental detail ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRentalDetail(dynamic id) =>
      _get('/api/v1/admin/rentals/$id');

  Future<Map<String, dynamic>> confirmRentalDetail(String id,
      {double? deposit, double? total, String notes = ''}) =>
      _post('/api/v1/admin/rentals/$id/confirm-detail', {
        if (deposit != null) 'deposit_amount': deposit,
        if (total != null) 'total_amount': total,
        'admin_notes': notes,
      });

  Future<Map<String, dynamic>> addRentalNote(String id, String note) =>
      _post('/api/v1/admin/rentals/$id/add-note', {'note': note});

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
      _token = null;
      _refreshToken = null;
      _storage.deleteAll();
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
