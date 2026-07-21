import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_provider.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/chathub/chathub_screen.dart';
import '../screens/events/events_screen.dart';
import '../screens/hiring/hiring_screen.dart';
import '../screens/inbox/inbox_screen.dart';
import '../screens/marketing/marketing_screen.dart';
import '../screens/morning/morning_screen.dart';
import '../screens/phone/phone_screen.dart';
import '../screens/rentals/rentals_screen.dart';
import '../screens/reservations/reservations_screen.dart';
import '../screens/vendors/vendors_screen.dart';
import '../screens/wineclub/wineclub_screen.dart';
import '../theme/app_theme.dart';
import 'nova_components.dart';

enum NovaDestination { today, inbox, operate, grow, more }

class NovaBottomNavigation extends StatelessWidget {
  const NovaBottomNavigation({super.key, required this.selected, required this.onSelected});

  final NovaDestination selected;
  final ValueChanged<NovaDestination> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: NavigationBar(
          selectedIndex: selected.index,
          onDestinationSelected: (index) => onSelected(NovaDestination.values[index]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: 'Inbox'),
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.dashboard_customize_rounded), label: 'Operate'),
            NavigationDestination(icon: Icon(Icons.rocket_launch_outlined), selectedIcon: Icon(Icons.rocket_launch_rounded), label: 'Grow'),
            NavigationDestination(icon: Icon(Icons.tune_rounded), selectedIcon: Icon(Icons.tune), label: 'More'),
          ],
        ),
      ),
    ),
  );
}

class NovaLegacyThemeBoundary extends StatelessWidget {
  const NovaLegacyThemeBoundary({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(data: buildAdminTheme(), child: ColoredBox(color: NovaColors.lightCanvas, child: child));
}

class NovaAppShell extends StatefulWidget {
  const NovaAppShell({super.key});

  @override
  State<NovaAppShell> createState() => _NovaAppShellState();
}

class _NovaAppShellState extends State<NovaAppShell> {
  NovaDestination _selected = NovaDestination.today;
  late final Map<NovaDestination, GlobalKey<NavigatorState>> _navigatorKeys = {
    for (final destination in NovaDestination.values) destination: GlobalKey<NavigatorState>(),
  };

  void _selectDestination(NovaDestination destination) {
    HapticFeedback.selectionClick();
    if (destination == _selected) {
      _navigatorKeys[destination]?.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _selected = destination);
  }

  Future<void> _handleSystemBack() async {
    final navigator = _navigatorKeys[_selected]?.currentState;
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
      return;
    }
    if (_selected != NovaDestination.today) {
      setState(() => _selected = NovaDestination.today);
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _handleSystemBack();
    },
    child: Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selected.index,
        children: [
          _DestinationNavigator(navigatorKey: _navigatorKeys[NovaDestination.today]!, rootBuilder: (_) => const NovaLegacyThemeBoundary(child: MorningScreen())),
          _DestinationNavigator(navigatorKey: _navigatorKeys[NovaDestination.inbox]!, rootBuilder: (_) => const NovaLegacyThemeBoundary(child: InboxScreen())),
          _DestinationNavigator(navigatorKey: _navigatorKeys[NovaDestination.operate]!, rootBuilder: (_) => const _OperateHub()),
          _DestinationNavigator(navigatorKey: _navigatorKeys[NovaDestination.grow]!, rootBuilder: (_) => const _GrowHub()),
          _DestinationNavigator(navigatorKey: _navigatorKeys[NovaDestination.more]!, rootBuilder: (_) => const _MoreHub()),
        ],
      ),
      bottomNavigationBar: NovaBottomNavigation(selected: _selected, onSelected: _selectDestination),
    ),
  );
}

class _DestinationNavigator extends StatelessWidget {
  const _DestinationNavigator({required this.navigatorKey, required this.rootBuilder});
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder rootBuilder;

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: rootBuilder),
  );
}

class _ModuleDefinition {
  const _ModuleDefinition({required this.title, required this.icon, this.screenBuilder, this.subtitle, this.accent});
  final String title;
  final IconData icon;
  final WidgetBuilder? screenBuilder;
  final String? subtitle;
  final Color? accent;
  bool get enabled => screenBuilder != null;
}

class _ModuleHub extends StatelessWidget {
  const _ModuleHub({required this.title, required this.subtitle, required this.modules, required this.eyebrow, required this.accent});

  final String title;
  final String subtitle;
  final String eyebrow;
  final Color accent;
  final List<_ModuleDefinition> modules;

  void _open(BuildContext context, _ModuleDefinition module) {
    final builder = module.screenBuilder;
    if (builder == null) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: module.title),
        builder: (context) => NovaLegacyThemeBoundary(child: builder(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: PageStorageKey<String>('hub-$title'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [accent, Color.lerp(accent, NovaColors.plum, .72)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: .26), blurRadius: 30, offset: const Offset(0, 16))],
                ),
                child: Stack(
                  children: [
                    Positioned(right: -22, top: -28, child: Icon(title == 'Operate' ? Icons.dashboard_customize_rounded : Icons.rocket_launch_rounded, size: 128, color: Colors.white.withValues(alpha: .10))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(eyebrow.toUpperCase(), style: NovaTypography.label.copyWith(color: Colors.white.withValues(alpha: .72), letterSpacing: 1.4)),
                        const SizedBox(height: 8),
                        Text(title, style: NovaTypography.display.copyWith(color: Colors.white, fontSize: 34)),
                        const SizedBox(height: 8),
                        Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: .82))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 118),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: .98,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final module = modules[index];
                  final moduleColor = module.accent ?? accent;
                  return _ModuleCard(
                    module: module,
                    color: moduleColor,
                    onTap: module.enabled ? () => _open(context, module) : null,
                  );
                },
                childCount: modules.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.color, this.onTap});
  final _ModuleDefinition module;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color.withValues(alpha: .22), color.withValues(alpha: .10)]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(module.icon, color: color),
                  ),
                  const Spacer(),
                  Icon(module.enabled ? Icons.arrow_outward_rounded : Icons.lock_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const Spacer(),
              Text(module.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(module.subtitle ?? (module.enabled ? 'Open workspace' : 'Coming soon'), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperateHub extends StatelessWidget {
  const _OperateHub();
  @override
  Widget build(BuildContext context) => _ModuleHub(
    title: 'Operate',
    eyebrow: 'Run the day',
    subtitle: 'Everything you need to keep the venue moving.',
    accent: NovaColors.burgundy,
    modules: [
      _ModuleDefinition(title: 'Events', icon: Icons.confirmation_num_outlined, accent: NovaColors.burgundy, screenBuilder: (_) => const EventsScreen()),
      _ModuleDefinition(title: 'Reservations', icon: Icons.table_bar_outlined, accent: NovaColors.information, screenBuilder: (_) => const ReservationsScreen()),
      _ModuleDefinition(title: 'Rentals', icon: Icons.home_work_outlined, accent: const Color(0xFF7255B8), screenBuilder: (_) => const RentalsScreen()),
      _ModuleDefinition(title: 'Vendors', icon: Icons.storefront_outlined, accent: NovaColors.warning, screenBuilder: (_) => const VendorsScreen()),
      _ModuleDefinition(title: 'Hiring', icon: Icons.people_outline, accent: NovaColors.success, screenBuilder: (_) => const HiringScreen()),
      _ModuleDefinition(title: 'Calendar', icon: Icons.calendar_month_outlined, accent: NovaColors.information, screenBuilder: (_) => const CalendarScreen()),
      _ModuleDefinition(title: 'Wine Club', icon: Icons.wine_bar_outlined, accent: NovaColors.burgundyDark, screenBuilder: (_) => const WineClubScreen()),
      const _ModuleDefinition(title: 'Inventory', icon: Icons.inventory_2_outlined, subtitle: 'In development'),
    ],
  );
}

class _GrowHub extends StatelessWidget {
  const _GrowHub();
  @override
  Widget build(BuildContext context) => _ModuleHub(
    title: 'Grow',
    eyebrow: 'Build demand',
    subtitle: 'Create content, answer guests, and turn attention into visits.',
    accent: const Color(0xFF5B3BA3),
    modules: [
      _ModuleDefinition(title: 'Marketing', icon: Icons.campaign_outlined, accent: NovaColors.burgundy, screenBuilder: (_) => const MarketingScreen()),
      _ModuleDefinition(title: 'Snap & Post', icon: Icons.camera_alt_outlined, accent: const Color(0xFFE45D7B), screenBuilder: (_) => const MarketingScreen()),
      _ModuleDefinition(title: 'Chat Hub', icon: Icons.chat_outlined, accent: NovaColors.information, screenBuilder: (_) => const ChatHubScreen()),
      _ModuleDefinition(title: 'Phone Assistant', icon: Icons.phone_outlined, accent: NovaColors.success, screenBuilder: (_) => const PhoneScreen()),
      const _ModuleDefinition(title: 'Loyalty', icon: Icons.star_outline, subtitle: 'In development'),
      const _ModuleDefinition(title: 'Gift Cards', icon: Icons.card_giftcard_outlined, subtitle: 'In development'),
    ],
  );
}

class _MoreHub extends StatelessWidget {
  const _MoreHub();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey<String>('more-hub'),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 118),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(colors: [NovaColors.plum, NovaColors.burgundy], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(
              children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.storefront_rounded, color: Colors.white)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(provider.tenantName, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 3),
                  Text('Venue settings & controls', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: .72))),
                ])),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const NovaSectionHeader(title: 'Appearance'),
          const SizedBox(height: 10),
          const NovaCard(child: NovaAppearanceSelector()),
          const SizedBox(height: 22),
          NovaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const NovaActionRow(title: 'Settings', subtitle: 'Coming soon', leading: Icon(Icons.settings_outlined), enabled: false),
                const NovaActionRow(title: 'Staff Access', subtitle: 'Coming soon', leading: Icon(Icons.people_outlined), enabled: false),
                const NovaActionRow(title: 'Accounting', subtitle: 'Coming soon', leading: Icon(Icons.account_balance_outlined), enabled: false),
                const NovaActionRow(title: 'Displays', subtitle: 'Coming soon', leading: Icon(Icons.tv_outlined), enabled: false),
                const NovaActionRow(title: 'Support', subtitle: 'Coming soon', leading: Icon(Icons.help_outline), enabled: false),
                NovaActionRow(
                  title: 'Sign out',
                  leading: const Icon(Icons.logout),
                  trailing: const SizedBox.shrink(),
                  onTap: () => NovaConfirmSheet.show(context, title: 'Sign out?', message: 'You will need to sign in again to manage this venue.', confirmLabel: 'Sign out', destructive: true).then((confirmed) {
                    if (confirmed && context.mounted) context.read<AppProvider>().forceLogout();
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
