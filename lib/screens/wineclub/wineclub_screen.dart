import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class WineClubScreen extends StatefulWidget {
  const WineClubScreen({super.key});
  @override State<WineClubScreen> createState() => _WineClubScreenState();
}

class _WineClubScreenState extends State<WineClubScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppProvider>().api.getWineClub();
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kPrimary));
    final clubs = (_data['clubs'] as List? ?? []).cast<Map<String, dynamic>>();
    final members = (_data['members'] as List? ?? []).cast<Map<String, dynamic>>();
    final stats = (_data['stats'] as Map<String, dynamic>? ?? {});
    return RefreshIndicator(onRefresh: _load, child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _stat('Members', stats['total_members']),
          const SizedBox(width: 10),
          _stat('Ship', stats['ship_members']),
          const SizedBox(width: 10),
          _stat('Pickup', stats['pickup_members']),
        ]),
        const SizedBox(height: 18),
        const Text('CLUBS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
            color: kTextMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        for (final c in clubs) _clubCard(c),
        const SizedBox(height: 18),
        Text('MEMBERS (' + members.length.toString() + ')',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: kTextMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        for (final m in members.take(100)) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: kPrimary.withOpacity(.1),
              child: const Icon(Icons.wine_bar, color: kPrimary, size: 20)),
          title: Text((m['member_name'] ?? m['member_email'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w600, color: kTextDark)),
          subtitle: Text((m['club_name'] ?? '').toString() + '  -  ' +
              (m['fulfillment'] ?? '').toString() +
              ((m['card_last4'] ?? '').toString().isNotEmpty
                  ? '  -  ****' + m['card_last4'].toString() : '')),
          trailing: Text((m['status'] ?? '').toString().toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                  color: m['status'] == 'active' ? kSuccess : kTextMuted)),
        ),
      ],
    ));
  }

  Widget _stat(String label, dynamic v) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder)),
      child: Column(children: [
        Text((v ?? 0).toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kTextDark)),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

  Widget _clubCard(Map<String, dynamic> c) {
    final price = ((c['price_cents'] ?? 0) / 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text((c['name'] ?? 'Club').toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextDark))),
          Text('\$' + price + '/run', style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
        ]),
        if ((c['description'] ?? '').toString().isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4),
            child: Text(c['description'].toString(),
                style: const TextStyle(fontSize: 13, color: kTextMuted))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kPrimary),
          icon: const Icon(Icons.bolt, size: 18),
          label: const Text('Run club charge'),
          onPressed: () => _confirmRun(c),
        )),
      ]),
    );
  }

  Future<void> _confirmRun(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Run club charge?'),
      content: Text('This charges EVERY active member of "' +
          (c['name'] ?? '').toString() + '" their saved card. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: kError),
            onPressed: () => Navigator.pop(context, true), child: const Text('Charge members')),
      ],
    ));
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Running charges...')));
    try {
      final res = await context.read<AppProvider>().api.runClubCharge(c['id'] as int);
      _load();
      if (mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text('Club run complete'),
          content: Text('Charged: ' + (res['charged'] ?? 0).toString() +
              '\nFailed: ' + (res['failed'] ?? 0).toString() +
              '\nTotal: \$' + (((res['total_cents'] ?? 0) as num) / 100).toStringAsFixed(2) +
              '\nShip: ' + (res['ship'] ?? 0).toString() +
              '  Pickup: ' + (res['pickup'] ?? 0).toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Run failed: ' + e.toString())));
    }
  }
}
