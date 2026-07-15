import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});
  @override State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _status = 'pending';
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppProvider>().api.getVendors(_status);
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: ' + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = (_data['applications'] as List? ?? []).cast<Map<String, dynamic>>();
    final events = (_data['events'] as List? ?? []).cast<Map<String, dynamic>>();
    final counts = (_data['counts'] as Map<String, dynamic>? ?? {});
    return Column(children: [
      Container(color: kSurface, child: TabBar(
        controller: _tabs, labelColor: kPrimary, unselectedLabelColor: kTextMuted,
        indicatorColor: kPrimary,
        tabs: [
          Tab(text: 'Applications' + ((counts['pending'] ?? 0) > 0 ? ' (' + counts['pending'].toString() + ')' : '')),
          Tab(text: 'Events (' + events.length.toString() + ')'),
        ])),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: kPrimary))
        : TabBarView(controller: _tabs, children: [
            _appsTab(apps),
            _eventsTab(events),
          ])),
    ]);
  }

  Widget _appsTab(List<Map<String, dynamic>> apps) {
    return Column(children: [
      SizedBox(height: 52, child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final s in ['pending', 'approved', 'declined', 'all'])
            Padding(padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s[0].toUpperCase() + s.substring(1)),
                selected: _status == s, selectedColor: kPrimary,
                labelStyle: TextStyle(color: _status == s ? Colors.white : kTextDark,
                    fontWeight: FontWeight.w700, fontSize: 13),
                onSelected: (_) { setState(() => _status = s); _load(); })),
        ])),
      Expanded(child: apps.isEmpty
        ? const Center(child: Text('No vendor applications', style: TextStyle(color: kTextMuted)))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
            itemCount: apps.length,
            itemBuilder: (_, i) {
              final v = apps[i];
              final name = (v['business_name'] ?? v['name'] ?? 'Vendor').toString();
              final st = (v['status'] ?? 'pending').toString();
              // 2026-07-14 depth pass: the admin list API ships per-event
              // arrays (event_names / vae_statuses / vae_paid) — surface them
              // as chips instead of a single opaque line.
              final evNames = (v['event_names'] as List? ?? []);
              final evStatuses = (v['vae_statuses'] as List? ?? []);
              final evPaid = (v['vae_paid'] as List? ?? []);
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Material(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openDetail(v),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(name, style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5, color: kTextDark),
                              overflow: TextOverflow.ellipsis)),
                          if (st == 'pending') ...[
                            IconButton(visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.check_circle, color: kSuccess),
                                onPressed: () => _setStatus(v, 'approved')),
                            IconButton(visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.cancel, color: kError),
                                onPressed: () => _setStatus(v, 'declined')),
                          ] else
                            _chip(st, st == 'approved' ? kSuccess : (st == 'declined' ? kError : kTextMuted)),
                        ]),
                        Text((v['category'] ?? v['email'] ?? '').toString(),
                            style: const TextStyle(fontSize: 12, color: kTextMuted),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (evNames.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (var j = 0; j < evNames.length; j++)
                              if (evNames[j] != null)
                                _eventChip(
                                  evNames[j].toString(),
                                  j < evStatuses.length ? (evStatuses[j] ?? 'pending').toString() : 'pending',
                                  j < evPaid.length && evPaid[j] == true,
                                ),
                          ]),
                        ],
                      ]),
                    ),
                  ),
                ),
              );
            }))),
    ]);
  }

  Widget _eventsTab(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return const Center(child: Text('No vendor events', style: TextStyle(color: kTextMuted)));
    }
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(
      itemCount: events.length,
      itemBuilder: (_, i) {
        final e = events[i];
        final spots = (e['spots_available'] ?? e['spots'] ?? '').toString();
        final total = (e['total_spots'] ?? '').toString();
        return ListTile(
          leading: const Icon(Icons.event, color: kPrimary),
          title: Text((e['name'] ?? e['event_name'] ?? 'Event').toString(),
              style: const TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
          subtitle: Text(_fmt(e['event_date']) +
              (total.isNotEmpty ? '  -  ' + spots + '/' + total + ' spots open' : '')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('x' + (e['vendor_count'] ?? e['booked'] ?? 0).toString(),
                style: const TextStyle(fontWeight: FontWeight.w800, color: kTextDark)),
            const Icon(Icons.chevron_right, color: kTextMuted, size: 20),
          ]),
          onTap: () => _openRoster(e),
        );
      }));
  }

  Future<void> _setStatus(Map<String, dynamic> v, String status) async {
    final id = (v['id'] ?? v['party_id'] ?? '').toString();
    try {
      // Reuses the existing dashboard vendor status endpoint
      await context.read<AppProvider>().api.setVendorStatus(id, status);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vendor ' + status)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ' + e.toString())));
    }
  }

  void _openDetail(Map<String, dynamic> v) async {
    final pid = (v['party_id'] ?? v['id'] ?? '').toString();
    Map<String, dynamic> detail = v;
    List<Map<String, dynamic>> bookings = [];
    try {
      final res = await context.read<AppProvider>().api.getVendorDetail(pid);
      detail = (res['vendor'] as Map<String, dynamic>? ?? v);
      bookings = (res['bookings'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .6, maxChildSize: .92, expand: false,
        builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(20),
          children: [
            Text((detail['business_name'] ?? detail['name'] ?? 'Vendor').toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
            const SizedBox(height: 10),
            if (bookings.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(bottom: 6),
                child: Text('EVENTS', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: .8, color: kTextMuted))),
              for (final b in bookings)
                Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: Text(
                        (b['event_name'] ?? b['name'] ?? 'Event #' + (b['event_id'] ?? b['vendor_event_id'] ?? '?').toString()).toString(),
                        style: const TextStyle(fontSize: 13.5, color: kTextDark))),
                    if (b['payment_paid'] == true)
                      const Padding(padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.attach_money, size: 15, color: kSuccess)),
                    _chip((b['status'] ?? 'pending').toString(),
                        (b['status'] == 'approved' || b['status'] == 'confirmed') ? kSuccess
                        : b['status'] == 'declined' ? kError : kWarning),
                  ])),
              const Padding(padding: EdgeInsets.only(top: 4, bottom: 12),
                child: Text('Per-event approval and payment links: use the web review page.',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted, fontStyle: FontStyle.italic))),
            ],
            for (final k in ['name', 'email', 'phone', 'category', 'products',
                             'website', 'status', 'notes'])
              if ((detail[k] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 92, child: Text(k.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextMuted))),
                    Expanded(child: Text(detail[k].toString(),
                        style: const TextStyle(fontSize: 14, color: kTextDark))),
                  ])),
            const SizedBox(height: 20),
          ])),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _eventChip(String name, String status, bool paid) {
    final c = (status == 'approved' || status == 'confirmed') ? kSuccess
        : status == 'declined' ? kError : kWarning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
        if (paid) ...[
          const SizedBox(width: 3),
          Icon(Icons.attach_money, size: 11, color: c),
        ],
      ]),
    );
  }

  void _openRoster(Map<String, dynamic> e) async {
    final eid = (e['id'] ?? e['event_id'] ?? '').toString();
    if (eid.isEmpty) return;
    List<Map<String, dynamic>> roster = [];
    try {
      final res = await context.read<AppProvider>().api.getVendorEventRoster(eid);
      roster = (res['roster'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .55, maxChildSize: .92, expand: false,
        builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(20),
          children: [
            Text((e['name'] ?? e['event_name'] ?? 'Event').toString() + ' — roster',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark)),
            const SizedBox(height: 12),
            if (roster.isEmpty)
              const Text('No vendors booked yet.', style: TextStyle(color: kTextMuted))
            else
              for (final r in roster)
                Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((r['business_name'] ?? r['vendor_name'] ?? r['name'] ?? 'Vendor').toString(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark)),
                      if ((r['spot'] ?? r['spot_number'] ?? '').toString().isNotEmpty)
                        Text('Spot ' + (r['spot'] ?? r['spot_number']).toString(),
                            style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
                    ])),
                    if (r['payment_paid'] == true || r['paid'] == true)
                      const Padding(padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.attach_money, size: 15, color: kSuccess)),
                    _chip((r['status'] ?? 'pending').toString(),
                        (r['status'] == 'approved' || r['status'] == 'confirmed') ? kSuccess
                        : r['status'] == 'declined' ? kError : kWarning),
                  ])),
            const SizedBox(height: 16),
          ])),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(v.toString())); }
    catch (_) { return v.toString(); }
  }
}
