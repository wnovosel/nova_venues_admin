import 'package:flutter/foundation.dart';
import '../api/admin_api.dart';

class AppProvider extends ChangeNotifier {
  final api = AdminApiClient();
  bool _loading = true;
  bool _loggedIn = false;
  String? _error;
  String _tenantName = 'Nova Venues';

  bool get loading      => _loading;
  bool get loggedIn     => _loggedIn;
  String? get error     => _error;
  String get tenantName => _tenantName;

  AppProvider() { _restore(); }

  Future<void> _restore() async {
    await api.restoreSession();
    _loggedIn = api.isAuthenticated;
    _loading = false;
    notifyListeners();
  }

  Future<void> restoreAndValidate() async {
    await api.restoreSession();
    if (api.isAuthenticated) {
      _loggedIn = true;
      notifyListeners();
    }
  }

  Future<void> forceLogout() async {
    _loggedIn = false;
    _tenantName = 'Nova Venues';
    _error = null;
    notifyListeners();
    // Logout after notifying so UI can transition first
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
      if (ok) await _fetchTenantName();
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

  Future<void> _fetchTenantName() async {
    try {
      final res = await api.getMorningData();
      final name = res['tenant_name'] as String?;
      if (name != null && name.isNotEmpty) _tenantName = name;
    } catch (_) {}
  }

  Future<void> logout() async {
    await api.logout();
    _loggedIn = false;
    notifyListeners();
  }
}
