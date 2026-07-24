import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _bioMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();
      if (!mounted) return;
      setState(() => _canBiometric = canAuth && isSupported);
      if (_canBiometric && enrolled.isNotEmpty) {
        _tryBiometric();
      } else if (canAuth && isSupported && enrolled.isEmpty) {
        // Device supports Face ID but nothing is enrolled — say so instead of
        // silently doing nothing.
        setState(() => _bioMessage =
            'Face ID is available but not set up on this device.');
      }
    } catch (e) {
      if (mounted) setState(() => _bioMessage = 'Face ID unavailable: $e');
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Sign in to Nova Venues Admin',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!authenticated || !mounted) return;
      final provider = context.read<AppProvider>();
      // Face ID does NOT log in — it unlocks a STORED session. If the saved
      // refresh token is gone or expired (long gap, logout, reinstall), the
      // restore silently does nothing and the user is left staring at the
      // login screen after a "successful" scan. Tell them to sign in once.
      await provider.restoreAndValidate();
      if (!mounted) return;
      if (!provider.loggedIn) {
        setState(() => _bioMessage =
            'Your saved session expired. Sign in with your password once to re-enable Face ID.');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      // The common real-world cases, named rather than swallowed.
      final msg = switch (e.code) {
        'NotEnrolled' => 'No Face ID enrolled on this device.',
        'NotAvailable' => 'Face ID is not available. Check Settings → Face ID.',
        'LockedOut' || 'PermanentlyLockedOut' =>
          'Face ID is locked after too many attempts. Use your passcode, then try again.',
        'PasscodeNotSet' => 'Set a device passcode to use Face ID.',
        _ => 'Face ID failed (${e.code}).',
      };
      setState(() => _bioMessage = msg);
    } catch (e) {
      if (mounted) setState(() => _bioMessage = 'Face ID failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: NovaColors.darkCanvas, // near-black like logo
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
                  color: NovaColors.fallbackPrimary,
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
                  labelStyle: const TextStyle(color: NovaColors.darkMuted),
                  filled: true,
                  fillColor: NovaColors.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NovaColors.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NovaColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NovaColors.fallbackPrimary, width: 1.5),
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
                  labelStyle: const TextStyle(color: NovaColors.darkMuted),
                  filled: true,
                  fillColor: NovaColors.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NovaColors.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NovaColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NovaColors.fallbackPrimary, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: NovaColors.darkMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              if (provider.error != null) ...[
                const SizedBox(height: 12),
                Text(provider.error!,
                    style: const TextStyle(color: NovaColors.fallbackPrimary, fontSize: 13)),
              ],

              const SizedBox(height: 16),

              // Face ID button
              if (_canBiometric)
                GestureDetector(
                  onTap: _tryBiometric,
                  child: Column(children: [
                    Icon(Icons.face_unlock_outlined, color: NovaColors.fallbackPrimary, size: 36),
                    const SizedBox(height: 4),
                    const Text('Sign in with Face ID',
                        style: TextStyle(color: NovaColors.fallbackPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),

              // Why Face ID didn't work — previously every failure was
              // swallowed by an empty catch, so it just appeared broken.
              if (_bioMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _bioMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: NovaColors.darkMuted, fontSize: 12, height: 1.4),
                  ),
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
                    backgroundColor: NovaColors.fallbackPrimary,
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
