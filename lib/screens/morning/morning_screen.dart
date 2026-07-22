import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';
import '../events/events_screen.dart';
import '../hiring/hiring_screen.dart';
import '../inbox/inbox_screen.dart';
import '../rentals/rentals_screen.dart';
import '../vendors/vendors_screen.dart';

class MorningScreen extends StatefulWidget {
  const MorningScreen({super.key});

  @override
  State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  Map<String, dynamic> _brief = {};
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppProvider>().api;
      final results = await Future.wait([
        api.getMorningData(),
        api.getDashboard().catchError((_) => <String, dynamic>{}),
        api.getEvents().catchError((_) => <String, dynamic>{}),
      ]);
      final now = DateTime.now();
      final upcoming = (results[2]['events'] as List? ?? const [])
          .whereType<Map>()
          .map((event) => event.cast<String, dynamic>())
          .where((event) {
            final date = DateTime.tryParse('${event['starts_at']}')?.toLocal();
            return date != null && !date.isBefore(now);
          })
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse('${a['starts_at']}') ?? DateTime(2100);
          final bd = DateTime.tryParse('${b['starts_at']}') ?? DateTime(2100);
          return ad.compareTo(bd);
        });
      if (!mounted) return;
      setState(() {
        _brief = results[0];
        _dashboard = results[1];
        _events = upcoming;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _list(String key) =>
      (_dashboard[key] as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();

  int get _attentionCount =>
      _list('new_hires').length +
      _list('new_vendors').length +
      _list('voicemails').length +
      _list('new_rentals').length +
      (_brief['system_alerts'] as List? ?? const []).length;

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  int _integer(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double get _revenue => _number(
        _brief['total_revenue_today'] ??
            _brief['revenue_today'] ??
            (_brief['sales'] is Map ? (_brief['sales'] as Map)['gross'] : null),
      );

  int get _orders => _integer(
        _brief['orders_today'] ??
            (_brief['sales'] is Map
                ? (_brief['sales'] as Map)['order_count']
                : null),
      );

  int get _ticketsToday => _integer(
        _brief['tickets_sold_today'] ??
            _brief['ticket_quantity_today'] ??
            _dashboard['tickets_sold_today'],
      );

  int get _eventsNextSevenDays {
    final cutoff = DateTime.now().add(const Duration(days: 7));
    return _events.where((event) {
      final date = DateTime.tryParse('${event['starts_at']}')?.toLocal();
      return date != null && date.isBefore(cutoff);
    }).length;
  }

  void _open(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _showQuickActions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where do you want to go?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Jump straight into the work that matters.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickAction(
                    label: 'Events',
                    icon: Icons.confirmation_num_outlined,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _open(const EventsScreen());
                    }),
                _QuickAction(
                    label: 'Rentals',
                    icon: Icons.home_work_outlined,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _open(const RentalsScreen());
                    }),
                _QuickAction(
                    label: 'Vendors',
                    icon: Icons.storefront_outlined,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _open(const VendorsScreen());
                    }),
                _QuickAction(
                    label: 'Hiring',
                    icon: Icons.person_add_alt_1_rounded,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _open(const HiringScreen());
                    }),
                _QuickAction(
                    label: 'Inbox',
                    icon: Icons.inbox_outlined,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _open(const InboxScreen());
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDataNotice(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickActions,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Nova'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text('Today', style: theme.textTheme.titleLarge),
              actions: [
                IconButton(
                  tooltip: 'Refresh company pulse',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 6),
              ],
            ),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                  child: _ErrorState(message: _error!, onRetry: _load))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                sliver: SliverList.list(
                  children: [
                    _CommandHero(
                      greeting: greeting,
                      date: DateFormat('EEEE, MMMM d').format(now),
                      tenantName: context.read<AppProvider>().tenantName,
                      attentionCount: _attentionCount,
                      nextEvent: _events.isEmpty ? null : _events.first,
                    ),
                    const SizedBox(height: 12),
                    _MetricGrid(
                      revenue: _revenue,
                      orders: _orders,
                      ticketsToday: _ticketsToday,
                      eventsNextSevenDays: _eventsNextSevenDays,
                      attention: _attentionCount,
                      onRevenue: () => _showDataNotice('Sales Today',
                          'This will open the live sales workspace when the shared web reporting route is connected.'),
                      onOrders: () => _showDataNotice('Orders Today',
                          'This will open today’s transaction list from the same reporting source as the website.'),
                      onTickets: () => _open(const EventsScreen()),
                      onEvents: () => _open(const EventsScreen()),
                      onAttention: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                              content: Text('Your open items are listed below.'))),
                    ),
                    ..._alerts(),
                    const SizedBox(height: 26),
                    _SectionHeader(
                      eyebrow: 'Action center',
                      title: 'Needs your attention',
                      subtitle: _attentionCount == 0
                          ? 'You are caught up. Nothing urgent is waiting.'
                          : '$_attentionCount items are waiting across the business.',
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: 12),
                    if (_attentionCount == 0)
                      const _AllClearCard()
                    else
                      _AttentionBoard(
                        rentals: _list('new_rentals'),
                        vendors: _list('new_vendors'),
                        voicemails: _list('voicemails'),
                        hires: _list('new_hires'),
                        onRentals: () => _open(const RentalsScreen()),
                        onVendors: () => _open(const VendorsScreen()),
                        onVoicemails: () => _open(const InboxScreen()),
                        onHires: () => _open(const HiringScreen()),
                      ),
                    const SizedBox(height: 28),
                    const _SectionHeader(
                      eyebrow: 'Next seven days',
                      title: 'Coming up',
                      subtitle:
                          'Events that can affect staffing, inventory, and guest flow.',
                      icon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(height: 12),
                    _UpcomingEvents(
                      events: _events.take(6).toList(),
                      onOpenAll: () => _open(const EventsScreen()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _alerts() {
    final alerts = (_brief['system_alerts'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (alerts.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      ...alerts.map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AlertCard(alert: alert),
          )),
    ];
  }
}

class _CommandHero extends StatelessWidget {
  const _CommandHero({
    required this.greeting,
    required this.date,
    required this.tenantName,
    required this.attentionCount,
    required this.nextEvent,
  });
  final String greeting;
  final String date;
  final String tenantName;
  final int attentionCount;
  final Map<String, dynamic>? nextEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nextDate = nextEvent == null
        ? null
        : DateTime.tryParse('${nextEvent!['starts_at']}')?.toLocal();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, .72)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .26),
            blurRadius: 32,
            offset: const Offset(0, 16),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -28,
            child: Icon(Icons.monitor_heart_rounded,
                size: 142, color: scheme.onPrimary.withValues(alpha: .09)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: .72),
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 7),
              Text('The pulse of $tenantName',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(date,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: .78))),
              const SizedBox(height: 22),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      attentionCount == 0
                          ? Icons.check_circle_rounded
                          : Icons.bolt_rounded,
                      size: 18,
                      color: scheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      attentionCount == 0
                          ? 'Everything is running smoothly'
                          : '$attentionCount items need attention',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (nextEvent != null && nextDate != null) ...[
                const SizedBox(height: 18),
                Divider(color: scheme.onPrimary.withValues(alpha: .18)),
                const SizedBox(height: 8),
                Text('NEXT ON THE CALENDAR',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: .66),
                        letterSpacing: 1.1)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('${nextEvent!['title'] ?? 'Upcoming event'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800)),
                    ),
                    Text(DateFormat('EEE, MMM d').format(nextDate),
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: scheme.onPrimary)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.revenue,
    required this.orders,
    required this.ticketsToday,
    required this.eventsNextSevenDays,
    required this.attention,
    required this.onRevenue,
    required this.onOrders,
    required this.onTickets,
    required this.onEvents,
    required this.onAttention,
  });
  final double revenue;
  final int orders;
  final int ticketsToday;
  final int eventsNextSevenDays;
  final int attention;
  final VoidCallback onRevenue;
  final VoidCallback onOrders;
  final VoidCallback onTickets;
  final VoidCallback onEvents;
  final VoidCallback onAttention;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData('Sales today', '\$${NumberFormat('#,##0').format(revenue)}',
          'Revenue since midnight', Icons.payments_outlined, onRevenue),
      _MetricData('Orders today', '$orders', 'Completed transactions',
          Icons.receipt_long_outlined, onOrders),
      _MetricData('Tickets today', '$ticketsToday', 'Sold since midnight',
          Icons.local_activity_outlined, onTickets),
      _MetricData('Next 7 days', '$eventsNextSevenDays', 'Scheduled events',
          Icons.event_available_outlined, onEvents),
      _MetricData('Open items', '$attention', 'Waiting for action',
          Icons.pending_actions_rounded, onAttention),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: identical(item, items.last)
                        ? constraints.maxWidth
                        : half,
                    child: _MetricCard(data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(
      this.label, this.value, this.detail, this.icon, this.onTap);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});
  final _MetricData data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, size: 19, color: scheme.primary),
                ),
                const Spacer(),
                Icon(Icons.arrow_outward_rounded,
                    size: 17, color: scheme.onSurfaceVariant),
              ]),
              const SizedBox(height: 14),
              Text(data.value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(height: 2),
              Text(data.label,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(data.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      );
}

class _AttentionBoard extends StatelessWidget {
  const _AttentionBoard({
    required this.rentals,
    required this.vendors,
    required this.voicemails,
    required this.hires,
    required this.onRentals,
    required this.onVendors,
    required this.onVoicemails,
    required this.onHires,
  });
  final List<Map<String, dynamic>> rentals;
  final List<Map<String, dynamic>> vendors;
  final List<Map<String, dynamic>> voicemails;
  final List<Map<String, dynamic>> hires;
  final VoidCallback onRentals;
  final VoidCallback onVendors;
  final VoidCallback onVoicemails;
  final VoidCallback onHires;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _AttentionData('Rental requests', rentals.length,
          Icons.home_work_outlined, onRentals),
      _AttentionData('Vendor applications', vendors.length,
          Icons.storefront_outlined, onVendors),
      _AttentionData('New voicemails', voicemails.length,
          Icons.voicemail_rounded, onVoicemails),
      _AttentionData('Hire applications', hires.length,
          Icons.person_add_alt_1_rounded, onHires),
    ].where((row) => row.count > 0).toList();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            ListTile(
              minTileHeight: 66,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(rows[index].icon,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(rows[index].label,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${rows[index].count} waiting for review'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(label: Text('${rows[index].count}')),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: rows[index].onTap,
            ),
            if (index != rows.length - 1)
              const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }
}

class _AttentionData {
  const _AttentionData(this.label, this.count, this.icon, this.onTap);
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
}

class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({required this.events, required this.onOpenAll});
  final List<Map<String, dynamic>> events;
  final VoidCallback onOpenAll;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            const Icon(Icons.event_available_outlined, size: 34),
            const SizedBox(height: 10),
            Text('No events in the next seven days',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Your full event calendar is available in Operate.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var index = 0; index < events.length; index++) ...[
          _EventRow(event: events[index], onTap: onOpenAll),
          if (index != events.length - 1)
            const Divider(height: 1, indent: 74),
        ],
        const Divider(height: 1),
        ListTile(
          title: const Text('View all events',
              style: TextStyle(fontWeight: FontWeight.w800)),
          trailing: const Icon(Icons.arrow_forward_rounded),
          onTap: onOpenAll,
        ),
      ]),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse('${event['starts_at']}')?.toLocal();
    final tickets = event['ticket_count'] ?? 0;
    return ListTile(
      minTileHeight: 76,
      leading: Container(
        width: 48,
        height: 52,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: date == null
            ? const Icon(Icons.event_outlined)
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(DateFormat('MMM').format(date).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900)),
                Text('${date.day}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ]),
      ),
      title: Text('${event['title'] ?? 'Upcoming event'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(date == null
          ? '${event['location'] ?? ''}'
          : '${DateFormat('EEE h:mm a').format(date)} • $tickets tickets'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 56) / 2,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
          ),
        ),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final Map<String, dynamic> alert;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: kError),
          title: Text('${alert['source'] ?? 'System'} alert',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${alert['message'] ?? ''}',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text('×${alert['count'] ?? 1}',
              style: const TextStyle(
                  color: kError, fontWeight: FontWeight.w800)),
        ),
      );
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: kSuccess.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.check_rounded, color: kSuccess),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are all caught up',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text('There are no outstanding items waiting for review.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded,
                size: 46, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 14),
            Text('Could not load the company pulse',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ]),
        ),
      );
}
