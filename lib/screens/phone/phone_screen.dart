import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';
import 'voicemail_sheet.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _saving = false;
  final _greeting = TextEditingController();
  final _forward  = TextEditingController();
  final _voice    = TextEditingController();
  final _voiceBk  = TextEditingController();
  bool _transferAlways = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppProvider>().api.getPhone();
      final s = (res['settings'] as Map<String, dynamic>? ?? {});
      setState(() {
        _data = res;
        _greeting.text = (s['phone_greeting'] ?? '').toString();
        _forward.text  = (s['phone_forward_number'] ?? '').toString();
        _voice.text    = (s['phone_voice_id'] ?? '').toString();
        _voiceBk.text  = (s['phone_voice_id_backup'] ?? '').toString();
        _transferAlways = (s['phone_transfer_always'] ?? '') == '1';
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppProvider>().api.savePhoneSettings({
        'phone_greeting': _greeting.text.trim(),
        'phone_forward_number': _forward.text.trim(),
        'phone_voice_id': _voice.text.trim(),
        'phone_voice_id_backup': _voiceBk.text.trim(),
        'phone_transfer_always': _transferAlways ? '1' : '',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone settings saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ' + e.toString())));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kPrimary));
    final calls = (_data['calls'] as List? ?? []).cast<Map<String, dynamic>>();
    return RefreshIndicator(onRefresh: _load, child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Icon(Icons.support_agent, color: kPrimary),
          const SizedBox(width: 8),
          const Expanded(child: Text('AI Phone Assistant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark))),
          Text((_data['total_calls'] ?? 0).toString() + ' calls',
              style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _greeting, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Greeting',
              helperText: 'What the assistant says when it answers',
              border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _forward, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Forward / transfer number',
              border: OutlineInputBorder())),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _transferAlways,
          activeColor: kPrimary,
          contentPadding: EdgeInsets.zero,
          title: const Text('Always transfer to a human',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Skip the AI and ring the forward number directly'),
          onChanged: (v) => setState(() => _transferAlways = v)),
        const SizedBox(height: 4),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Voice settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          children: [
            TextField(controller: _voice,
                decoration: const InputDecoration(labelText: 'ElevenLabs voice ID',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _voiceBk,
                decoration: const InputDecoration(labelText: 'Backup voice ID',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
          ]),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save settings'))),
        const SizedBox(height: 6),
        const Text('Location routing and hour schedules are edited on the web admin.',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
        const SizedBox(height: 20),
        const Text('RECENT CALLS', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w800, color: kTextMuted, letterSpacing: 1)),
        const SizedBox(height: 6),
        for (final c in calls) Builder(builder: (ctx) {
          final hasVm = (c['voicemail_url'] ?? c['recording_url'] ?? '')
              .toString().isNotEmpty;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            // Voicemails open a sheet to listen + read the full transcript.
            onTap: hasVm ? () => showVoicemailSheet(ctx, c) : null,
            leading: Icon(hasVm ? Icons.voicemail : Icons.phone,
                color: hasVm ? kError : kSuccess),
            title: Text((c['caller_name'] ?? c['from_number'] ?? 'Unknown').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600, color: kTextDark)),
            subtitle: Text((c['summary'] ?? c['voicemail_transcript'] ?? '').toString(),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: hasVm
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_fmt(c['started_at']),
                        style: const TextStyle(fontSize: 11, color: kTextMuted)),
                    const SizedBox(width: 4),
                    const Icon(Icons.play_circle_outline, size: 20, color: kPrimary),
                  ])
                : Text(_fmt(c['started_at']),
                    style: const TextStyle(fontSize: 11, color: kTextMuted)),
          );
        }),
        if (calls.isEmpty)
          const Text('No calls yet', style: TextStyle(color: kTextMuted)),
      ],
    ));
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    try { return DateFormat('MMM d\nh:mm a').format(DateTime.parse(v.toString())); }
    catch (_) { return ''; }
  }
}
