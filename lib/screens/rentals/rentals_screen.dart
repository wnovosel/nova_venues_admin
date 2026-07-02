import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});
  @override State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  List<Map<String, dynamic>> _rentals = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getRentals();
      final list = (res['inquiries'] ?? res['data']?['inquiries'] ?? []) as List;
      setState(() { _rentals = list.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _rentals;
    return _rentals.where((r) => r['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Rentals')),
      body: Column(children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            for (final f in ['all', 'pending', 'confirmed', 'declined'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f[0].toUpperCase() + f.substring(1)),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: kPrimary.withOpacity(0.15),
                  checkmarkColor: kPrimary,
                  labelStyle: TextStyle(
                    color: _filter == f ? kPrimary : kTextMuted,
                    fontWeight: _filter == f ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : _error != null
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_error!, style: const TextStyle(color: kTextMuted)),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: kPrimary,
                      child: _filtered.isEmpty
                          ? const Center(child: Text('No rentals found', style: TextStyle(color: kTextMuted)))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) => _RentalCard(
                                rental: _filtered[i],
                                onRefresh: _load,
                              ),
                            ),
                    ),
        ),
      ]),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final Map<String, dynamic> rental;
  final VoidCallback onRefresh;
  const _RentalCard({required this.rental, required this.onRefresh});

  Color get _statusColor => switch (rental['status'] ?? '') {
    'confirmed' => kSuccess,
    'pending'   => kWarning,
    'declined'  => kError,
    _           => kTextMuted,
  };

  @override
  Widget build(BuildContext context) {
    final eventDate = rental['event_date'] != null
        ? DateTime.tryParse(rental['event_date'].toString())
        : null;

    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rental['name'] ?? rental['contact_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text(rental['event_type'] ?? rental['inquiry_type'] ?? '',
                style: const TextStyle(fontSize: 13, color: kTextMuted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor.withOpacity(0.3)),
            ),
            child: Text(
              (rental['status'] ?? 'pending').toString().toUpperCase(),
              style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w700),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        Row(children: [
          if (eventDate != null) ...[
            const Icon(Icons.calendar_today, size: 14, color: kTextMuted),
            const SizedBox(width: 4),
            Text(DateFormat('MMM d, yyyy').format(eventDate),
                style: const TextStyle(fontSize: 13, color: kTextMuted)),
            const SizedBox(width: 16),
          ],
          if (rental['guest_count'] != null) ...[
            const Icon(Icons.people, size: 14, color: kTextMuted),
            const SizedBox(width: 4),
            Text('${rental['guest_count']} guests',
                style: const TextStyle(fontSize: 13, color: kTextMuted)),
          ],
        ]),

        if (rental['notes'] != null || rental['message'] != null) ...[
          const SizedBox(height: 8),
          Text(rental['notes'] ?? rental['message'] ?? '',
              style: const TextStyle(fontSize: 13, color: kTextMuted),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],

        if (rental['status'] == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _decline(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kError,
                  side: const BorderSide(color: kError),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _confirm(context),
                child: const Text('Confirm'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    await context.read<AppProvider>().api.confirmRental(rental['id'].toString());
    onRefresh();
  }

  Future<void> _decline(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Inquiry?'),
        content: const Text('This will notify the customer their inquiry was declined.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline', style: TextStyle(color: kError)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().api.declineRental(rental['id'].toString());
      onRefresh();
    }
  }
}
