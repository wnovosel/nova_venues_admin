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
              return ListTile(
                leading: CircleAvatar(backgroundColor: kWarning.withOpacity(.12),
                    child: const Icon(Icons.storefront, color: kWarning, size: 20)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
                subtitle: Text((v['event_name'] ?? v['category'] ?? v['email'] ?? '').toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: st == 'pending'
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.check_circle, color: kSuccess),
                          onPressed: () => _setStatus(v, 'approved')),
                      IconButton(icon: const Icon(Icons.cancel, color: kError),
                          onPressed: () => _setStatus(v, 'declined')),
                    ])
                  : Text(st.toUpperCase(), style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: kTextMuted)),
                onTap: () => _openDetail(v),
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
          trailing: Text('x' + (e['vendor_count'] ?? e['booked'] ?? 0).toString(),
              style: const TextStyle(fontWeight: FontWeight.w800, color: kTextDark)),
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
    try {
      final res = await context.read<AppProvider>().api.getVendorDetail(pid);
      detail = (res['vendor'] as Map<String, dynamic>? ?? v);
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
            for (final k in ['name', 'email', 'phone', 'category', 'products',
                             'website', 'status', 'event_name', 'notes'])
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

  String _fmt(dynamic v) {
    if (v == null) return '';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(v.toString())); }
    catch (_) { return v.toString(); }
  }
}
