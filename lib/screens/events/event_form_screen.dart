import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

/// Create or edit an event. Posts to /admin/events/save, which delegates to
/// the SAME service the web admin uses (one save path).
///
/// Contract notes that matter (from the service's scar tissue):
/// - action MUST be 'publish' or 'save_draft'; the backend refuses anything
///   else because ambiguous publish state once force-unpublished events on
///   every save.
/// - dates are sent as ISO starts_at / ends_at, which the service accepts as
///   its fallback vocabulary.
class EventFormScreen extends StatefulWidget {
  /// Null for a new event; an existing event map (from getEventDetail) to edit.
  final Map<String, dynamic>? event;
  const EventFormScreen({super.key, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late final TextEditingController _shortDesc;
  late final TextEditingController _desc;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  bool get _isEdit => widget.event != null;
  int? get _eventId {
    final id = widget.event?['id'];
    if (id is int) return id;
    return int.tryParse('$id');
  }

  @override
  void initState() {
    super.initState();
    final e = widget.event ?? const {};
    _title = TextEditingController(text: (e['title'] ?? '').toString());
    _location = TextEditingController(text: (e['location'] ?? '').toString());
    _capacity = TextEditingController(
        text: e['capacity'] == null ? '' : '${e['capacity']}');
    _shortDesc =
        TextEditingController(text: (e['short_description'] ?? '').toString());
    _desc = TextEditingController(text: (e['description'] ?? '').toString());
    _startsAt = _parse(e['starts_at']);
    _endsAt = _parse(e['ends_at']);
  }

  DateTime? _parse(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _capacity.dispose();
    _shortDesc.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool start}) async {
    final existing = start ? _startsAt : _endsAt;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: existing ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing ?? now),
    );
    if (time == null) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = picked;
        // Keep end after start by default.
        if (_endsAt == null || _endsAt!.isBefore(picked)) {
          _endsAt = picked.add(const Duration(hours: 2));
        }
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _save(String action) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a start date and time')));
      return;
    }
    setState(() => _saving = true);
    try {
      final fields = <String, dynamic>{
        'title': _title.text.trim(),
        'location': _location.text.trim(),
        'starts_at': _startsAt!.toIso8601String(),
        if (_endsAt != null) 'ends_at': _endsAt!.toIso8601String(),
        if (_capacity.text.trim().isNotEmpty) 'capacity': _capacity.text.trim(),
        if (_shortDesc.text.trim().isNotEmpty)
          'short_description': _shortDesc.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'action': action, // REQUIRED: 'publish' | 'save_draft'
      };
      await context
          .read<AppProvider>()
          .api
          .saveEvent(fields, eventId: _isEdit ? _eventId : null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'publish'
              ? 'Event published'
              : 'Draft saved')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('ApiException: ', '')),
        backgroundColor: kError,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(DateTime? d) =>
      d == null ? 'Not set' : DateFormat('EEE, MMM d · h:mm a').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Event' : 'New Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: kPrimary),
              title: const Text('Starts'),
              subtitle: Text(_fmt(_startsAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => _pickDateTime(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available, color: kPrimary),
              title: const Text('Ends'),
              subtitle: Text(_fmt(_endsAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => _pickDateTime(start: false),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                  labelText: 'Location', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Capacity (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _shortDesc,
              maxLength: 160,
              decoration: const InputDecoration(
                  labelText: 'Short description (listings)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _desc,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                  labelText: 'Full description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _save('save_draft'),
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: _saving ? null : () => _save('publish'),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Publish'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Save Draft keeps the event unpublished. Publish makes it live on the site immediately.',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ],
        ),
      ),
    );
  }
}
