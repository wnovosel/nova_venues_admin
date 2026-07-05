import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});
  @override State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getChatHub();
      final logs = await api.getChatLogs(limit: 200);
      setState(() {
        _data = res;
        _logs = (logs['logs'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final faqs = (_data['faqs'] as List? ?? []).cast<Map<String, dynamic>>();
    final stats = (_data['stats'] as Map<String, dynamic>? ?? {});
    return Scaffold(
      backgroundColor: kBackground,
      floatingActionButton: _tabs.index == 0
        ? FloatingActionButton(backgroundColor: kPrimary,
            onPressed: () => _faqDialog(), child: const Icon(Icons.add, color: Colors.white))
        : null,
      body: Column(children: [
        Container(color: kSurface, child: TabBar(
          controller: _tabs, labelColor: kPrimary, unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(text: 'FAQ (' + faqs.length.toString() + ')'),
            const Tab(text: 'Logs'),
            const Tab(text: 'Stats'),
          ])),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : TabBarView(controller: _tabs, children: [
              _faqTab(faqs), _logsTab(), _statsTab(stats),
            ])),
      ]),
    );
  }

  Widget _faqTab(List<Map<String, dynamic>> faqs) {
    if (faqs.isEmpty) {
      return const Center(child: Text('No FAQ entries yet - tap + to add',
          style: TextStyle(color: kTextMuted)));
    }
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(
      itemCount: faqs.length,
      itemBuilder: (_, i) {
        final f = faqs[i];
        final active = f['is_active'] != false;
        return Dismissible(
          key: ValueKey('faq' + f['id'].toString()),
          direction: DismissDirection.endToStart,
          background: Container(color: kError, alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (_) async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
              title: const Text('Delete FAQ?'),
              content: Text('Keyword: ' + (f['keyword'] ?? '').toString()),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
              ]));
            if (ok == true) {
              await context.read<AppProvider>().api.deleteFaq(f['id'] as int);
              _load();
            }
            return ok == true;
          },
          child: ListTile(
            onTap: () => _faqDialog(existing: f),
            leading: Switch(value: active, activeColor: kSuccess,
              onChanged: (v) async {
                await context.read<AppProvider>().api.toggleFaq(f['id'] as int, v);
                _load();
              }),
            title: Text((f['keyword'] ?? '').toString(),
                style: TextStyle(fontWeight: FontWeight.w800,
                    color: active ? kTextDark : kTextMuted)),
            subtitle: Text((f['answer'] ?? '').toString(),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text('x' + (f['hit_count'] ?? 0).toString(),
                style: const TextStyle(fontWeight: FontWeight.w800, color: kTextMuted)),
          ),
        );
      }));
  }

  Widget _logsTab() {
    if (_logs.isEmpty) {
      return const Center(child: Text('No chat logs', style: TextStyle(color: kTextMuted)));
    }
    // Group by session
    final Map<String, List<Map<String, dynamic>>> sessions = {};
    for (final l in _logs) {
      final sid = (l['session_id'] ?? l['details']?['session_id'] ?? 'unknown').toString();
      sessions.putIfAbsent(sid, () => []).add(l);
    }
    final keys = sessions.keys.toList();
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final msgs = sessions[keys[i]]!;
        final first = msgs.first;
        return ExpansionTile(
          leading: const Icon(Icons.chat_bubble_outline, color: kPrimary),
          title: Text((first['body'] ?? '').toString(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextDark)),
          subtitle: Text(msgs.length.toString() + ' messages - ' + _fmt(first['occurred_at'])),
          children: [
            for (final m in msgs)
              Container(
                alignment: (m['role'] ?? m['type']) == 'user'
                    ? Alignment.centerRight : Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 290),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (m['role'] ?? m['type']) == 'user' ? kPrimary : kBorder,
                    borderRadius: BorderRadius.circular(12)),
                  child: Text((m['body'] ?? '').toString(),
                      style: TextStyle(fontSize: 13,
                          color: (m['role'] ?? m['type']) == 'user' ? Colors.white : kTextDark)),
                )),
            const SizedBox(height: 10),
          ],
        );
      }));
  }

  Widget _statsTab(Map<String, dynamic> stats) {
    final top = (_data['top_questions'] as List? ?? []).cast<Map<String, dynamic>>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        _stat('Total chats', stats['total_sessions'] ?? stats['total'] ?? 0),
        const SizedBox(width: 10),
        _stat('Messages', stats['total_messages'] ?? 0),
        const SizedBox(width: 10),
        _stat('FAQ hits', stats['faq_hits'] ?? 0),
      ]),
      const SizedBox(height: 20),
      const Text('TOP QUESTIONS', style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w800, color: kTextMuted, letterSpacing: 1)),
      const SizedBox(height: 8),
      for (final q in top) ListTile(
        contentPadding: EdgeInsets.zero, dense: true,
        title: Text((q['question'] ?? q['body'] ?? '').toString(),
            style: const TextStyle(fontSize: 14, color: kTextDark)),
        trailing: Text('x' + (q['count'] ?? q['hits'] ?? 1).toString(),
            style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
      ),
      if (top.isEmpty) const Text('No data yet', style: TextStyle(color: kTextMuted)),
    ]);
  }

  Widget _stat(String label, dynamic v) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder)),
      child: Column(children: [
        Text(v.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kTextDark)),
        Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w700)),
      ])));
  }

  void _faqDialog({Map<String, dynamic>? existing}) {
    final kw = TextEditingController(text: (existing?['keyword'] ?? '').toString());
    final q  = TextEditingController(text: (existing?['question'] ?? '').toString());
    final a  = TextEditingController(text: (existing?['answer'] ?? '').toString());
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(existing == null ? 'Add FAQ' : 'Edit FAQ'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: kw, decoration: const InputDecoration(
            labelText: 'Keyword (matches in questions)')),
        TextField(controller: q, decoration: const InputDecoration(labelText: 'Question (optional)')),
        TextField(controller: a, maxLines: 4, decoration: const InputDecoration(labelText: 'Answer')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final api = context.read<AppProvider>().api;
          if (existing == null) {
            await api.addFaq(kw.text.trim(), q.text.trim(), a.text.trim());
          } else {
            await api.updateFaq(existing['id'] as int, kw.text.trim(), q.text.trim(), a.text.trim());
          }
          if (mounted) Navigator.pop(context);
          _load();
        }, child: const Text('Save')),
      ],
    ));
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    try { return DateFormat('MMM d, h:mm a').format(DateTime.parse(v.toString())); }
    catch (_) { return ''; }
  }
}
