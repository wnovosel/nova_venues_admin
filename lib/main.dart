import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/morning/morning_screen.dart';
import 'screens/inbox/inbox_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/rentals/rentals_screen.dart';
import 'screens/marketing/marketing_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const NovaAdminApp(),
    ),
  );
}

class NovaAdminApp extends StatelessWidget {
  const NovaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova Venues Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.loading) {
      return const Scaffold(
        backgroundColor: kBackground,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    return provider.loggedIn ? const _AdminShell() : const LoginScreen();
  }
}

class _AdminShell extends StatefulWidget {
  const _AdminShell();
  @override State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _index = 0;

  static const _screens = [
    MorningScreen(),
    InboxScreen(),
    EventsScreen(),
    RentalsScreen(),
    MarketingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          if (i == 5) {
            context.read<AppProvider>().forceLogout();
            return;
          }
          setState(() => _index = i);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined),
            activeIcon: Icon(Icons.wb_sunny),
            label: 'Morning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work_outlined),
            activeIcon: Icon(Icons.home_work),
            label: 'Rentals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Marketing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            activeIcon: Icon(Icons.logout),
            label: 'Sign Out',
          ),
        ],
      ),
    );
  }
}
