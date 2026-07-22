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
    // Proactive: access tokens live 60 min. If this one is expired or about to
    // expire, refresh NOW — before the home screen fires parallel requests.
    // (Lazy refresh-on-401 under parallel load caused a refresh stampede: many
    // requests reused the same rotating refresh token, Supabase reuse-detection
    // revoked the whole token family, and the "session" died within the hour.)
    if (_token != null && _tokenExpiresWithin(const Duration(minutes: 5))) {
      final ok = await _refreshIfNeeded();
      if (!ok && _tokenExpiresWithin(Duration.zero)) {
        // Token is genuinely expired and refresh failed — don't fake-enter the
        // app with a dead token (that's the "Face ID works then bounces" bug).
        // Keep storage intact: a network blip shouldn't wipe credentials;
        // the next launch retries the refresh.
        _token = null;
      }
    }
  }

  /// Decode the JWT exp claim locally — no network, no verification needed
  /// (the server verifies; we only need the timestamp for scheduling).
  bool _tokenExpiresWithin(Duration window) {
    try {
      final parts = _token!.split('.');
      if (parts.length != 3) return true;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) { payload += '='; }
      final map = jsonDecode(utf8.decode(base64.decode(payload)));
      final exp = (map['exp'] as num?)?.toInt();
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry.subtract(window));
    } catch (_) {
      return true; // unreadable token → treat as expiring, refresh
    }
  }

  // Single-flight: concurrent callers share ONE refresh. Firing multiple
  // refreshes with the same rotating token trips Supabase reuse-detection
  // and revokes the token family — the root cause of early "session expired".
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshIfNeeded() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final fut = _doRefresh().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = fut;
    return fut;
  }

  Future<bool> _doRefresh() async {
    if (_refreshToken == null) return false;
    try {
      const supabaseUrl = 'https://umgsxpdtwoehomqcagvd.supabase.co';
      const supabaseKey = 'sb_publishable_icPM2xuhjXOhGluB514rpg_h63K3ofb';
      final res = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {'Content-Type': 'application/json', 'apikey': supabaseKey},
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _token = body['access_token'];
        _refreshToken = body['refresh_token'];
        await _storage.write(key: 'admin_token', value: _token);
        await _storage.write(key: 'admin_refresh', value: _refreshToken);
        return true;
      }
      // 400/401 from the token endpoint = refresh token truly dead.
      // Anything else (5xx, weird) — keep tokens, let the user retry later.
      if (res.statusCode == 400 || res.statusCode == 401) {
        return false;
      }
    } catch (_) {
      // Network blip — do NOT kill the session over it.
    }
    return false;
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
      _get('/api/v1/admin-inbox/email/$id');

  Future<Map<String, dynamic>> replyEmail(int id, String body) =>
      _post('/api/v1/admin-inbox/email/$id/reply', {'body': body});

  Future<Map<String, dynamic>> replyToMessage(int id, String body) =>
      _post('/api/v1/admin-inbox/message/$id/reply', {'body': body});

  Future<Map<String, dynamic>> markMessageHandled(int id, bool handled) =>
      _post('/api/v1/admin-inbox/message/$id/handled', {'handled': handled});

  Future<Map<String, dynamic>> markVoicemailHeard(String callSid) =>
      _post('/api/v1/admin-inbox/voicemail/$callSid/heard', {});

  Future<Map<String, dynamic>> composeEmail(String to, String subject, String body) =>
      _post('/api/v1/admin-inbox/compose', {'to': to, 'subject': subject, 'body': body});

  // ── Hiring ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getHiring([String status = 'new']) =>
      _get('/api/v1/admin/hiring?status=$status');
  Future<Map<String, dynamic>> getHiringDetail(String id) =>
      _get('/api/v1/admin/hiring/$id');
  Future<Map<String, dynamic>> setHiringStatus(String id, String status) =>
      _post('/api/v1/admin/hiring/$id/status', {'status': status});
  Future<Map<String, dynamic>> setHiringNotes(String id, String notes) =>
      _post('/api/v1/admin/hiring/$id/notes', {'notes': notes});

  // ── Vendors (module) ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getVendors([String status = 'pending']) =>
      _get('/api/v1/admin/vendors?status=$status');
  Future<Map<String, dynamic>> getVendorDetail(String partyId) =>
      _get('/api/v1/admin/vendors/$partyId');

  Future<Map<String, dynamic>> setVendorStatus(String id, String status) =>
      _post('/api/v1/admin/dashboard/vendor/$id/status', {'status': status});

  // ── Wine Club ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWineClub() =>
      _get('/api/v1/admin/club');
  Future<Map<String, dynamic>> runClubCharge(int clubId, {int? amountCents}) =>
      _post('/api/v1/admin/club/run',
          {'club_id': clubId, if (amountCents != null) 'amount_cents': amountCents});

  // ── Chat Hub ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getChatHub() =>
      _get('/api/v1/admin/chat');
  Future<Map<String, dynamic>> getChatLogs({int limit = 200}) =>
      _get('/api/v1/admin/chat/logs?limit=$limit');
  Future<Map<String, dynamic>> addFaq(String keyword, String question, String answer) =>
      _post('/api/v1/admin/chat/faq',
          {'keyword': keyword, 'question': question, 'answer': answer});
  Future<Map<String, dynamic>> updateFaq(int id, String keyword, String question, String answer) =>
      _post('/api/v1/admin/chat/faq/$id/update',
          {'keyword': keyword, 'question': question, 'answer': answer});
  Future<Map<String, dynamic>> toggleFaq(int id, bool active) =>
      _post('/api/v1/admin/chat/faq/$id/toggle', {'active': active});
  Future<Map<String, dynamic>> deleteFaq(int id) =>
      _post('/api/v1/admin/chat/faq/$id/delete', {});

  // ── Phone Assistant ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPhone() =>
      _get('/api/v1/admin/phone');
  Future<Map<String, dynamic>> savePhoneSettings(Map<String, dynamic> settings) =>
      _post('/api/v1/admin/phone/settings', settings);

  // ── Events ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEvents() =>
      _get('/api/v1/admin/events');

  // ── Rentals ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRentals() =>
      _get('/api/v1/admin/rentals');

  // Backend /admin/rentals/<id>/status REQUIRES a valid status in the body
  // (one of: pending, confirmed, declined, cancelled, completed) and returns
  // 400 otherwise. Sending {} made both of these fail — always. Verified
  // against src/blueprints/mobile_api.py::admin_rental_status.
  Future<Map<String, dynamic>> confirmRental(String id) =>
      _post('/api/v1/admin/rentals/$id/status', {'status': 'confirmed'});

  Future<Map<String, dynamic>> declineRental(String id) =>
      _post('/api/v1/admin/rentals/$id/status', {'status': 'declined'});


  // ── Marketing ─────────────────────────────────────────────────────────────

  // Was wrongly pointed at /admin/brief (the morning brief), which returns no
  // 'posts' key — so the marketing screen silently rendered an empty queue.
  // /admin/marketing is the real endpoint and returns {"posts":[...]} with the
  // exact fields the screen reads. Verified against mobile_api.py::admin_marketing_list.
  Future<Map<String, dynamic>> getMarketingQueue() =>
      _get('/api/v1/admin/marketing');


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
      _get('/api/v1/admin/marketing/r2-upload-url');

  Future<Map<String, dynamic>> snapPost(String imageUrl, String platform, String action) =>
      _post('/api/v1/admin/marketing/snap-post',
          {'image_url': imageUrl, 'platform': platform, 'action': action});

  Future<Map<String, dynamic>> snapArchive(String imageUrl) =>
      _post('/api/v1/admin/marketing/snap-archive', {'image_url': imageUrl});

  Future<void> uploadToR2(String uploadUrl, List<int> bytes) async {
    await http.put(Uri.parse(uploadUrl), body: bytes,
        headers: {'Content-Type': 'image/jpeg'});
  }

  Future<Map<String, dynamic>> approvePost(dynamic id) =>
      _post('/api/v1/admin/marketing/$id/approve', {});


  Future<Map<String, dynamic>> getEventAttendees(int id) =>
      _get('/api/v1/admin/events/$id/attendees');

  Future<Map<String, dynamic>> getEventDetail(int id) =>
      _get('/api/v1/admin/events/$id');

  /// Search customers by name or email. Backend fixed 2026-07-22 — it had
  /// joined a nonexistent table and 500'd on every call since it was written.
  Future<Map<String, dynamic>> searchCustomers(String query) =>
      _get('/api/v1/admin/customers?q=${Uri.encodeQueryComponent(query)}');

  /// All tickets for a customer by email -> {tickets:[...]} with event info.
  Future<Map<String, dynamic>> getCustomerTickets(String email) =>
      _get('/api/v1/admin/customers/tickets?email=${Uri.encodeQueryComponent(email)}');

  /// Resend a ticket email via the same sender that delivers at purchase.
  Future<Map<String, dynamic>> resendTicket(int ticketId) =>
      _post('/api/v1/admin/tickets/$ticketId/resend', {});

  /// Create (eventId null) or update an event. The backend REQUIRES
  /// action='publish'|'save_draft' — ambiguous publish state is refused
  /// because it once force-unpublished events on every save. Dates go as ISO
  /// starts_at/ends_at strings.
  Future<Map<String, dynamic>> saveEvent(Map<String, dynamic> fields, {int? eventId}) =>
      _post(eventId == null
          ? '/api/v1/admin/events/save'
          : '/api/v1/admin/events/$eventId/save', fields);

  Future<Map<String, dynamic>> cancelEvent(String id) =>
      _post('/api/v1/admin/events/$id/cancel', {});

  Future<Map<String, dynamic>> toggleSoldOut(String id) =>
      _post('/api/v1/admin/events/$id/toggle-soldout', {});

  Future<Map<String, dynamic>> togglePublish(String id) =>
      _post('/api/v1/admin/events/$id/toggle-publish', {});

  Future<Map<String, dynamic>> checkIn(int eventId, dynamic ticketId) =>
      _post('/api/v1/admin/events/$eventId/checkin/$ticketId', {});

  /// Check in a ticket by its scanned QR token. Backend accepts a bare UUID or
  /// a full ticket URL and returns {checked_in, already_checked_in, name,
  /// event_name, quantity}. Verified against mobile_api.py::admin_scan_checkin.
  Future<Map<String, dynamic>> scanCheckin(String token) =>
      _post('/api/v1/admin/events/scan-checkin', {'token': token});

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


  // ── Inbox IMAP actions ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> archiveEmail(int id) =>
      _post('/api/v1/admin-inbox/email/$id/archive', {});

  Future<Map<String, dynamic>> trashEmail(int id) =>
      _post('/api/v1/admin-inbox/email/$id/trash', {});

  Future<Map<String, dynamic>> markEmailUnread(int id) =>
      _post('/api/v1/admin-inbox/email/$id/unread', {});

  Future<Map<String, dynamic>> markEmailSpam(int id) =>
      _post('/api/v1/admin-inbox/email/$id/spam', {});

  // ── HTTP plumbing ─────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> getVendorEventRoster(String eventId) =>
      _get('/api/v1/admin/vendors/events/$eventId/roster');

  // ── Reservations (module, 2026-07-14) ───────────────────────────────────
  Future<Map<String, dynamic>> getReservations([String? day]) =>
      _get('/api/v1/admin/reservations${day != null ? '?day=$day' : ''}');
  Future<Map<String, dynamic>> getUpcomingReservations() =>
      _get('/api/v1/admin/reservations/upcoming');
  Future<Map<String, dynamic>> setReservationStatus(int id, String status) =>
      _post('/api/v1/admin/reservations/$id/status', {'status': status});
  Future<Map<String, dynamic>> chargeNoShow(int id) =>
      _post('/api/v1/admin/reservations/$id/charge-noshow', {});
  Future<Map<String, dynamic>> getReservationSlots(int experienceId, String date) =>
      _get('/api/v1/admin/reservations/slots?experience_id=$experienceId&date=$date');
  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> data) =>
      _post('/api/v1/admin/reservations/create', data);

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      // Proactive: refresh BEFORE the request if the token is stale — cheaper
      // and safer than the 401 round-trip, and it single-flights under load.
      if (_token != null && _refreshToken != null &&
          _tokenExpiresWithin(const Duration(minutes: 2))) {
        await _refreshIfNeeded();
      }
      var res = await http.get(
        Uri.parse('$kApiBase$path'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      // Auto-refresh on 401 and retry once
      if (res.statusCode == 401 && _refreshToken != null) {
        final refreshed = await _refreshIfNeeded();
        if (refreshed) {
          res = await http.get(Uri.parse('$kApiBase$path'), headers: _headers)
              .timeout(const Duration(seconds: 15));
        }
      }
      return _handle(res);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on TimeoutException {
      throw const ApiException('Request timed out.');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      if (_token != null && _refreshToken != null &&
          _tokenExpiresWithin(const Duration(minutes: 2))) {
        await _refreshIfNeeded();
      }
      var res = await http.post(
        Uri.parse('$kApiBase$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      // _post previously had NO refresh-retry — any action after ~1h idle
      // threw "Session expired" even though a refresh would have fixed it.
      if (res.statusCode == 401 && _refreshToken != null) {
        final refreshed = await _refreshIfNeeded();
        if (refreshed) {
          res = await http.post(Uri.parse('$kApiBase$path'),
              headers: _headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 15));
        }
      }
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
