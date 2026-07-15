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
  const NovaBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NovaDestination selected;
  final ValueChanged<NovaDestination> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selected.index,
        onDestinationSelected: (index) =>
            onSelected(NovaDestination.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Operate',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Grow',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more),
            label: 'More',
          ),
        ],
      );
}

/// Preserves the readable legacy light palette until each feature screen is
/// migrated to semantic Theme/ColorScheme values. This avoids mixed dark/light
/// surfaces and unreadable text while allowing the new shell itself to support
/// dark mode safely.
class NovaLegacyThemeBoundary extends StatelessWidget {
  const NovaLegacyThemeBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
        data: buildAdminTheme(),
        child: ColoredBox(color: NovaColors.lightCanvas, child: child),
      );
}

class NovaAppShell extends StatefulWidget {
  const NovaAppShell({super.key});

  @override
  State<NovaAppShell> createState() => _NovaAppShellState();
}

class _NovaAppShellState extends State<NovaAppShell> {
  NovaDestination _selected = NovaDestination.today;

  late final Map<NovaDestination, GlobalKey<NavigatorState>> _navigatorKeys = {
    for (final destination in NovaDestination.values)
      destination: GlobalKey<NavigatorState>(),
  };

  void _selectDestination(NovaDestination destination) {
    if (destination == _selected) {
      _navigatorKeys[destination]
          ?.currentState
          ?.popUntil((route) => route.isFirst);
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
          body: IndexedStack(
            index: _selected.index,
            children: [
              _DestinationNavigator(
                navigatorKey: _navigatorKeys[NovaDestination.today]!,
                rootBuilder: (_) => const NovaLegacyThemeBoundary(
                  child: MorningScreen(),
                ),
              ),
              _DestinationNavigator(
                navigatorKey: _navigatorKeys[NovaDestination.inbox]!,
                rootBuilder: (_) => const NovaLegacyThemeBoundary(
                  child: InboxScreen(),
                ),
              ),
              _DestinationNavigator(
                navigatorKey: _navigatorKeys[NovaDestination.operate]!,
                rootBuilder: (_) => const _OperateHub(),
              ),
              _DestinationNavigator(
                navigatorKey: _navigatorKeys[NovaDestination.grow]!,
                rootBuilder: (_) => const _GrowHub(),
              ),
              _DestinationNavigator(
                navigatorKey: _navigatorKeys[NovaDestination.more]!,
                rootBuilder: (_) => const _MoreHub(),
              ),
            ],
          ),
          bottomNavigationBar: NovaBottomNavigation(
            selected: _selected,
            onSelected: _selectDestination,
          ),
        ),
      );
}

class _DestinationNavigator extends StatelessWidget {
  const _DestinationNavigator({
    required this.navigatorKey,
    required this.rootBuilder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder rootBuilder;

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: rootBuilder),
      );
}

class _ModuleDefinition {
  const _ModuleDefinition({
    required this.title,
    required this.icon,
    this.screenBuilder,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final WidgetBuilder? screenBuilder;
  final String? subtitle;

  bool get enabled => screenBuilder != null;
}

class _ModuleHub extends StatelessWidget {
  const _ModuleHub({
    required this.title,
    required this.subtitle,
    required this.modules,
  });

  final String title;
  final String subtitle;
  final List<_ModuleDefinition> modules;

  void _open(BuildContext context, _ModuleDefinition module) {
    final builder = module.screenBuilder;
    if (builder == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: module.title),
        builder: (context) => NovaLegacyThemeBoundary(
          child: builder(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: CustomScrollView(
          key: PageStorageKey<String>('hub-$title'),
          slivers: [
            SliverToBoxAdapter(
              child: NovaPageHeader(title: title, subtitle: subtitle),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                NovaSpacing.md,
                NovaSpacing.xs,
                NovaSpacing.md,
                NovaSpacing.xl,
              ),
              sliver: SliverList.list(
                children: [
                  NovaCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final module in modules)
                          NovaActionRow(
                            title: module.title,
                            subtitle: module.subtitle,
                            leading: Icon(module.icon),
                            enabled: module.enabled,
                            onTap: module.enabled
                                ? () => _open(context, module)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _OperateHub extends StatelessWidget {
  const _OperateHub();

  @override
  Widget build(BuildContext context) => _ModuleHub(
        title: 'Operate',
        subtitle: 'Events, guests, partners, and day-to-day operations',
        modules: [
          _ModuleDefinition(
            title: 'Events',
            icon: Icons.confirmation_num_outlined,
            screenBuilder: (_) => const EventsScreen(),
          ),
          _ModuleDefinition(
            title: 'Reservations',
            icon: Icons.table_bar_outlined,
            screenBuilder: (_) => const ReservationsScreen(),
          ),
          _ModuleDefinition(
            title: 'Rentals',
            icon: Icons.home_work_outlined,
            screenBuilder: (_) => const RentalsScreen(),
          ),
          _ModuleDefinition(
            title: 'Vendors',
            icon: Icons.storefront_outlined,
            screenBuilder: (_) => const VendorsScreen(),
          ),
          _ModuleDefinition(
            title: 'Hiring',
            icon: Icons.people_outline,
            screenBuilder: (_) => const HiringScreen(),
          ),
          _ModuleDefinition(
            title: 'Calendar',
            icon: Icons.calendar_month_outlined,
            screenBuilder: (_) => const CalendarScreen(),
          ),
          _ModuleDefinition(
            title: 'Wine Club',
            icon: Icons.wine_bar_outlined,
            screenBuilder: (_) => const WineClubScreen(),
          ),
          const _ModuleDefinition(
            title: 'Inventory',
            icon: Icons.inventory_2_outlined,
            subtitle: 'Coming soon',
          ),
        ],
      );
}

class _GrowHub extends StatelessWidget {
  const _GrowHub();

  @override
  Widget build(BuildContext context) => _ModuleHub(
        title: 'Grow',
        subtitle: 'Campaigns, communications, and guest growth',
        modules: [
          _ModuleDefinition(
            title: 'Marketing',
            icon: Icons.campaign_outlined,
            screenBuilder: (_) => const MarketingScreen(),
          ),
          _ModuleDefinition(
            title: 'Snap & Post',
            icon: Icons.camera_alt_outlined,
            screenBuilder: (_) => const MarketingScreen(),
          ),
          _ModuleDefinition(
            title: 'Chat Hub',
            icon: Icons.chat_outlined,
            screenBuilder: (_) => const ChatHubScreen(),
          ),
          _ModuleDefinition(
            title: 'Phone Assistant',
            icon: Icons.phone_outlined,
            screenBuilder: (_) => const PhoneScreen(),
          ),
          const _ModuleDefinition(
            title: 'Loyalty',
            icon: Icons.star_outline,
            subtitle: 'Coming soon',
          ),
          const _ModuleDefinition(
            title: 'Gift Cards',
            icon: Icons.card_giftcard_outlined,
            subtitle: 'Coming soon',
          ),
        ],
      );
}

class _MoreHub extends StatelessWidget {
  const _MoreHub();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return SafeArea(
      child: ListView(
        key: const PageStorageKey<String>('more-hub'),
        padding: const EdgeInsets.only(bottom: NovaSpacing.xl),
        children: [
          NovaPageHeader(title: 'More', subtitle: provider.tenantName),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NovaSectionHeader(title: 'Appearance'),
                const SizedBox(height: NovaSpacing.sm),
                const NovaCard(child: NovaAppearanceSelector()),
                const SizedBox(height: NovaSpacing.xl),
                NovaCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const NovaActionRow(
                        title: 'Settings',
                        subtitle: 'Coming soon',
                        leading: Icon(Icons.settings_outlined),
                        enabled: false,
                      ),
                      const NovaActionRow(
                        title: 'Staff Access',
                        subtitle: 'Coming soon',
                        leading: Icon(Icons.people_outlined),
                        enabled: false,
                      ),
                      const NovaActionRow(
                        title: 'Accounting',
                        subtitle: 'Coming soon',
                        leading: Icon(Icons.account_balance_outlined),
                        enabled: false,
                      ),
                      const NovaActionRow(
                        title: 'Displays',
                        subtitle: 'Coming soon',
                        leading: Icon(Icons.tv_outlined),
                        enabled: false,
                      ),
                      const NovaActionRow(
                        title: 'Support',
                        subtitle: 'Coming soon',
                        leading: Icon(Icons.help_outline),
                        enabled: false,
                      ),
                      NovaActionRow(
                        title: 'Sign out',
                        leading: const Icon(Icons.logout),
                        trailing: const SizedBox.shrink(),
                        onTap: () => NovaConfirmSheet.show(
                          context,
                          title: 'Sign out?',
                          message:
                              'You will need to sign in again to manage this venue.',
                          confirmLabel: 'Sign out',
                          destructive: true,
                        ).then((confirmed) {
                          if (confirmed && context.mounted) {
                            context.read<AppProvider>().forceLogout();
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
