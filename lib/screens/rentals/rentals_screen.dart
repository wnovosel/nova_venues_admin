import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

// ── Rentals List ──────────────────────────────────────────────────────────────

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});
  @override State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  List<Map<String, dynamic>> _rentals = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppProvider>().api.getRentals();
      final list = (res['rentals'] ?? res['inquiries'] ?? []) as List;
      setState(() { _rentals = list.cast<Map<String,dynamic>>(); _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String,dynamic>> get _filtered =>
      _filter == 'all' ? _rentals : _rentals.where((r) => r['status'] == _filter).toList();

  Map<String, int> get _counts => {
    'pending':   _rentals.where((r) => r['status'] == 'pending').length,
    'confirmed': _rentals.where((r) => r['status'] == 'confirmed').length,
    'declined':  _rentals.where((r) => r['status'] == 'declined').length,
  };

  @override
  Widget build(BuildContext context) {
    final pending = _counts['pending'] ?? 0;
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('Rentals${pending > 0 ? ' ($pending pending)' : ''}'),
      ),
      body: Column(children: [
        // Stats bar
        if (!_loading && _rentals.isNotEmpty)
          Container(
            color: kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              _StatChip('All', _rentals.length, 'all', _filter, () => setState(() => _filter = 'all')),
              const SizedBox(width: 8),
              _StatChip('Pending', _counts['pending']!, 'pending', _filter, () => setState(() => _filter = 'pending'), color: kWarning),
              const SizedBox(width: 8),
              _StatChip('Confirmed', _counts['confirmed']!, 'confirmed', _filter, () => setState(() => _filter = 'confirmed'), color: kSuccess),
              const SizedBox(width: 8),
              _StatChip('Declined', _counts['declined']!, 'declined', _filter, () => setState(() => _filter = 'declined'), color: kError),
            ]),
          ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kPrimary,
                  child: _filtered.isEmpty
                      ? Center(child: Text('No $_filter rentals', style: const TextStyle(color: kTextMuted)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
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

class _StatChip extends StatelessWidget {
  final String label, value, filter;
  final int count;
  final VoidCallback onTap;
  final Color color;
  const _StatChip(this.label, this.count, this.value, this.filter, this.onTap, {this.color = kTextMuted});

  @override
  Widget build(BuildContext context) {
    final selected = filter == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : kBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : kBorder),
        ),
        child: Text('$label $count',
          style: TextStyle(fontSize: 12, color: selected ? color : kTextMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}

// ── Rental Card ───────────────────────────────────────────────────────────────

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
    final eventDate = _parseDate(rental['event_date']);
    final name = rental['name'] ?? rental['contact_name'] ?? 'Unknown';
    final venue = rental['venue'] ?? '';
    final eventType = rental['event_type'] ?? '';
    final guests = rental['guest_count'];
    final status = rental['status'] ?? 'pending';
    final deposit = rental['deposit_amount'];
    final total = rental['total_amount'];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => RentalDetailScreen(rentalId: rental['id'], name: name),
      )).then((_) => onRefresh()),
      child: Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kTextDark))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Text(status.toUpperCase(),
                style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w700)),
            ),
          ]),

          const SizedBox(height: 8),

          if (eventType.isNotEmpty)
            Row(children: [
              const Icon(Icons.celebration_outlined, size: 14, color: kTextMuted),
              const SizedBox(width: 4),
              Text(eventType, style: const TextStyle(fontSize: 13, color: kTextMuted)),
            ]),

          if (eventDate != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: kTextMuted),
              const SizedBox(width: 4),
              Text(DateFormat('EEE, MMM d, y').format(eventDate),
                style: const TextStyle(fontSize: 13, color: kTextMuted)),
            ]),
          ],

          Row(children: [
            if (venue.isNotEmpty) ...[
              const Icon(Icons.location_on_outlined, size: 14, color: kTextMuted),
              const SizedBox(width: 4),
              Text(venue, style: const TextStyle(fontSize: 13, color: kTextMuted)),
              const SizedBox(width: 12),
            ],
            if (guests != null) ...[
              const Icon(Icons.people_outline, size: 14, color: kTextMuted),
              const SizedBox(width: 4),
              Text('$guests guests', style: const TextStyle(fontSize: 13, color: kTextMuted)),
            ],
          ]),

          if (deposit != null || total != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (deposit != null) ...[
                const Icon(Icons.attach_money, size: 14, color: kSuccess),
                Text('Deposit: \$${deposit}', style: const TextStyle(fontSize: 13, color: kSuccess, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
              ],
              if (total != null) ...[
                Text('Total: \$${total}', style: const TextStyle(fontSize: 13, color: kTextMuted)),
              ],
            ]),
          ],

          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => _decline(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kError, side: const BorderSide(color: kError),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Decline'),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => RentalDetailScreen(rentalId: rental['id'], name: name),
                )).then((_) => onRefresh()),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('Review & Confirm'),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _decline(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Inquiry?'),
        content: const Text('This will notify the customer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline', style: TextStyle(color: kError))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().api.declineRental(rental['id'].toString());
      onRefresh();
    }
  }
}

// ── Rental Detail ─────────────────────────────────────────────────────────────

class RentalDetailScreen extends StatefulWidget {
  final dynamic rentalId;
  final String name;
  const RentalDetailScreen({super.key, required this.rentalId, required this.name});
  @override State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  Map<String,dynamic>? _rental;
  bool _loading = true;
  bool _saving = false;
  final _depositCtrl = TextEditingController();
  final _totalCtrl   = TextEditingController();
  final _noteCtrl    = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _depositCtrl.dispose(); _totalCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppProvider>().api.getRentalDetail(widget.rentalId);
      final r = res['rental'] as Map<String,dynamic>?;
      setState(() {
        _rental = r;
        if (r?['deposit_amount'] != null) _depositCtrl.text = '${r!['deposit_amount']}';
        if (r?['total_amount'] != null) _totalCtrl.text = '${r!['total_amount']}';
        if (r?['admin_notes'] != null) _noteCtrl.text = r!['admin_notes'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final res = await context.read<AppProvider>().api.confirmRentalDetail(
        widget.rentalId.toString(),
        deposit: double.tryParse(_depositCtrl.text),
        total: double.tryParse(_totalCtrl.text),
        notes: _noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Confirmed! Portal: ${res['portal_url'] ?? ''}'),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kError));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNote() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;
    try {
      await context.read<AppProvider>().api.addRentalNote(widget.rentalId.toString(), note);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved'), backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kError));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _rental;
    final status = r?['status'] ?? 'pending';
    final isPending = status == 'pending';

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: Text(widget.name, style: const TextStyle(fontSize: 16))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : r == null
              ? const Center(child: Text('Not found', style: TextStyle(color: kTextMuted)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Status banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _statusColor(status).withOpacity(0.3)),
                      ),
                      child: Text(status.toUpperCase(),
                        style: TextStyle(color: _statusColor(status),
                          fontWeight: FontWeight.w700, fontSize: 14),
                        textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 20),

                    // Contact info
                    _Section(title: 'Contact', children: [
                      _Row('Name', r['name'] ?? ''),
                      _Row('Email', r['email'] ?? ''),
                      _Row('Phone', r['phone'] ?? ''),
                    ]),
                    const SizedBox(height: 16),

                    // Event details
                    _Section(title: 'Event Details', children: [
                      _Row('Type', r['event_type'] ?? ''),
                      _Row('Date', r['event_date'] != null
                          ? DateFormat('EEE, MMM d, y').format(_parseDate(r['event_date'])!)
                          : ''),
                      _Row('Venue', r['venue'] ?? ''),
                      _Row('Guests', '${r['guest_count'] ?? ''}'),
                      if (r['message'] != null && r['message'].toString().isNotEmpty)
                        _Row('Message', r['message']),
                    ]),
                    const SizedBox(height: 16),

                    // Financials
                    _Section(title: 'Financials', children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _depositCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Deposit Amount (\$)',
                            prefixText: '\$ ',
                          ),
                        ),
                      ),
                      TextField(
                        controller: _totalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Total Amount (\$)',
                          prefixText: '\$ ',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Notes
                    _Section(title: 'Admin Notes', children: [
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Internal notes, special requests, setup details...',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _saveNote,
                          child: const Text('Save Note'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Action buttons
                    if (isPending)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _confirm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: kSuccess,
                          ),
                          child: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Confirm & Send Portal Link',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),

                    if (status == 'confirmed') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: cardDecoration(),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Portal Link', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
                          const SizedBox(height: 4),
                          Text(r['portal_token'] != null
                              ? 'nova-venue.com/rentals/portal/${r['portal_token']}'
                              : 'No portal link',
                            style: const TextStyle(fontSize: 13, color: kPrimary)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ]),
                ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'confirmed' => kSuccess,
    'pending'   => kWarning,
    'declined'  => kError,
    _           => kTextMuted,
  };
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: cardDecoration(),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextDark)),
      const SizedBox(height: 12),
      ...children,
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: kTextDark))),
      ]),
    );
  }
}

DateTime? _parseDate(dynamic val) {
  if (val == null) return null;
  final s = val.toString();
  try { return DateTime.parse(s).toLocal(); } catch (_) {}
  try {
    final months = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,
                    'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
    final parts = s.replaceAll(',','').split(' ');
    final day = int.parse(parts[1]);
    final mon = months[parts[2]] ?? 1;
    final year = int.parse(parts[3]);
    return DateTime(year, mon, day);
  } catch (_) {}
  return null;
}
