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
      final brief = await api.getMorningData();
      Map<String, dynamic> dashboard = {};
      try {
        dashboard = await api.getDashboard();
      } catch (error) {
        debugPrint('Dashboard error: $error');
      }
      if (!mounted) return;
      setState(() {
        _brief = brief;
        _dashboard = dashboard;
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
      (_dashboard[key] as List? ?? const []).cast<Map<String, dynamic>>();

  int get _attentionCount =>
      _list('new_hires').length +
      _list('new_vendors').length +
      _list('voicemails').length +
      _list('new_rentals').length +
      (_brief['system_alerts'] as List? ?? const []).length;

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
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 44, color: scheme.error),
                        const SizedBox(height: 12),
                        Text('Could not load the company pulse',
                            style: theme.textTheme.titleMedium),
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
                        .cast<Map<String, dynamic>>()
                        .map((alert) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SystemAlert(alert: alert),
                            ))),
                    _PulseMetrics(
                      sales: (_brief['sales'] as Map?)?.cast<String, dynamic>(),
                      events: (_brief['upcoming_events'] as List? ?? const []).length,
                      attention: _attentionCount,
                      dashboard: _dashboard,
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
                        emptyText: 'No new rental requests',
                        builder: (item) =>
                            _RentalCard(item: item, onRefresh: _load),
                      ),
                      const SizedBox(height: 10),
                      _ActionSection(
                        title: 'Vendor requests',
                        icon: Icons.storefront_outlined,
                        color: kWarning,
                        items: _list('new_vendors'),
                        emptyText: 'No new vendor requests',
                        builder: (item) =>
                            _VendorCard(item: item, onRefresh: _load),
                      ),
                      const SizedBox(height: 10),
                      _ActionSection(
                        title: 'New voicemails',
                        icon: Icons.voicemail_rounded,
                        color: scheme.primary,
                        items: _list('voicemails'),
                        emptyText: 'No new voicemails',
                        builder: (item) =>
                            _VoicemailCard(item: item, onRefresh: _load),
                      ),
                      const SizedBox(height: 10),
                      _ActionSection(
                        title: 'Hire applications',
                        icon: Icons.person_add_alt_1_rounded,
                        color: kSuccess,
                        items: _list('new_hires'),
                        emptyText: 'No new applications',
                        builder: (item) =>
                            _HireCard(item: item, onRefresh: _load),
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _SectionHeading(
                      title: 'Coming up',
                      subtitle: 'The next events on the company calendar.',
                      icon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(height: 10),
                    _UpcomingEvents(
                      events: (_brief['upcoming_events'] as List? ?? const [])
                          .cast<Map<String, dynamic>>(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulseHero extends StatelessWidget {
  const _PulseHero({
    required this.greeting,
    required this.date,
    required this.tenantName,
    required this.attentionCount,
  });

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
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, .74)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -28,
            child: Icon(Icons.monitor_heart_rounded,
                size: 132, color: scheme.onPrimary.withValues(alpha: .09)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: .72),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 7),
              Text('The pulse of $tenantName',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 5),
              Text(date,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: .78),
                  )),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(clear ? Icons.check_circle : Icons.bolt_rounded,
                        size: 18, color: scheme.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      clear
                          ? 'Everything is running smoothly'
                          : '$attentionCount items need attention',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
  const _PulseMetrics({
    required this.sales,
    required this.events,
    required this.attention,
    required this.dashboard,
  });

  final Map<String, dynamic>? sales;
  final int events;
  final int attention;
  final Map<String, dynamic> dashboard;

  @override
  Widget build(BuildContext context) {
    final gross = (sales?['gross'] ?? 0).toDouble();
    final orders = sales?['order_count'] ?? 0;
    final metrics = [
      ('Revenue', sales?['available'] == true ? '\$${gross.toStringAsFixed(0)}' : '—', Icons.payments_outlined),
      ('Orders', '$orders', Icons.receipt_long_outlined),
      ('Upcoming', '$events', Icons.event_outlined),
      ('Open items', '$attention', Icons.pending_actions_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
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
                Icon(metric.$3, size: 20,
                    color: Theme.of(context).colorScheme.primary),
                Text(metric.$2,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                Text(metric.$1,
                    style: Theme.of(context).textTheme.bodySmall),
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
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
          title: Text('${alert['source'] ?? 'System'} alert',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${alert['message'] ?? ''}', maxLines: 2,
              overflow: TextOverflow.ellipsis),
          trailing: Text('×${alert['count'] ?? 1}',
              style: const TextStyle(color: kError, fontWeight: FontWeight.w800)),
        ),
      );
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kSuccess.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.check_rounded, color: kSuccess),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You are all caught up',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('There are no approvals, calls, or requests waiting.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyText,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${items.length}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          ...items.map((item) => Column(
                children: [
                  const Divider(height: 1),
                  builder(item),
                ],
              )),
        ],
      ),
    );
  }
}

class _HireCard extends StatelessWidget {
  const _HireCard({required this.item, required this.onRefresh});
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: kSuccess.withValues(alpha: .12),
              child: Text('${item['name'] ?? '?'}'[0].toUpperCase(),
                  style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (item['position'] != null)
                    Text('${item['position']}',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(onPressed: () => _update(context, 'rejected'), child: const Text('Pass')),
            FilledButton(onPressed: () => _update(context, 'approved'), child: const Text('Interview')),
          ],
        ),
      );

  Future<void> _update(BuildContext context, String status) async {
    await context.read<AppProvider>().api.updateHireStatus(item['id'], status);
    onRefresh();
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.item, required this.onRefresh});
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_rounded, color: kWarning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['business_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (item['event_name'] != null)
                        Text('For ${item['event_name']}',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                TextButton(onPressed: () => _update(context, 'rejected'), child: const Text('Decline')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => _update(context, 'approved'), child: const Text('Approve')),
              ],
            ),
          ],
        ),
      );

  Future<void> _update(BuildContext context, String status) async {
    await context.read<AppProvider>().api.updateVendorStatus(item['id'], status);
    onRefresh();
  }
}

class _VoicemailCard extends StatelessWidget {
  const _VoicemailCard({required this.item, required this.onRefresh});
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.voicemail_rounded)),
        title: Text(item['caller_name'] ?? item['from_number'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: item['summary'] == null
            ? null
            : Text('${item['summary']}', maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          onPressed: () async {
            await context.read<AppProvider>().api.markVoicemailHandled(item['id']);
            onRefresh();
          },
          child: const Text('Done'),
        ),
      );
}

class _RentalCard extends StatelessWidget {
  const _RentalCard({required this.item, required this.onRefresh});
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.home_work_outlined)),
        title: Text(item['contact_name'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${item['event_type'] ?? 'Rental'} · ${item['guest_count'] ?? '?'} guests${item['event_date'] == null ? '' : ' · ${_formatDate(item['event_date'])}'}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({required this.events});
  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('No upcoming events are scheduled.'),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: events.take(6).map((event) => Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.event_rounded),
                  ),
                  title: Text(event['title'] ?? 'Event',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: event['starts_at'] == null
                      ? null
                      : Text(_formatDate(event['starts_at'])),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                if (event != events.take(6).last) const Divider(height: 1),
              ],
            )).toList(),
      ),
    );
  }
}

String _formatDate(dynamic value) {
  if (value == null) return '';
  try {
    final date = DateTime.parse(value.toString()).toLocal();
    return DateFormat('MMM d').format(date);
  } catch (_) {
    return value.toString();
  }
}
