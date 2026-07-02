import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

// ── Events List ───────────────────────────────────────────────────────────────

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppProvider>().api.getEvents();
      final list = (res['events'] as List? ?? []).cast<Map<String,dynamic>>();
      setState(() { _all = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String,dynamic>> get _upcoming => _all.where((e) {
    try { return DateTime.parse(e['starts_at'].toString()).isAfter(DateTime.now().subtract(const Duration(hours: 6))); }
    catch (_) { return true; }
  }).toList();

  List<Map<String,dynamic>> get _past => _all.where((e) {
    try { return DateTime.parse(e['starts_at'].toString()).isBefore(DateTime.now().subtract(const Duration(hours: 6))); }
    catch (_) { return false; }
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Events'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Past (${_past.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              onRefresh: _load,
              color: kPrimary,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _EventList(events: _upcoming, onRefresh: _load),
                  _EventList(events: _past, onRefresh: _load, isPast: true),
                ],
              ),
            ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<Map<String,dynamic>> events;
  final VoidCallback onRefresh;
  final bool isPast;
  const _EventList({required this.events, required this.onRefresh, this.isPast = false});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text(
        isPast ? 'No past events' : 'No upcoming events',
        style: const TextStyle(color: kTextMuted),
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _EventCard(event: events[i], onRefresh: onRefresh),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String,dynamic> event;
  final VoidCallback onRefresh;
  const _EventCard({required this.event, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final startsAt = _parseDate(event['starts_at']);
    final ticketCount = event['ticket_count'] ?? 0;
    final checkedIn = event['checked_in_count'] ?? 0;
    final isCancelled = event['is_cancelled'] == true;
    final isSoldOut = event['sold_out'] == true || event['is_sold_out'] == true;
    final isPublished = event['is_published'] != false;
    final heroUrl = event['hero_image_url'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => EventDetailScreen(eventId: event['id'], title: event['title'] ?? ''),
      )).then((_) => onRefresh()),
      child: Container(
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero image
          if (heroUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(heroUrl, height: 120, width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(event['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kTextDark))),
                if (isCancelled) _chip('Cancelled', kError)
                else if (isSoldOut) _chip('Sold Out', kWarning)
                else if (!isPublished) _chip('Draft', kTextMuted)
                else _chip('Active', kSuccess),
              ]),

              const SizedBox(height: 6),

              if (startsAt != null)
                Row(children: [
                  const Icon(Icons.calendar_today, size: 13, color: kTextMuted),
                  const SizedBox(width: 4),
                  Text(DateFormat('EEE, MMM d • h:mm a').format(startsAt),
                      style: const TextStyle(fontSize: 13, color: kTextMuted)),
                ]),

              if (event['location'] != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: kTextMuted),
                  const SizedBox(width: 4),
                  Text(event['location'], style: const TextStyle(fontSize: 13, color: kTextMuted)),
                ]),
              ],

              if (ticketCount > 0) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.confirmation_num_outlined, size: 13, color: kPrimary),
                  const SizedBox(width: 4),
                  Text('$ticketCount tickets · $checkedIn checked in',
                      style: const TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w600)),
                ]),
              ],

              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Manage →', style: TextStyle(
                  fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );
}

// ── Event Detail ──────────────────────────────────────────────────────────────

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  final String title;
  const EventDetailScreen({super.key, required this.eventId, required this.title});
  @override State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String,dynamic>? _event;
  List<Map<String,dynamic>> _tiers = [];
  List<Map<String,dynamic>> _attendees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppProvider>().api;
      final results = await Future.wait([
        api.getEventDetail(widget.eventId),
        api.getEventAttendees(widget.eventId),
      ]);
      setState(() {
        _event = results[0]['event'] as Map<String,dynamic>?;
        _tiers = (results[0]['tiers'] as List? ?? []).cast<Map<String,dynamic>>();
        _attendees = (results[1]['attendees'] as List? ?? []).cast<Map<String,dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    final isCancelled = e?['is_cancelled'] == true;
    final isSoldOut = e?['sold_out'] == true;
    final isPublished = e?['is_published'] != false;
    final checkedIn = _attendees.where((a) => a['checked_in_at'] != null).length;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        actions: [
          if (e != null) PopupMenuButton<String>(
            onSelected: (action) => _handleAction(action),
            itemBuilder: (_) => [
              if (!isCancelled) const PopupMenuItem(value: 'cancel', child: Text('Cancel Event')),
              PopupMenuItem(value: 'soldout', child: Text(isSoldOut ? 'Remove Sold Out' : 'Mark Sold Out')),
              PopupMenuItem(value: 'publish', child: Text(isPublished ? 'Unpublish' : 'Publish')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          tabs: [
            const Tab(text: 'Details'),
            Tab(text: 'Attendees ($checkedIn/${_attendees.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : TabBarView(
              controller: _tabs,
              children: [
                _DetailsTab(event: e, tiers: _tiers),
                _AttendeesTab(
                  eventId: widget.eventId,
                  attendees: _attendees,
                  onRefresh: _load,
                ),
              ],
            ),
    );
  }

  Future<void> _handleAction(String action) async {
    final api = context.read<AppProvider>().api;
    try {
      switch (action) {
        case 'cancel':
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Cancel Event?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
                TextButton(onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel Event', style: TextStyle(color: kError))),
              ],
            ),
          );
          if (ok == true) await api.cancelEvent(widget.eventId.toString());
        case 'soldout':
          await api.toggleSoldOut(widget.eventId.toString());
        case 'publish':
          await api.togglePublish(widget.eventId.toString());
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kError));
    }
  }
}

// ── Details Tab ───────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final Map<String,dynamic>? event;
  final List<Map<String,dynamic>> tiers;
  const _DetailsTab({this.event, required this.tiers});

  @override
  Widget build(BuildContext context) {
    final e = event;
    if (e == null) return const Center(child: Text('No data', style: TextStyle(color: kTextMuted)));

    final startsAt = _parseDate(e['starts_at']);
    final endsAt   = _parseDate(e['ends_at']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (e['hero_image_url'] != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(e['hero_image_url'], width: double.infinity,
              height: 180, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),

        // Status badges
        Row(children: [
          if (e['is_cancelled'] == true) _badge('Cancelled', kError),
          if (e['sold_out'] == true) _badge('Sold Out', kWarning),
          if (e['is_published'] == false) _badge('Draft', kTextMuted)
          else if (e['is_cancelled'] != true) _badge('Published', kSuccess),
        ]),
        const SizedBox(height: 16),

        _InfoRow(Icons.calendar_today, 'Date',
          startsAt != null ? DateFormat('EEEE, MMMM d, y').format(startsAt) : '—'),
        _InfoRow(Icons.access_time, 'Time',
          [startsAt != null ? DateFormat('h:mm a').format(startsAt) : null,
           endsAt   != null ? DateFormat('h:mm a').format(endsAt)   : null]
              .whereType<String>().join(' – ')),
        if (e['location'] != null)
          _InfoRow(Icons.location_on_outlined, 'Location', e['location']),
        if (e['price'] != null)
          _InfoRow(Icons.attach_money, 'Price', '\$${e['price']}'),
        if (e['description'] != null && e['description'].toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
          const SizedBox(height: 6),
          Text(e['description'], style: const TextStyle(fontSize: 14, height: 1.5)),
        ],

        if (tiers.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Ticket Tiers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ...tiers.map((t) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: cardDecoration(),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('\$${t['price'] ?? 0}', style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${t['tickets_sold'] ?? 0} sold',
                    style: const TextStyle(fontSize: 13, color: kTextMuted)),
                if (t['capacity'] != null)
                  Text('of ${t['capacity']}', style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: kTextMuted),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 14, color: kTextDark)),
      ]),
    ]),
  );
}

// ── Attendees Tab ─────────────────────────────────────────────────────────────

class _AttendeesTab extends StatelessWidget {
  final int eventId;
  final List<Map<String,dynamic>> attendees;
  final VoidCallback onRefresh;
  const _AttendeesTab({required this.eventId, required this.attendees, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (attendees.isEmpty) {
      return const Center(child: Text('No attendees yet', style: TextStyle(color: kTextMuted)));
    }

    final checkedIn = attendees.where((a) => a['checked_in_at'] != null).length;

    return Column(children: [
      // Summary bar
      Container(
        color: kSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _StatPill('Total', '${attendees.length}', kTextMuted),
          const SizedBox(width: 12),
          _StatPill('Checked In', '$checkedIn', kSuccess),
          const SizedBox(width: 12),
          _StatPill('Remaining', '${attendees.length - checkedIn}', kPrimary),
        ]),
      ),
      const Divider(height: 1),

      // Attendee list
      Expanded(
        child: ListView.separated(
          itemCount: attendees.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (_, i) {
            final a = attendees[i];
            final isCheckedIn = a['checked_in_at'] != null;
            final name = a['buyer_name'] ?? 'Guest';
            final email = a['buyer_email'] ?? '';
            final tierName = a['tier_name'] ?? '';
            final qty = a['quantity'] ?? 1;
            final checkedInAt = _parseDate(a['checked_in_at']);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: isCheckedIn ? kSuccess.withOpacity(0.1) : kBorder,
                child: Icon(
                  isCheckedIn ? Icons.check : Icons.person_outline,
                  color: isCheckedIn ? kSuccess : kTextMuted,
                  size: 18,
                ),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                Text('$tierName${qty > 1 ? ' × $qty' : ''}',
                    style: const TextStyle(fontSize: 12, color: kTextMuted)),
                if (isCheckedIn && checkedInAt != null)
                  Text('✓ ${DateFormat('h:mm a').format(checkedInAt)}',
                      style: const TextStyle(fontSize: 11, color: kSuccess, fontWeight: FontWeight.w600)),
              ]),
              trailing: GestureDetector(
                onTap: () => _toggleCheckin(context, a),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCheckedIn ? kError.withOpacity(0.1) : kSuccess.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCheckedIn ? kError.withOpacity(0.3) : kSuccess.withOpacity(0.3)),
                  ),
                  child: Text(
                    isCheckedIn ? 'Undo' : 'Check In',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCheckedIn ? kError : kSuccess,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _toggleCheckin(BuildContext context, Map<String,dynamic> attendee) async {
    final api = context.read<AppProvider>().api;
    final ticketId = attendee['id'];
    final isCheckedIn = attendee['checked_in_at'] != null;
    try {
      if (isCheckedIn) {
        await api.undoCheckin(eventId, ticketId);
      } else {
        await api.checkIn(eventId, ticketId);
      }
      onRefresh();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kError));
    }
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ]),
  );
}

DateTime? _parseDate(dynamic val) {
  if (val == null) return null;
  try { return DateTime.parse(val.toString()).toLocal(); }
  catch (_) { return null; }
}
