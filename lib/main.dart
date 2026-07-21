import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'design_system/nova_navigation_shell.dart';
import 'models/app_provider.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/appearance_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AppearanceController()),
      ],
      child: const NovaAdminApp(),
    ),
  );
}

class NovaAdminApp extends StatelessWidget {
  const NovaAdminApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    return MaterialApp(
      title: 'Nova Venue',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      darkTheme: buildAdminTheme(brightness: Brightness.dark),
      themeMode: appearance.themeMode,
      home: home ?? const AppRoot(),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final appearance = context.watch<AppearanceController>();
    if (provider.loading || !appearance.ready) {
      return const _NovaSplashScreen();
    }
    return provider.loggedIn ? const NovaAppShell() : const LoginScreen();
  }
}

class _NovaSplashScreen extends StatelessWidget {
  const _NovaSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 34),
                child: Image(
                  image: AssetImage('assets/images/nova_venue_logo.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: 46,
              right: 46,
              bottom: 54,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0xFF241012),
                color: Color(0xFFFF1A25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
