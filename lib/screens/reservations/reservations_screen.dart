// Reservations — tenant floor board (2026-07-14).
// The web gained a full Tock-parity reservations engine this week; this is
// its mobile face: tonight's covers at a glance, one-tap status from the
// floor, the human-in-the-loop no-show charge queue, and a phone-in booking
// flow that uses the same server path as the public widget (capacity checks
// + confirmation email included).
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../api/admin_api.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  DateTime _day = DateTime.now();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _board = [];
  List<Map<String, dynamic>> _chargeQueue = [];
  List<Map<String, dynamic>> _experiences = [];
  int _feeCents = 0;

  String get _dayParam =>
      '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppProvider>().api;
      final data = await api.getReservations(_dayParam);
      if (!mounted) return;
      setState(() {
        _board = List<Map<String, dynamic>>.from(data['board'] ?? []);
        _chargeQueue = List<Map<String, dynamic>>.from(data['charge_queue'] ?? []);
        _experiences = List<Map<String, dynamic>>.from(data['experiences'] ?? []);
        _feeCents = (data['fee_cents'] ?? 0) as int;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Could not load reservations.'; _loading = false; });
    }
  }

  int get _totalCovers => _board.fold(0, (s, r) => s + ((r['party_size'] ?? 0) as int));

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _dateStrip()),
            SliverToBoxAdapter(child: _summaryHeader()),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator(radius: 14)))
            else if (_error != null)
              SliverFillRemaining(child: _errorState())
            else ...[
              if (_chargeQueue.isNotEmpty)
                SliverToBoxAdapter(child: _chargeQueueCard()),
              if (_board.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else
                _boardList(),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Reservation',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: _experiences.isEmpty ? null : _openBookingSheet,
      ),
    );
  }

  // ── Date strip: 14 days, today anchored ──────────────────────────────────
  Widget _dateStrip() {
    final today = DateTime.now();
    return Container(
      color: kSurface,
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: 14,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final d = today.add(Duration(days: i));
            final sel = d.year == _day.year && d.month == _day.month && d.day == _day.day;
            const wk = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _day = d);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 52,
                decoration: BoxDecoration(
                  color: sel ? kPrimary : kBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(wk[d.weekday - 1],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: sel ? Colors.white70 : kTextMuted)),
                    const SizedBox(height: 3),
                    Text('${d.day}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : kTextDark)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summaryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_isToday ? 'Today' : _weekdayLong(_day),
              style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kTextDark)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
                _loading ? '' : '${_board.length} parties · $_totalCovers covers',
                style: const TextStyle(fontSize: 13, color: kTextMuted)),
          ),
        ],
      ),
    );
  }

  String _weekdayLong(DateTime d) {
    const names = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${names[d.weekday - 1]} ${d.month}/${d.day}';
  }

  // ── Board ─────────────────────────────────────────────────────────────────
  Widget _boardList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      sliver: SliverList.separated(
        itemCount: _board.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _reservationCard(_board[i]),
      ),
    );
  }

  Widget _reservationCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'confirmed').toString();
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetailSheet(r),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              _timeBlock(r),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['guest_name']?.toString() ?? 'Guest',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kTextDark),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      [
                        r['experience_name'],
                        if ((r['notes'] ?? '').toString().isNotEmpty) r['notes'],
                      ].where((e) => e != null).join(' · '),
                      style: const TextStyle(fontSize: 12.5, color: kTextMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _partyPill(r['party_size']),
              const SizedBox(width: 8),
              _statusChip(status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeBlock(Map<String, dynamic> r) {
    final t = _fmtTime(r['reserved_at']?.toString());
    return SizedBox(
      width: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.$1,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: kTextDark)),
          Text(t.$2, style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ],
      ),
    );
  }

  (String, String) _fmtTime(String? iso) {
    if (iso == null) return ('—', '');
    final dt = DateTime.tryParse(iso);
    if (dt == null) return ('—', '');
    final h12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final mm = dt.minute.toString().padLeft(2, '0');
    return ('$h12:$mm', dt.hour >= 12 ? 'PM' : 'AM');
  }

  Widget _partyPill(dynamic size) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const Icon(Icons.person_outline, size: 13, color: kTextMuted),
        const SizedBox(width: 3),
        Text('${size ?? '-'}',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
      ]),
    );
  }

  static const _statusMeta = {
    'confirmed': (Color(0xFF1D4ED8), Color(0xFFDBEAFE), 'Confirmed'),
    'seated':    (kSuccess, Color(0xFFD1E7DD), 'Seated'),
    'completed': (kTextMuted, Color(0xFFEDEAE6), 'Done'),
    'no_show':   (kWarning, Color(0xFFFDE8D0), 'No-show'),
    'cancelled': (kError, Color(0xFFF6D9DC), 'Cancelled'),
  };

  Widget _statusChip(String status) {
    final m = _statusMeta[status] ?? _statusMeta['confirmed']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: m.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(m.$3,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: m.$1)),
    );
  }

  // ── Detail + status actions ───────────────────────────────────────────────
  void _openDetailSheet(Map<String, dynamic> r) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final t = _fmtTime(r['reserved_at']?.toString());
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: kBorder,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: Text(r['guest_name']?.toString() ?? 'Guest',
                        style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 21,
                            fontWeight: FontWeight.w700)),
                  ),
                  _statusChip((r['status'] ?? 'confirmed').toString()),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${t.$1} ${t.$2} · ${r['party_size'] ?? '-'} guests · ${r['experience_name'] ?? ''}',
                  style: const TextStyle(fontSize: 13.5, color: kTextMuted),
                ),
                if ((r['guest_phone'] ?? '').toString().isNotEmpty ||
                    (r['guest_email'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    [r['guest_phone'], r['guest_email']]
                        .where((e) => (e ?? '').toString().isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(fontSize: 13, color: kTextMuted),
                  ),
                ],
                if ((r['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(r['notes'].toString(),
                        style: const TextStyle(fontSize: 13.5)),
                  ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  _actionButton(ctx, r, 'seated', 'Seat', Icons.event_seat_outlined, kSuccess),
                  const SizedBox(width: 8),
                  _actionButton(ctx, r, 'completed', 'Done', Icons.check_circle_outline, kTextMuted),
                  const SizedBox(width: 8),
                  _actionButton(ctx, r, 'no_show', 'No-show', Icons.person_off_outlined, kWarning),
                  const SizedBox(width: 8),
                  _actionButton(ctx, r, 'cancelled', 'Cancel', Icons.close, kError),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton(BuildContext sheetCtx, Map<String, dynamic> r,
      String status, String label, IconData icon, Color color) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.45)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(sheetCtx);
          await _setStatus(r, status);
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _setStatus(Map<String, dynamic> r, String status) async {
    final api = context.read<AppProvider>().api;
    final prev = r['status'];
    setState(() => r['status'] = status); // optimistic
    try {
      final res = await api.setReservationStatus(
          int.parse(r['id'].toString()), status);
      if (res['ok'] != true) throw const ApiException('rejected');
      HapticFeedback.lightImpact();
      if (status == 'no_show') _load(); // may enter the charge queue
    } catch (_) {
      if (!mounted) return;
      setState(() => r['status'] = prev); // roll back
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update — check connection.')));
    }
  }

  // ── No-show charge queue (human-in-the-loop) ─────────────────────────────
  Widget _chargeQueueCard() {
    final fee = (_feeCents / 100).toStringAsFixed(2);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0DFC0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.credit_card_outlined, size: 17, color: kWarning),
            SizedBox(width: 7),
            Text('No-show charges to review',
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextDark)),
          ]),
          const SizedBox(height: 10),
          ..._chargeQueue.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        '${c['guest_name'] ?? 'Guest'} · ${_fmtTime(c['reserved_at']?.toString()).$1} ${_fmtTime(c['reserved_at']?.toString()).$2}',
                        style: const TextStyle(fontSize: 13.5)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: kWarning,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _confirmCharge(c, fee),
                    child: Text('Charge \$$fee',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
              )),
        ],
      ),
    );
  }

  void _confirmCharge(Map<String, dynamic> c, String fee) {
    HapticFeedback.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Charge no-show fee?'),
        content: Text(
            '\$$fee will be charged to the card on file for ${c['guest_name'] ?? 'this guest'}. This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
              child: const Text('Not now'),
              onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Charge card'),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = context.read<AppProvider>().api;
              try {
                final res = await api.chargeNoShow(int.parse(c['id'].toString()));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res['ok'] == true
                        ? 'Card charged.'
                        : (res['message']?.toString() ?? 'Charge failed.'))));
                _load();
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Charge failed — check connection.')));
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Manual booking (phone-in / walk-in) ───────────────────────────────────
  void _openBookingSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BookingSheet(
        experiences: _experiences,
        day: _dayParam,
        onBooked: () {
          _load();
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wine_bar_outlined, size: 44, color: kBorder),
          const SizedBox(height: 12),
          Text(_isToday ? 'No reservations today — yet.' : 'No reservations this day.',
              style: const TextStyle(fontSize: 14.5, color: kTextMuted)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: kTextMuted)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('Retry')),
      ]),
    );
  }
}

// ═══ Booking sheet: experience → slot → guest, one smooth flow ═════════════
class _BookingSheet extends StatefulWidget {
  final List<Map<String, dynamic>> experiences;
  final String day;
  final VoidCallback onBooked;
  const _BookingSheet(
      {required this.experiences, required this.day, required this.onBooked});
  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  int? _expId;
  List<Map<String, dynamic>> _slots = [];
  bool _slotsLoading = false;
  String? _slot;
  int _party = 2;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.experiences.length == 1) {
      _expId = int.tryParse(widget.experiences.first['id'].toString());
      _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    if (_expId == null) return;
    setState(() { _slotsLoading = true; _slot = null; });
    try {
      final api = context.read<AppProvider>().api;
      final data = await api.getReservationSlots(_expId!, widget.day);
      if (!mounted) return;
      setState(() {
        _slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
        _slotsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _slots = []; _slotsLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: kBorder, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('New reservation',
                  style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 21,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (widget.experiences.length > 1) ...[
                _label('EXPERIENCE'),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: widget.experiences.map((e) {
                    final id = int.tryParse(e['id'].toString());
                    final sel = id == _expId;
                    return ChoiceChip(
                      label: Text(e['name']?.toString() ?? 'Experience'),
                      selected: sel,
                      selectedColor: kPrimary,
                      labelStyle: TextStyle(
                          color: sel ? Colors.white : kTextDark,
                          fontWeight: FontWeight.w600, fontSize: 13),
                      backgroundColor: kBackground,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) {
                        setState(() => _expId = id);
                        _loadSlots();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              _label('TIME'),
              if (_slotsLoading)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CupertinoActivityIndicator()))
              else if (_expId == null)
                const Text('Choose an experience first.',
                    style: TextStyle(fontSize: 13, color: kTextMuted))
              else if (_slots.isEmpty)
                const Text('No open slots this day.',
                    style: TextStyle(fontSize: 13, color: kTextMuted))
              else
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _slots.map((s) {
                    final iso = s['time']?.toString() ?? s['slot']?.toString() ?? '';
                    final full = s['available'] == false || s['full'] == true;
                    final sel = iso == _slot;
                    final dt = DateTime.tryParse(iso);
                    final lbl = dt == null
                        ? iso
                        : '${dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
                    return ChoiceChip(
                      label: Text(lbl),
                      selected: sel,
                      selectedColor: kPrimary,
                      labelStyle: TextStyle(
                          color: full
                              ? kBorder
                              : (sel ? Colors.white : kTextDark),
                          fontWeight: FontWeight.w600, fontSize: 13),
                      backgroundColor: kBackground,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      onSelected: full
                          ? null
                          : (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _slot = iso);
                            },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              _label('PARTY SIZE'),
              Row(children: [
                _stepBtn(Icons.remove, () {
                  if (_party > 1) setState(() => _party--);
                }),
                SizedBox(
                  width: 52,
                  child: Center(
                      child: Text('$_party',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700))),
                ),
                _stepBtn(Icons.add, () => setState(() => _party++)),
              ]),
              const SizedBox(height: 16),
              _label('GUEST'),
              _field(_name, 'Name', TextInputType.name),
              const SizedBox(height: 8),
              _field(_phone, 'Phone (optional)', TextInputType.phone),
              const SizedBox(height: 8),
              _field(_email, 'Email — sends confirmation (optional)',
                  TextInputType.emailAddress),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_slot == null ||
                          _name.text.trim().isEmpty ||
                          _submitting)
                      ? null
                      : _submit,
                  child: _submitting
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text('Book it',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.createReservation({
        'experience_id': _expId,
        'reserved_at': _slot,
        'party_size': _party,
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
      });
      if (!mounted) return;
      if (res['ok'] == true) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        widget.onBooked();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_email.text.trim().isEmpty
                ? 'Reservation booked.'
                : 'Booked — confirmation email sent.')));
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['message']?.toString() ??
                res['error']?.toString() ??
                'Could not book.')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not book — check connection.')));
    }
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: kTextMuted)),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => Material(
        color: kBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () { HapticFeedback.selectionClick(); onTap(); },
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 20, color: kTextDark)),
        ),
      );

  Widget _field(TextEditingController c, String hint, TextInputType type) =>
      TextField(
        controller: c,
        keyboardType: type,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13.5, color: kTextMuted),
          filled: true,
          fillColor: kBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );
}
