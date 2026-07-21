import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/admin_api.dart';

class AppProvider extends ChangeNotifier {
  final api = AdminApiClient();

  bool _loading = true;
  bool _loggedIn = false;
  String? _error;
  String _tenantName = 'Nova Venues';
  Color _primaryColor = const Color(0xFF8E2434);
  Color? _secondaryColor;

  bool get loading => _loading;
  bool get loggedIn => _loggedIn;
  String? get error => _error;
  String get tenantName => _tenantName;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor ?? _primaryColor;

  AppProvider() {
    _restore();
  }

  Future<void> _restore() async {
    await api.restoreSession();
    _loggedIn = api.isAuthenticated;
    if (_loggedIn) await _fetchTenantBranding();
    _loading = false;
    notifyListeners();
  }

  Future<void> restoreAndValidate() async {
    await api.restoreSession();
    if (api.isAuthenticated) {
      _loggedIn = true;
      await _fetchTenantBranding();
      notifyListeners();
    }
  }

  Future<void> forceLogout() async {
    _loggedIn = false;
    _tenantName = 'Nova Venues';
    _primaryColor = const Color(0xFF8E2434);
    _secondaryColor = null;
    _error = null;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    await api.logout();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final ok = await api.login(email, password);
      _loggedIn = ok;
      if (!ok) _error = 'Invalid email or password.';
      if (ok) await _fetchTenantBranding();
      _loading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _fetchTenantBranding() async {
    try {
      final response = await api.getMorningData();
      final branding = _asMap(response['branding']) ??
          _asMap(response['theme']) ??
          _asMap(response['tenant']);

      final name = _firstString([
        response['tenant_name'],
        branding?['tenant_name'],
        branding?['name'],
      ]);
      final primary = _firstColor([
        response['primary_color'],
        response['brand_color'],
        branding?['primary_color'],
        branding?['primary'],
        branding?['brand_color'],
        branding?['accent_color'],
      ]);
      final secondary = _firstColor([
        response['secondary_color'],
        branding?['secondary_color'],
        branding?['secondary'],
      ]);

      if (name != null) _tenantName = name;
      if (primary != null) _primaryColor = primary;
      _secondaryColor = secondary;
    } catch (_) {
      // Keep the neutral Nova fallback if an older API response has no branding.
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  String? _firstString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Color? _firstColor(List<dynamic> values) {
    for (final value in values) {
      final parsed = _parseColor(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  Color? _parseColor(dynamic value) {
    if (value is int) return Color(value);
    if (value is! String) return null;
    var hex = value.trim().replaceFirst('#', '').replaceFirst('0x', '');
    if (hex.length == 3) {
      hex = hex.split('').map((character) => '$character$character').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  Future<void> logout() async {
    await forceLogout();
  }
}
