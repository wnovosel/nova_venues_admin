import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'design_system/nova_app_shell.dart';
import 'design_system/nova_components.dart';
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
      title: 'Nova Venues',
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
      return const Scaffold(
        body: NovaLoadingState(label: 'Restoring your session'),
      );
    }
    return provider.loggedIn ? const NovaAppShell() : const LoginScreen();
  }
}
