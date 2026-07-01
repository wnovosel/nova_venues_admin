import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),

              // Logo area
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.wine_bar, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 24),

              const Text('Nova Venues', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700,
                color: kTextDark, fontFamily: 'Georgia',
              )),
              const SizedBox(height: 4),
              const Text('Admin Portal', style: TextStyle(
                fontSize: 15, color: kTextMuted,
              )),

              const SizedBox(height: 48),

              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _pass,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    color: kTextMuted,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              if (provider.error != null) ...[
                const SizedBox(height: 12),
                Text(provider.error!, style: const TextStyle(color: kError, fontSize: 13)),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: provider.loading ? null : () async {
                    await provider.login(_email.text.trim(), _pass.text);
                  },
                  child: provider.loading
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
