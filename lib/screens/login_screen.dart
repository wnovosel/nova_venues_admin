import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../models/app_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email   = TextEditingController();
  final _pass    = TextEditingController();
  final _auth    = LocalAuthentication();
  bool _obscure  = true;
  bool _canBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      setState(() => _canBiometric = canAuth && isSupported);
      if (_canBiometric) _tryBiometric();
    } catch (_) {}
  }

  Future<void> _tryBiometric() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Sign in to Nova Venues Admin',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (authenticated && mounted) {
        final provider = context.read<AppProvider>();
        // Restore existing session — biometric just unlocks it
        await provider.restoreAndValidate();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // near-black like logo
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo
              Image.asset(
                'assets/images/nova_venue_logo.png',
                width: 220,
                height: 220,
              ),

              const SizedBox(height: 8),

              // Tagline
              const Text(
                'Admin Portal',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9B1B2B),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 48),

              // Email field
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFF888888)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9B1B2B), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _pass,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Color(0xFF888888)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9B1B2B), width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: const Color(0xFF888888),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              if (provider.error != null) ...[
                const SizedBox(height: 12),
                Text(provider.error!,
                    style: const TextStyle(color: Color(0xFF9B1B2B), fontSize: 13)),
              ],

              const SizedBox(height: 16),

              // Face ID button
              if (_canBiometric)
                GestureDetector(
                  onTap: _tryBiometric,
                  child: Column(children: [
                    Icon(Icons.face_unlock_outlined, color: const Color(0xFF9B1B2B), size: 36),
                    const SizedBox(height: 4),
                    const Text('Sign in with Face ID',
                        style: TextStyle(color: Color(0xFF9B1B2B), fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),

              const SizedBox(height: 20),

              // Sign in button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: provider.loading ? null : () async {
                    await provider.login(_email.text.trim(), _pass.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B1B2B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: provider.loading
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
