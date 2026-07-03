import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class MorningScreen extends StatefulWidget {
  const MorningScreen({super.key});
  @override State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  Map<String, dynamic> _brief = {};
  Map<String, dynamic> _dashboard = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppProvider>().api;
      final brief = await api.getMorningData();
      Map<String, dynamic> dashboard = {};
      try {
        dashboard = await api.getDashboard();
      } catch (e) {
        debugPrint('Dashboard error: $e');
      }
      debugPrint('Dashboard keys: ${dashboard.keys.toList()}');
      debugPrint('New hires: ${dashboard['new_hires']}');
      setState(() {
        _brief = brief;
        _dashboard = dashboard;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      backgroundColor: kBackground,
      body: RefreshIndicator(
        onRefresh: _load,
        color: kPrimary,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: kSurface,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting, style: const TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w400)),
              Text(DateFormat('EEEE, MMMM d').format(now),
                  style: const TextStyle(fontSize: 17, color: kTextDark, fontWeight: FontWeight.w700)),
            ]),
            actions: [
              IconButton(icon: const Icon(Icons.refresh, color: kTextMuted), onPressed: _load),
            ],
          ),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kPrimary)))
          else if (_error != null)
            SliverFillRemaining(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: const TextStyle(color: kTextMuted)),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            )))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate([
                // Sales strip
                _SalesStrip(data: _brief['sales']),
                const SizedBox(height: 12),

                // Action items — the meat of the dashboard
                _ActionSection(
                  title: 'New Hire Applications',
                  icon: Icons.person_add_outlined,
                  color: kSuccess,
                  items: (_dashboard['new_hires'] as List? ?? []).cast<Map<String,dynamic>>(),
                  counts: (_dashboard['hire_counts'] as Map?)?.cast<String,dynamic>(),
                  emptyText: 'No new applications',
                  builder: (item) => _HireCard(item: item, onRefresh: _load),
                ),
                const SizedBox(height: 12),

                _ActionSection(
                  title: 'Vendor Requests',
                  icon: Icons.storefront_outlined,
                  color: kWarning,
                  items: (_dashboard['new_vendors'] as List? ?? []).cast<Map<String,dynamic>>(),
                  emptyText: 'No new vendor requests',
                  builder: (item) => _VendorCard(item: item, onRefresh: _load),
                ),
                const SizedBox(height: 12),

                _ActionSection(
                  title: 'New Voicemails',
                  icon: Icons.voicemail,
                  color: kPrimary,
                  items: (_dashboard['voicemails'] as List? ?? []).cast<Map<String,dynamic>>(),
                  emptyText: 'No new voicemails',
                  builder: (item) => _VoicemailCard(item: item, onRefresh: _load),
                ),
                const SizedBox(height: 12),

                _ActionSection(
                  title: 'Rental Requests',
                  icon: Icons.home_work_outlined,
                  color: Color(0xFF6B4FBB),
                  items: (_dashboard['new_rentals'] as List? ?? []).cast<Map<String,dynamic>>(),
                  counts: (_dashboard['rental_counts'] as Map?)?.cast<String,dynamic>(),
                  emptyText: 'No new rental requests',
                  builder: (item) => _RentalCard(item: item, onRefresh: _load),
                ),
                const SizedBox(height: 12),

                // Upcoming events
                if ((_brief['upcoming_events'] as List? ?? []).isNotEmpty)
                  _UpcomingEvents(events: (_brief['upcoming_events'] as List).cast<Map<String,dynamic>>()),

                const SizedBox(height: 32),
              ])),
            ),
        ]),
      ),
    );
  }
}

// ── Sales strip ───────────────────────────────────────────────────────────────

class _SalesStrip extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _SalesStrip({this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null || data!['available'] != true) return const SizedBox.shrink();
    final gross = (data!['gross'] ?? 0).toDouble();
    final count = data!['order_count'] ?? 0;

    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: _Mini(label: "Yesterday's Revenue",
            value: '\$${gross.toStringAsFixed(0)}', color: kSuccess)),
        Container(width: 1, height: 40, color: kBorder),
        Expanded(child: _Mini(label: 'Orders', value: '$count', color: kPrimary)),
        Container(width: 1, height: 40, color: kBorder),
        Expanded(child: _Mini(label: 'Avg Order',
            value: count > 0 ? '\$${(gross/count).toStringAsFixed(0)}' : '-', color: kTextMuted)),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Mini({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted), textAlign: TextAlign.center),
  ]);
}

// ── Action section ────────────────────────────────────────────────────────────

class _ActionSection extends StatelessWidget {
  final String title, emptyText;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? counts;
  final Widget Function(Map<String, dynamic>) builder;

  const _ActionSection({
    required this.title, required this.icon, required this.color,
    required this.items, required this.emptyText, required this.builder,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextDark)),
            const Spacer(),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text('${items.length} new', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        // Status count pills
        if (counts != null && counts!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(spacing: 6, children: counts!.entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Text('${e.key}: ${e.value}',
                style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            )).toList()),
          ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(emptyText, style: const TextStyle(fontSize: 13, color: kTextMuted)),
          )
        else
          ...items.map((item) => Column(children: [
            const Divider(height: 1, indent: 16),
            builder(item),
          ])),
      ]),
    );
  }
}

// ── Hire card ─────────────────────────────────────────────────────────────────

class _HireCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;
  const _HireCard({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        CircleAvatar(backgroundColor: kSuccess.withOpacity(0.1), radius: 18,
          child: Text((item['name'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (item['position'] != null)
            Text(item['position'], style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ])),
        _ActionButtons(
          onApprove: () => _updateStatus(context, 'approved'),
          onDecline: () => _updateStatus(context, 'rejected'),
          approveLabel: 'Interview',
          declineLabel: 'Pass',
        ),
      ]),
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    await context.read<AppProvider>().api.updateHireStatus(item['id'], status);
    onRefresh();
  }
}

// ── Vendor card ───────────────────────────────────────────────────────────────

class _VendorCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;
  const _VendorCard({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: kWarning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.storefront, color: kWarning, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['business_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (item['contact_name'] != null)
            Text(item['contact_name'], style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ])),
        _ActionButtons(
          onApprove: () => _updateStatus(context, 'approved'),
          onDecline: () => _updateStatus(context, 'rejected'),
        ),
      ]),
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    await context.read<AppProvider>().api.updateVendorStatus(item['id'], status);
    onRefresh();
  }
}

// ── Voicemail card ────────────────────────────────────────────────────────────

class _VoicemailCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;
  const _VoicemailCard({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final durSecs = item['duration_seconds'] as int?;
    final duration = durSecs != null ? '${durSecs ~/ 60}:${(durSecs % 60).toString().padLeft(2,'0')}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.voicemail, color: kPrimary, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['caller_name'] ?? item['from_number'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (item['summary'] != null)
            Text(item['summary'], style: const TextStyle(fontSize: 12, color: kTextMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          if (duration.isNotEmpty)
            Text(duration, style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ])),
        TextButton(
          onPressed: () => _markHandled(context),
          child: const Text('Done', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Future<void> _markHandled(BuildContext context) async {
    await context.read<AppProvider>().api.markVoicemailHandled(item['id']);
    onRefresh();
  }
}

// ── Rental card ───────────────────────────────────────────────────────────────

class _RentalCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;
  const _RentalCard({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFF6B4FBB).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.home_work, color: Color(0xFF6B4FBB), size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['contact_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${item['event_type'] ?? ''} · ${item['guest_count'] ?? '?'} guests',
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
          if (item['event_date'] != null)
            Text(_formatDate(item['event_date']), style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ])),
        const Icon(Icons.chevron_right, color: kBorder, size: 18),
      ]),
    );
  }
}

// ── Upcoming events ───────────────────────────────────────────────────────────

class _UpcomingEvents extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  const _UpcomingEvents({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.event, size: 16, color: kPrimary),
            SizedBox(width: 8),
            Text('This Week', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        ...events.map((e) => Column(children: [
          const Divider(height: 1, indent: 16),
          ListTile(
            dense: true,
            title: Text(e['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: e['starts_at'] != null
                ? Text(_formatDate(e['starts_at']), style: const TextStyle(fontSize: 12, color: kTextMuted))
                : null,
            trailing: const Icon(Icons.chevron_right, color: kBorder, size: 18),
          ),
        ])),
      ]),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onApprove, onDecline;
  final String approveLabel, declineLabel;
  const _ActionButtons({
    required this.onApprove, required this.onDecline,
    this.approveLabel = 'Approve', this.declineLabel = 'Decline',
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton(
        onPressed: onDecline,
        style: TextButton.styleFrom(foregroundColor: kError, padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: Text(declineLabel, style: const TextStyle(fontSize: 12)),
      ),
      ElevatedButton(
        onPressed: onApprove,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text(approveLabel),
      ),
    ]);
  }
}

String _formatDate(dynamic val) {
  if (val == null) return '';
  try {
    final dt = DateTime.parse(val.toString()).toLocal();
    return DateFormat('MMM d').format(dt);
  } catch (_) { return val.toString(); }
}
