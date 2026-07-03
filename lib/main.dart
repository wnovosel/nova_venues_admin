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
import 'screens/calendar/calendar_screen.dart';

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
      title: 'Nova Venues',
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
    CalendarScreen(),
    MarketingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // Persistent top bar with logo + tenant name
        Container(
          color: const Color(0xFF0A0A0A),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16, right: 16, bottom: 10,
          ),
          child: Row(children: [
            Image.asset('assets/images/nova_venue_logo.png', height: 30, width: 30),
            const SizedBox(width: 10),
            Consumer<AppProvider>(
              builder: (_, provider, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(provider.tenantName, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const Text('Nova Venues Admin', style: TextStyle(
                  color: Color(0xFF9B1B2B), fontSize: 11, fontWeight: FontWeight.w500,
                  letterSpacing: 1)),
              ]),
            ),
          ]),
        ),
        Expanded(child: IndexedStack(index: _index, children: _screens)),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          if (i == 6) {
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
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
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
