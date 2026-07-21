import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

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

      final eventsResponse = results[2];
      final rawEvents = (eventsResponse['events'] as List? ?? const []);
      final now = DateTime.now();
      final upcoming = rawEvents
          .whereType<Map>()
          .map((event) => event.cast<String, dynamic>())
          .where((event) {
            final value = event['starts_at'];
            final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
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
      (_dashboard[key] as List? ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  int get _attentionCount =>
      _list('new_hires').length +
      _list('new_vendors').length +
      _list('voicemails').length +
      _list('new_rentals').length +
      (_brief['system_alerts'] as List? ?? const []).length;

  double get _revenue {
    final value = _brief['total_revenue_today'] ??
        _brief['revenue_today'] ??
        (_brief['sales'] is Map ? (_brief['sales'] as Map)['gross'] : null) ??
        0;
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  int get _orders {
    final value = _brief['orders_today'] ??
        (_brief['sales'] is Map ? (_brief['sales'] as Map)['order_count'] : null) ??
        0;
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text('Today', style: theme.textTheme.titleLarge),
              actions: [
                IconButton(
                  tooltip: 'Refresh pulse',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 44, color: scheme.error),
                        const SizedBox(height: 12),
                        Text('Could not load the company pulse', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList.list(
                  children: [
                    _PulseHero(
                      greeting: greeting,
                      date: DateFormat('EEEE, MMMM d').format(now),
                      tenantName: context.read<AppProvider>().tenantName,
                      attentionCount: _attentionCount,
                    ),
                    const SizedBox(height: 16),
                    ...((_brief['system_alerts'] as List? ?? const [])
                        .whereType<Map>()
                        .map((alert) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SystemAlert(alert: alert.cast<String, dynamic>()),
                            ))),
                    _PulseMetrics(
                      revenue: _revenue,
                      orders: _orders,
                      events: _events.length,
                      attention: _attentionCount,
                    ),
                    const SizedBox(height: 22),
                    _SectionHeading(
                      title: 'Needs your attention',
                      subtitle: _attentionCount == 0
                          ? 'Nothing urgent is waiting on you.'
                          : '$_attentionCount outstanding items across the company.',
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: 10),
                    if (_attentionCount == 0)
                      const _AllClearCard()
                    else ...[
                      _ActionSection(
                        title: 'Rental requests',
                        icon: Icons.home_work_outlined,
                        color: const Color(0xFF6B4FBB),
                        items: _list('new_rentals'),
                        onAction: _rentalAction,
                      ),
                      const SizedBox(height: 10),
                      _ActionSection(
                        title: 'Vendor requests',
                        icon: Icons.storefront_outlined,
                        color: kWarning,
                        items: _list('new_vendors'),
                        onAction: _vendorAction,
                      ),
                      const SizedBox(height: 10),
                      _ActionSection(
                        title: 'New voicemails',
                        icon: Icons.voicemail_rounded,
                        color: scheme.primary,
                        items: _list('voicemails'),
                        onAction: _voicemailAction,
                      ),
                      const SizedBox(height: 10),
                      _ActionSection(
                        title: 'Hire applications',
                        icon: Icons.person_add_alt_1_rounded,
                        color: kSuccess,
                        items: _list('new_hires'),
                        onAction: _hireAction,
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _SectionHeading(
                      title: 'Coming up',
                      subtitle: 'The next events on the company calendar.',
                      icon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(height: 10),
                    _UpcomingEvents(events: _events.take(6).toList()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _rentalAction(Map<String, dynamic> item, bool approve) async {
    final id = '${item['id']}';
    if (approve) {
      await context.read<AppProvider>().api.confirmRental(id);
    } else {
      await context.read<AppProvider>().api.declineRental(id);
    }
    await _load();
  }

  Future<void> _vendorAction(Map<String, dynamic> item, bool approve) async {
    await context.read<AppProvider>().api.updateVendorStatus(item['id'], approve ? 'approved' : 'rejected');
    await _load();
  }

  Future<void> _voicemailAction(Map<String, dynamic> item, bool approve) async {
    await context.read<AppProvider>().api.markVoicemailHandled(item['id'] ?? item['call_sid']);
    await _load();
  }

  Future<void> _hireAction(Map<String, dynamic> item, bool approve) async {
    await context.read<AppProvider>().api.updateHireStatus(item['id'], approve ? 'approved' : 'rejected');
    await _load();
  }
}

class _PulseHero extends StatelessWidget {
  const _PulseHero({required this.greeting, required this.date, required this.tenantName, required this.attentionCount});
  final String greeting;
  final String date;
  final String tenantName;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clear = attentionCount == 0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.secondary, .74)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .24), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -28, child: Icon(Icons.monitor_heart_rounded, size: 132, color: scheme.onPrimary.withValues(alpha: .09))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting.toUpperCase(), style: theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimary.withValues(alpha: .72), letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text('The pulse of $tenantName', style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(date, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimary.withValues(alpha: .78))),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: scheme.onPrimary.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(clear ? Icons.check_circle : Icons.bolt_rounded, size: 18, color: scheme.onPrimary),
                    const SizedBox(width: 8),
                    Text(clear ? 'Everything is running smoothly' : '$attentionCount items need attention', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseMetrics extends StatelessWidget {
  const _PulseMetrics({required this.revenue, required this.orders, required this.events, required this.attention});
  final double revenue;
  final int orders;
  final int events;
  final int attention;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Revenue', '\$${NumberFormat('#,##0').format(revenue)}', Icons.payments_outlined),
      ('Orders', '$orders', Icons.receipt_long_outlined),
      ('Upcoming', '$events', Icons.event_outlined),
      ('Open items', '$attention', Icons.pending_actions_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.65),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(metric.$3, size: 20, color: Theme.of(context).colorScheme.primary),
                Text(metric.$2, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                Text(metric.$1, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])),
        ],
      );
}

class _SystemAlert extends StatelessWidget {
  const _SystemAlert({required this.alert});
  final Map<String, dynamic> alert;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: kError),
          title: Text('${alert['source'] ?? 'System'} alert', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${alert['message'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text('×${alert['count'] ?? 1}', style: const TextStyle(color: kError, fontWeight: FontWeight.w800)),
        ),
      );
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.title, required this.icon, required this.color, required this.items, required this.onAction});
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic>, bool) onAction;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            trailing: CircleAvatar(radius: 15, backgroundColor: color.withValues(alpha: .12), child: Text('${items.length}', style: TextStyle(color: color, fontWeight: FontWeight.w800))),
          ),
          const Divider(height: 1),
          ...items.take(5).map((item) => _ActionRow(item: item, color: color, onAction: onAction)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item, required this.color, required this.onAction});
  final Map<String, dynamic> item;
  final Color color;
  final Future<void> Function(Map<String, dynamic>, bool) onAction;

  String get title => '${item['business_name'] ?? item['contact_name'] ?? item['name'] ?? item['from_number'] ?? item['caller'] ?? 'New item'}';
  String get subtitle => '${item['event_type'] ?? item['vendor_type'] ?? item['position'] ?? item['transcription'] ?? item['message'] ?? item['venue'] ?? ''}';

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(tooltip: 'Pass', onPressed: () => onAction(item, false), icon: const Icon(Icons.close_rounded)),
            IconButton(tooltip: 'Approve', onPressed: () => onAction(item, true), icon: Icon(Icons.check_rounded, color: color)),
          ],
        ),
      );
}

class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({required this.events});
  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No upcoming events found.')));
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: events.map((event) {
          final parsed = DateTime.tryParse('${event['starts_at']}')?.toLocal();
          final when = parsed == null ? '' : DateFormat('EEE, MMM d • h:mm a').format(parsed);
          return ListTile(
            leading: const Icon(Icons.event_rounded),
            title: Text('${event['title'] ?? 'Event'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([when, event['location']].where((value) => value != null && '$value'.isNotEmpty).join(' · ')),
            trailing: event['ticket_count'] == null ? null : Text('${event['ticket_count']} tickets'),
          );
        }).toList(),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              const Expanded(child: Text('You are all caught up. There are no outstanding items requiring action.')),
            ],
          ),
        ),
      );
}
