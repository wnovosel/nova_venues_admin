import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum NovaAppearance { system, light, dark }

class AppearanceController extends ChangeNotifier {
  AppearanceController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _restore();
  }

  static const storageKey = 'nova_appearance';
  final FlutterSecureStorage _storage;
  NovaAppearance _appearance = NovaAppearance.system;
  bool _ready = false;

  NovaAppearance get appearance => _appearance;
  bool get ready => _ready;
  ThemeMode get themeMode => switch (_appearance) {
    NovaAppearance.light => ThemeMode.light,
    NovaAppearance.dark => ThemeMode.dark,
    NovaAppearance.system => ThemeMode.system,
  };

  Future<void> _restore() async {
    try {
      final value = await _storage.read(key: storageKey);
      _appearance = NovaAppearance.values.firstWhere(
        (option) => option.name == value,
        orElse: () => NovaAppearance.system,
      );
    } catch (_) {
      _appearance = NovaAppearance.system;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> select(NovaAppearance appearance) async {
    if (_appearance == appearance) return;
    _appearance = appearance;
    notifyListeners();
    await _storage.write(key: storageKey, value: appearance.name);
  }
}
