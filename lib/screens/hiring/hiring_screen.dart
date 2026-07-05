import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class HiringScreen extends StatefulWidget {
  const HiringScreen({super.key});
  @override State<HiringScreen> createState() => _HiringScreenState();
}

class _HiringScreenState extends State<HiringScreen> {
  String _status = 'new';
  List<Map<String, dynamic>> _apps = [];
  Map<String, dynamic> _counts = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<AppProvider>().api.getHiring(_status);
      setState(() {
        _apps = (res['applications'] as List? ?? []).cast<Map<String, dynamic>>();
        _counts = (res['counts'] as Map<String, dynamic>? ?? {});
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(height: 56, child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          for (final s in ['new', 'reviewing', 'hired', 'declined', 'all'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s == 'all' ? 'All'
                    : s[0].toUpperCase() + s.substring(1) +
                      ((_counts[s] ?? 0) > 0 ? ' (' + _counts[s].toString() + ')' : '')),
                selected: _status == s,
                selectedColor: kPrimary,
                labelStyle: TextStyle(
                    color: _status == s ? Colors.white : kTextDark,
                    fontWeight: FontWeight.w700, fontSize: 13),
                onSelected: (_) { setState(() => _status = s); _load(); },
              ),
            ),
        ],
      )),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _error != null
              ? Center(child: TextButton(onPressed: _load,
                  child: Text('Error - tap to retry', textAlign: TextAlign.center)))
              : _apps.isEmpty
                  ? const Center(child: Text('No applications', style: TextStyle(color: kTextMuted)))
                  : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                      itemCount: _apps.length,
                      itemBuilder: (_, i) => _appCard(_apps[i]),
                    ))),
    ]);
  }

  Widget _appCard(Map<String, dynamic> a) {
    final name = (a['name'] ?? a['applicant_name'] ?? 'Applicant').toString();
    final pos  = (a['position'] ?? a['role'] ?? '').toString();
    final when = _fmt(a['created_at'] ?? a['applied_at']);
    final st   = (a['status'] ?? 'new').toString();
    return InkWell(
      onTap: () => _openDetail(a),
      child: Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          CircleAvatar(backgroundColor: kPrimary.withOpacity(.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextDark)),
            if (pos.isNotEmpty)
              Text(pos, style: const TextStyle(fontSize: 13, color: kTextMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _statusPill(st),
            const SizedBox(height: 4),
            Text(when, style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ]),
      ),
    );
  }

  Widget _statusPill(String s) {
    final c = {'new': kPrimary, 'reviewing': kWarning, 'hired': kSuccess,
               'declined': kTextMuted}[s] ?? kTextMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(100)),
      child: Text(s.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }

  void _openDetail(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _HiringDetailSheet(app: a, onChanged: _load),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    try { return DateFormat('MMM d').format(DateTime.parse(v.toString())); }
    catch (_) { return ''; }
  }
}

class _HiringDetailSheet extends StatefulWidget {
  final Map<String, dynamic> app;
  final VoidCallback onChanged;
  const _HiringDetailSheet({required this.app, required this.onChanged});
  @override State<_HiringDetailSheet> createState() => _HiringDetailSheetState();
}

class _HiringDetailSheetState extends State<_HiringDetailSheet> {
  late final TextEditingController _notes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(
        text: (widget.app['admin_notes'] ?? widget.app['notes'] ?? '').toString());
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    final id = (a['id'] ?? a['work_unit_id'] ?? '').toString();
    final fields = <List<String>>[
      ['Email', (a['email'] ?? '').toString()],
      ['Phone', (a['phone'] ?? '').toString()],
      ['Availability', (a['availability'] ?? '').toString()],
      ['Experience', (a['experience'] ?? '').toString()],
    ];
    return DraggableScrollableSheet(
      initialChildSize: .72, maxChildSize: .95, minChildSize: .4, expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl, padding: const EdgeInsets.all(20),
        children: [
          Text((a['name'] ?? a['applicant_name'] ?? 'Applicant').toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
          if ((a['position'] ?? '').toString().isNotEmpty)
            Text(a['position'].toString(),
                style: const TextStyle(fontSize: 14, color: kPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (final f in fields)
            if (f[1].isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 92, child: Text(f[0],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextMuted))),
                  Expanded(child: Text(f[1],
                      style: const TextStyle(fontSize: 14, color: kTextDark))),
                ])),
          if ((a['resume_url'] ?? '').toString().isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Copy resume link'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: a['resume_url'].toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resume link copied')));
              }),
          const SizedBox(height: 14),
          const Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kTextMuted)),
          const SizedBox(height: 6),
          TextField(controller: _notes, maxLines: 3,
            decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: 'Internal notes...')),
          TextButton(onPressed: _busy ? null : () => _saveNotes(id),
              child: const Text('Save notes')),
          const SizedBox(height: 8),
          const Text('Set status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kTextMuted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton(style: FilledButton.styleFrom(backgroundColor: kWarning),
                onPressed: _busy ? null : () => _setStatus(id, 'reviewing'),
                child: const Text('Reviewing')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: kSuccess),
                onPressed: _busy ? null : () => _setStatus(id, 'hired'),
                child: const Text('Hired')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: kTextMuted),
                onPressed: _busy ? null : () => _setStatus(id, 'declined'),
                child: const Text('Declined')),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _setStatus(String id, String status) async {
    setState(() => _busy = true);
    try {
      await context.read<AppProvider>().api.setHiringStatus(id, status);
      widget.onChanged();
      if (mounted) { Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Marked ' + status))); }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ' + e.toString())));
    }
  }

  Future<void> _saveNotes(String id) async {
    try {
      await context.read<AppProvider>().api.setHiringNotes(id, _notes.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ' + e.toString())));
    }
  }
}
