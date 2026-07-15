import 'package:flutter/material.dart';
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
    onDestinationSelected: (index) => onSelected(NovaDestination.values[index]),
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

class NovaAppShell extends StatefulWidget {
  const NovaAppShell({super.key});
  @override
  State<NovaAppShell> createState() => _NovaAppShellState();
}

class _NovaAppShellState extends State<NovaAppShell> {
  NovaDestination _destination = NovaDestination.today;
  Widget? _module;
  String? _moduleTitle;

  void _selectDestination(NovaDestination destination) {
    setState(() {
      _destination = destination;
      _module = null;
      _moduleTitle = null;
    });
  }

  void _openModule(NovaDestination parent, String title, Widget screen) {
    setState(() {
      _destination = parent;
      _moduleTitle = title;
      _module = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content =
        _module ??
        switch (_destination) {
          NovaDestination.today => const MorningScreen(),
          NovaDestination.inbox => const InboxScreen(),
          NovaDestination.operate => _OperateHub(onOpen: _openModule),
          NovaDestination.grow => _GrowHub(onOpen: _openModule),
          NovaDestination.more => const _MoreHub(),
        };
    return Scaffold(
      body: AnimatedSwitcher(
        duration: NovaMotion.standard,
        child: KeyedSubtree(
          key: ValueKey(_moduleTitle ?? _destination),
          child: content,
        ),
      ),
      bottomNavigationBar: NovaBottomNavigation(
        selected: _destination,
        onSelected: _selectDestination,
      ),
    );
  }
}

typedef _ModuleOpener =
    void Function(NovaDestination parent, String title, Widget screen);

class _Hub extends StatelessWidget {
  const _Hub({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: CustomScrollView(
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
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OperateHub extends StatelessWidget {
  const _OperateHub({required this.onOpen});
  final _ModuleOpener onOpen;
  @override
  Widget build(BuildContext context) => _Hub(
    title: 'Operate',
    subtitle: 'Events, guests, partners, and day-to-day operations',
    children: [
      NovaActionRow(
        title: 'Events',
        leading: const Icon(Icons.confirmation_num_outlined),
        onTap: () =>
            onOpen(NovaDestination.operate, 'Events', const EventsScreen()),
      ),
      NovaActionRow(
        title: 'Reservations',
        leading: const Icon(Icons.table_bar_outlined),
        onTap: () => onOpen(
          NovaDestination.operate,
          'Reservations',
          const ReservationsScreen(),
        ),
      ),
      NovaActionRow(
        title: 'Rentals',
        leading: const Icon(Icons.home_work_outlined),
        onTap: () =>
            onOpen(NovaDestination.operate, 'Rentals', const RentalsScreen()),
      ),
      NovaActionRow(
        title: 'Vendors',
        leading: const Icon(Icons.storefront_outlined),
        onTap: () =>
            onOpen(NovaDestination.operate, 'Vendors', const VendorsScreen()),
      ),
      NovaActionRow(
        title: 'Hiring',
        leading: const Icon(Icons.people_outline),
        onTap: () =>
            onOpen(NovaDestination.operate, 'Hiring', const HiringScreen()),
      ),
      NovaActionRow(
        title: 'Calendar',
        leading: const Icon(Icons.calendar_month_outlined),
        onTap: () =>
            onOpen(NovaDestination.operate, 'Calendar', const CalendarScreen()),
      ),
      NovaActionRow(
        title: 'Wine Club',
        leading: const Icon(Icons.wine_bar_outlined),
        onTap: () => onOpen(
          NovaDestination.operate,
          'Wine Club',
          const WineClubScreen(),
        ),
      ),
      const NovaActionRow(
        title: 'Inventory',
        subtitle: 'Coming soon',
        leading: Icon(Icons.inventory_2_outlined),
        enabled: false,
      ),
    ],
  );
}

class _GrowHub extends StatelessWidget {
  const _GrowHub({required this.onOpen});
  final _ModuleOpener onOpen;
  @override
  Widget build(BuildContext context) => _Hub(
    title: 'Grow',
    subtitle: 'Campaigns, communications, and guest growth',
    children: [
      NovaActionRow(
        title: 'Marketing',
        leading: const Icon(Icons.campaign_outlined),
        onTap: () =>
            onOpen(NovaDestination.grow, 'Marketing', const MarketingScreen()),
      ),
      NovaActionRow(
        title: 'Snap & Post',
        leading: const Icon(Icons.camera_alt_outlined),
        onTap: () => onOpen(
          NovaDestination.grow,
          'Snap & Post',
          const MarketingScreen(),
        ),
      ),
      NovaActionRow(
        title: 'Chat Hub',
        leading: const Icon(Icons.chat_outlined),
        onTap: () =>
            onOpen(NovaDestination.grow, 'Chat Hub', const ChatHubScreen()),
      ),
      NovaActionRow(
        title: 'Phone Assistant',
        leading: const Icon(Icons.phone_outlined),
        onTap: () => onOpen(
          NovaDestination.grow,
          'Phone Assistant',
          const PhoneScreen(),
        ),
      ),
      const NovaActionRow(
        title: 'Loyalty',
        subtitle: 'Coming soon',
        leading: Icon(Icons.star_outline),
        enabled: false,
      ),
      const NovaActionRow(
        title: 'Gift Cards',
        subtitle: 'Coming soon',
        leading: Icon(Icons.card_giftcard_outlined),
        enabled: false,
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
                        onTap: () =>
                            NovaConfirmSheet.show(
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
