import 'package:flutter/foundation.dart';
import '../api/admin_api.dart';

class AppProvider extends ChangeNotifier {
  final api = AdminApiClient();
  bool _loading = true;
  bool _loggedIn = false;
  String? _error;

  bool get loading  => _loading;
  bool get loggedIn => _loggedIn;
  String? get error => _error;

  AppProvider() { _restore(); }

  Future<void> _restore() async {
    await api.restoreSession();
    _loggedIn = api.isAuthenticated;
    _loading = false;
    notifyListeners();
  }

  void forceLogout() {
    api.logout();
    _loggedIn = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final ok = await api.login(email, password);
      _loggedIn = ok;
      if (!ok) _error = 'Invalid email or password.';
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

  Future<void> logout() async {
    await api.logout();
    _loggedIn = false;
    notifyListeners();
  }
}
