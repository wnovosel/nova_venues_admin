import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Map<String,dynamic>> _events = [];
  List<Map<String,dynamic>> _rentals = [];
  bool _loading = true;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppProvider>().api;
      final eRes = await api.getEvents();
      final rRes = await api.getRentals();
      setState(() {
        _events  = (eRes['events']   as List? ?? []).cast<Map<String,dynamic>>();
        _rentals = (rRes['rentals']  as List? ?? rRes['inquiries'] as List? ?? []).cast<Map<String,dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String,dynamic>> _itemsForDay(DateTime day) {
    final items = <Map<String,dynamic>>[];
    for (final e in _events) {
      final d = _parseDate(e['starts_at']);
      if (d != null && d.year == day.year && d.month == day.month && d.day == day.day) {
        items.add({...e, '_type': 'event'});
      }
    }
    for (final r in _rentals) {
      final d = _parseDate(r['event_date']);
      if (d != null && d.year == day.year && d.month == day.month && d.day == day.day) {
        items.add({...r, '_type': 'rental'});
      }
    }
    return items;
  }

  Set<int> _daysWithItems(int year, int month) {
    final days = <int>{};
    for (final e in _events) {
      final d = _parseDate(e['starts_at']);
      if (d != null && d.year == year && d.month == month) days.add(d.day);
    }
    for (final r in _rentals) {
      final d = _parseDate(r['event_date']);
      if (d != null && d.year == year && d.month == month) days.add(d.day);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final daysWithItems = _daysWithItems(_focusedMonth.year, _focusedMonth.month);
    final selectedItems = _selectedDay != null ? _itemsForDay(_selectedDay!) : <Map<String,dynamic>>[];

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Calendar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(children: [
              // Month navigation
              Container(
                color: kSurface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() =>
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
                  ),
                  Expanded(child: Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextDark),
                    textAlign: TextAlign.center,
                  )),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() =>
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
                  ),
                ]),
              ),

              // Day of week headers
              Container(
                color: kSurface,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: ['Su','Mo','Tu','We','Th','Fr','Sa'].map((d) =>
                    Expanded(child: Text(d,
                      style: const TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center))
                  ).toList(),
                ),
              ),
              const Divider(height: 1),

              // Calendar grid
              _CalendarGrid(
                month: _focusedMonth,
                daysWithItems: daysWithItems,
                selectedDay: _selectedDay,
                onDayTap: (day) => setState(() => _selectedDay = day),
              ),

              const Divider(height: 1),

              // Selected day items
              Expanded(
                child: selectedItems.isEmpty
                    ? Center(child: Text(
                        _selectedDay == null ? 'Tap a day to see events' : 'Nothing on this day',
                        style: const TextStyle(color: kTextMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: selectedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = selectedItems[i];
                          final isEvent = item['_type'] == 'event';
                          return Container(
                            decoration: cardDecoration(),
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: (isEvent ? kPrimary : Color(0xFF6B4FBB)).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isEvent ? Icons.event : Icons.home_work,
                                  color: isEvent ? kPrimary : const Color(0xFF6B4FBB),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  isEvent ? (item['title'] ?? '') : (item['name'] ?? item['contact_name'] ?? ''),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(
                                  isEvent
                                    ? (item['location'] ?? '')
                                    : '${item['event_type'] ?? ''} · ${item['guest_count'] ?? '?'} guests',
                                  style: const TextStyle(fontSize: 12, color: kTextMuted)),
                                if (isEvent && item['starts_at'] != null)
                                  Text(
                                    _parseDate(item['starts_at']) != null
                                      ? DateFormat('h:mm a').format(_parseDate(item['starts_at'])!)
                                      : '',
                                    style: const TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isEvent ? kPrimary.withOpacity(0.1) : const Color(0xFF6B4FBB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isEvent ? 'Event' : (item['status'] ?? 'Rental'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isEvent ? kPrimary : const Color(0xFF6B4FBB),
                                    fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Set<int> daysWithItems;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;
  const _CalendarGrid({required this.month, required this.daysWithItems,
    required this.selectedDay, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) cells.add(const SizedBox());
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      final isSelected = selectedDay != null && date.year == selectedDay!.year &&
          date.month == selectedDay!.month && date.day == selectedDay!.day;
      final hasItems = daysWithItems.contains(day);

      cells.add(GestureDetector(
        onTap: () => onDayTap(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? kPrimary : isToday ? kPrimary.withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: TextStyle(
              fontSize: 14,
              fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? Colors.white : isToday ? kPrimary : kTextDark,
            )),
            if (hasItems)
              Container(width: 4, height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : kPrimary,
                  shape: BoxShape.circle)),
          ]),
        ),
      ));
    }

    return Container(
      color: kSurface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.0,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: cells,
      ),
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
    if (parts.length >= 4) {
      final day = int.parse(parts[1]);
      final mon = months[parts[2]] ?? 1;
      final year = int.parse(parts[3]);
      if (parts.length >= 5 && parts[4].contains(':')) {
        final t = parts[4].split(':');
        return DateTime.utc(year, mon, day, int.parse(t[0]), int.parse(t[1])).toLocal();
      }
      return DateTime(year, mon, day);
    }
  } catch (_) {}
  return null;
}
