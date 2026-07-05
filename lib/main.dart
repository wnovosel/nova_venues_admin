import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/morning/morning_screen.dart';
import 'screens/inbox/inbox_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/rentals/rentals_screen.dart';
import 'screens/marketing/marketing_screen.dart';
import 'screens/hiring/hiring_screen.dart';
import 'screens/vendors/vendors_screen.dart';
import 'screens/wineclub/wineclub_screen.dart';
import 'screens/chathub/chathub_screen.dart';
import 'screens/phone/phone_screen.dart';
import 'screens/calendar/calendar_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    return provider.loggedIn ? const _AdminShell() : const LoginScreen();
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────

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
    HiringScreen(),
    VendorsScreen(),
    WineClubScreen(),
    ChatHubScreen(),
    PhoneScreen(),
  ];

  static const _titles = [
    'Morning Brief', 'Inbox', 'Events', 'Rentals', 'Calendar', 'Marketing',
    'Hiring', 'Vendors', 'Wine Club', 'Chat Hub', 'Phone Assistant',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Row(children: [
          Image.asset('assets/images/nova_venue_logo.png', height: 28, width: 28),
          const SizedBox(width: 10),
          Consumer<AppProvider>(
            builder: (_, p, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.tenantName, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              const Text('Nova Venues', style: TextStyle(
                color: Color(0xFF9B1B2B), fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _NavDrawer(
        currentIndex: _index,
        onSelect: (i) { setState(() => _index = i); Navigator.pop(context); },
        onLogout: () async {
          Navigator.pop(context);
          await provider.forceLogout();
        },
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index < 4 ? _index : 0,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined), activeIcon: Icon(Icons.wb_sunny), label: 'Morning'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined), activeIcon: Icon(Icons.inbox), label: 'Inbox'),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work_outlined), activeIcon: Icon(Icons.home_work), label: 'Rentals'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Calendar'),
        ],
      ),
    );
  }
}

// ── Navigation Drawer ─────────────────────────────────────────────────────────

class _NavDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  const _NavDrawer({required this.currentIndex, required this.onSelect, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F0F0F),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Image.asset('assets/images/nova_venue_logo.png', height: 40, width: 40),
                const SizedBox(width: 12),
                Consumer<AppProvider>(
                  builder: (_, p, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.tenantName, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    const Text('Admin', style: TextStyle(color: Color(0xFF9B1B2B), fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            const Divider(color: Color(0xFF222222)),

            // Overview
            _Section('Overview', [
              _Item(Icons.wb_sunny_outlined, 'Morning Brief', 0),
              _Item(Icons.inbox_outlined, 'Inbox', 1),
              _Item(Icons.attach_money, 'Sales & Revenue', -1),
            ]),

            // Operations
            _Section('Operations', [
              _Item(Icons.confirmation_num_outlined, 'Events & Ticketing', 2),
              _Item(Icons.storefront_outlined, 'Vendors', 7),
              _Item(Icons.home_work_outlined, 'Rentals', 3),
              _Item(Icons.people_outline, 'Hiring', 6),
              _Item(Icons.music_note_outlined, 'Musicians', -1),
              _Item(Icons.calendar_month_outlined, 'Calendar', 4),
              _Item(Icons.wine_bar_outlined, 'Wine Club', 8),
              _Item(Icons.restaurant_menu_outlined, 'Menus', -1),
              _Item(Icons.store_outlined, 'Store', -1),
            ]),

            // Marketing
            _Section('Marketing & Growth', [
              _Item(Icons.campaign_outlined, 'Marketing', 5),
              _Item(Icons.camera_alt_outlined, 'Snap & Post', 5),
              _Item(Icons.chat_outlined, 'Chat Hub', 9),
              _Item(Icons.phone_outlined, 'Phone Assistant', 10),
              _Item(Icons.card_giftcard_outlined, 'Gift Cards', -1),
              _Item(Icons.star_outline, 'Loyalty', -1),
            ]),

            // Display
            _Section('Display', [
              _Item(Icons.tv_outlined, 'Display Boards', -1),
              _Item(Icons.campaign, 'Announcements', -1),
            ]),

            // Accounting
            _Section('Accounting', [
              _Item(Icons.account_balance_outlined, 'Nova Books', -1),
              _Item(Icons.receipt_outlined, 'Review Transactions', -1),
              _Item(Icons.inventory_2_outlined, 'Inventory', -1),
            ]),

            // System
            _Section('System', [
              _Item(Icons.people_outlined, 'Staff Access', -1),
              _Item(Icons.settings_outlined, 'Settings', -1),
              _Item(Icons.bar_chart_outlined, 'Metrics', -1),
            ]),

            const Divider(color: Color(0xFF222222)),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF666666), size: 20),
              title: const Text('Sign Out', style: TextStyle(color: Color(0xFF666666), fontSize: 14)),
              onTap: onLogout,
              dense: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _Section(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF555555), fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ),
      ...items,
    ]);
  }

  Widget _Item(IconData icon, String label, int index) {
    final isActive = index == currentIndex && index >= 0;
    final isAvailable = index >= 0;
    return ListTile(
      dense: true,
      leading: Icon(icon,
        color: isActive ? kPrimary : isAvailable ? const Color(0xFFAAAAAA) : const Color(0xFF444444),
        size: 18),
      title: Text(label, style: TextStyle(
        color: isActive ? kPrimary : isAvailable ? Colors.white : const Color(0xFF444444),
        fontSize: 14,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
      )),
      trailing: !isAvailable
          ? const Text('Soon', style: TextStyle(color: Color(0xFF444444), fontSize: 10))
          : null,
      onTap: isAvailable ? () => onSelect(index) : null,
    );
  }
}
