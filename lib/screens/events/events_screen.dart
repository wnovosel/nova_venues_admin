import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getEvents();
      final list = (res['events'] ?? res['data']?['events'] ?? []) as List;
      setState(() { _events = list.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {
            // TODO: New event
          }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: kTextMuted)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kPrimary,
                  child: _events.isEmpty
                      ? const Center(child: Text('No events found', style: TextStyle(color: kTextMuted)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _EventCard(
                            event: _events[i],
                            onRefresh: _load,
                          ),
                        ),
                ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onRefresh;
  const _EventCard({required this.event, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final startsAt = event['starts_at'] != null
        ? DateTime.tryParse(event['starts_at'].toString())
        : null;
    final ticketsSold = event['tickets_sold'] ?? 0;
    final capacity    = event['capacity'] ?? 0;
    final isSoldOut   = event['is_sold_out'] == true;
    final isCancelled = event['is_cancelled'] == true;

    return Container(
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event['title'] ?? 'Untitled', style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: kTextDark)),
              const SizedBox(height: 4),
              if (startsAt != null)
                Text(DateFormat('EEE, MMM d • h:mm a').format(startsAt),
                    style: const TextStyle(fontSize: 13, color: kTextMuted)),
              if (event['location'] != null)
                Text(event['location'], style: const TextStyle(fontSize: 13, color: kPrimary)),
            ])),
            // Status chip
            if (isCancelled)
              _chip('Cancelled', kError)
            else if (isSoldOut)
              _chip('Sold Out', kWarning)
            else
              _chip('Active', kSuccess),
          ]),
        ),

        // Ticket progress
        if (capacity > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$ticketsSold / $capacity tickets',
                    style: const TextStyle(fontSize: 12, color: kTextMuted)),
                Text('${capacity > 0 ? (ticketsSold / capacity * 100).toStringAsFixed(0) : 0}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: capacity > 0 ? ticketsSold / capacity : 0,
                backgroundColor: kBorder,
                valueColor: const AlwaysStoppedAnimation(kPrimary),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // Actions
        if (!isCancelled)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(foregroundColor: kError),
                onPressed: () => _confirmCancel(context),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: Icon(isSoldOut ? Icons.lock_open : Icons.lock, size: 16),
                label: Text(isSoldOut ? 'Reopen' : 'Mark Sold Out'),
                style: TextButton.styleFrom(foregroundColor: kWarning),
                onPressed: () => _toggleSoldOut(context),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Event?'),
        content: Text('Cancel "${event['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Event', style: TextStyle(color: kError)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().api.cancelEvent(event['id'].toString());
      onRefresh();
    }
  }

  Future<void> _toggleSoldOut(BuildContext context) async {
    await context.read<AppProvider>().api.toggleSoldOut(event['id'].toString());
    onRefresh();
  }
}
