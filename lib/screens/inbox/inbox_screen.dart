import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

// ── Main Inbox Screen ─────────────────────────────────────────────────────────

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getInbox();
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final emails = (_data['emails'] as List? ?? []).cast<Map<String, dynamic>>();
    final calls  = (_data['calls']  as List? ?? []).cast<Map<String, dynamic>>();
    final chats  = (_data['chats']  as List? ?? []).cast<Map<String, dynamic>>();
    final unread = emails.where((e) => e['is_read'] == false).length;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Inbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (unread > 0)
            Text('$unread unread', style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showCompose(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Email${emails.isEmpty ? '' : ' (${emails.length})'}'),
            Tab(text: 'Calls${calls.isEmpty ? '' : ' (${calls.length})'}'),
            Tab(text: 'Chat${chats.isEmpty ? '' : ' (${chats.length})'}'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _EmailList(emails: emails, onRefresh: _load),
                    _CallList(calls: calls),
                    _ChatList(chats: chats),
                  ],
                ),
    );
  }

  void _showCompose(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const ComposeScreen(),
      fullscreenDialog: true,
    ));
  }
}

// ── Email List ────────────────────────────────────────────────────────────────

class _EmailList extends StatelessWidget {
  final List<Map<String, dynamic>> emails;
  final VoidCallback onRefresh;
  const _EmailList({required this.emails, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (emails.isEmpty) {
      return const _EmptyState(icon: Icons.mail_outline, message: 'No emails yet');
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: kPrimary,
      child: ListView.builder(
        itemCount: emails.length,
        itemBuilder: (_, i) {
          final e = emails[i];
          final isUnread = e['is_read'] == false;
          final from = e['from_name'] ?? e['from_address'] ?? 'Unknown';
          final subject = e['subject'] ?? '(no subject)';
          final snippet = e['snippet'] ?? '';
          final when = _formatDate(e['received_at']);
          final replied = e['owner_action'] == 'replied';

          return _EmailRow(
            from: from,
            subject: subject,
            snippet: snippet,
            when: when,
            isUnread: isUnread,
            replied: replied,
            category: e['ai_category'],
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => EmailDetailScreen(email: e),
            )).then((_) => onRefresh()),
          );
        },
      ),
    );
  }
}

class _EmailRow extends StatelessWidget {
  final String from, subject, snippet, when;
  final bool isUnread, replied;
  final String? category;
  final VoidCallback onTap;

  const _EmailRow({
    required this.from, required this.subject, required this.snippet,
    required this.when, required this.isUnread, required this.replied,
    required this.onTap, this.category,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isUnread ? kSurface : kBackground,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              from.isNotEmpty ? from[0].toUpperCase() : '?',
              style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 16),
            )),
          ),
          const SizedBox(width: 12),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                from + (replied ? ' ✓' : ''),
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15, color: kTextDark,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
              Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
            const SizedBox(height: 2),
            Text(subject,
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14, color: kTextDark,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(snippet,
              style: const TextStyle(fontSize: 13, color: kTextMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            if (category != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(category!, style: const TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600)),
              ),
            ],
          ])),

          if (isUnread) ...[
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Email Detail ──────────────────────────────────────────────────────────────

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email;
  const EmailDetailScreen({super.key, required this.email});
  @override State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  String? _body;
  bool _loading = true;
  bool _showReply = false;
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getEmailDetail(widget.email['id']);
      setState(() { _body = res['email']?['body'] ?? widget.email['snippet'] ?? ''; _loading = false; });
    } catch (e) {
      setState(() { _body = widget.email['snippet'] ?? ''; _loading = false; });
    }
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final api = context.read<AppProvider>().api;
      await api.replyEmail(widget.email['id'], _replyCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent'), backgroundColor: kSuccess));
        setState(() { _showReply = false; _sending = false; });
        _replyCtrl.clear();
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: kError));
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.email['from_name'] ?? widget.email['from_address'] ?? '';
    final subject = widget.email['subject'] ?? '(no subject)';
    final when = _formatDate(widget.email['received_at']);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.reply),
            onPressed: () => setState(() => _showReply = !_showReply),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(children: [
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(subject, style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: kTextDark)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Center(child: Text(
                        from.isNotEmpty ? from[0].toUpperCase() : '?',
                        style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
                      )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(from, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                    ])),
                  ]),
                  const Divider(height: 24),
                  Text(_body ?? '', style: const TextStyle(fontSize: 15, height: 1.6, color: kTextDark)),
                ]),
              )),

              // Reply panel
              if (_showReply)
                Container(
                  decoration: const BoxDecoration(
                    color: kSurface,
                    border: Border(top: BorderSide(color: kBorder)),
                  ),
                  padding: EdgeInsets.only(
                    left: 16, right: 16, top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Reply to $from', style: const TextStyle(
                      fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _replyCtrl,
                      maxLines: 4,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Write your reply...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: () => setState(() => _showReply = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _sending ? null : _sendReply,
                        child: _sending
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Send'),
                      ),
                    ]),
                  ]),
                ),
            ]),
    );
  }
}

// ── Compose Screen ────────────────────────────────────────────────────────────

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _to      = TextEditingController();
  final _subject = TextEditingController();
  final _body    = TextEditingController();
  bool _sending  = false;

  Future<void> _send() async {
    if (_to.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final api = context.read<AppProvider>().api;
      await api.composeEmail(_to.text.trim(), _subject.text.trim(), _body.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent!'), backgroundColor: kSuccess));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: kError));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: kPrimary)),
        ),
        title: const Text('New Message'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ComposeField(controller: _to, label: 'To', keyboardType: TextInputType.emailAddress),
          const Divider(height: 1),
          _ComposeField(controller: _subject, label: 'Subject'),
          const Divider(height: 1),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: null,
            minLines: 12,
            decoration: const InputDecoration(
              hintText: 'Write your message...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ComposeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  const _ComposeField({required this.controller, required this.label, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 64, child: Text(label, style: const TextStyle(color: kTextMuted, fontSize: 15))),
      Expanded(child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
        style: const TextStyle(fontSize: 15),
      )),
    ]);
  }
}

// ── Call List ─────────────────────────────────────────────────────────────────

class _CallList extends StatelessWidget {
  final List<Map<String, dynamic>> calls;
  const _CallList({required this.calls});

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) return const _EmptyState(icon: Icons.phone_outlined, message: 'No recent calls');

    return ListView.builder(
      itemCount: calls.length,
      itemBuilder: (_, i) {
        final c = calls[i];
        final caller = c['caller_name'] ?? c['from_number'] ?? 'Unknown';
        final summary = c['summary'] ?? '';
        final intent = c['intent'] ?? '';
        final when = _formatDate(c['started_at'] ?? c['ended_at']);
        final duration = c['duration_seconds'] != null
            ? '${(c['duration_seconds'] / 60).floor()}m ${c['duration_seconds'] % 60}s'
            : '';

        return InkWell(
          onTap: () => _showCallDetail(context, c),
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: kSuccess.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.phone, color: kSuccess, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(caller, style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15, color: kTextDark))),
                  Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ]),
                if (intent.isNotEmpty)
                  Text(intent, style: const TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w500)),
                if (summary.isNotEmpty)
                  Text(summary, style: const TextStyle(fontSize: 13, color: kTextMuted),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                if (duration.isNotEmpty)
                  Text(duration, style: const TextStyle(fontSize: 11, color: kTextMuted)),
              ])),
            ]),
          ),
        );
      },
    );
  }

  void _showCallDetail(BuildContext context, Map<String, dynamic> call) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(call['caller_name'] ?? call['from_number'] ?? 'Unknown',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (call['from_number'] != null)
            Text(call['from_number'], style: const TextStyle(color: kTextMuted)),
          const SizedBox(height: 16),
          if (call['intent'] != null) ...[
            const Text('Intent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
            const SizedBox(height: 4),
            Text(call['intent'], style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
          ],
          if (call['summary'] != null) ...[
            const Text('Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
            const SizedBox(height: 4),
            Text(call['summary'], style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
        ]),
      ),
    );
  }
}

// ── Chat List ─────────────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  final List<Map<String, dynamic>> chats;
  const _ChatList({required this.chats});

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) return const _EmptyState(icon: Icons.chat_bubble_outline, message: 'No chats yet');

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (_, i) {
        final c = chats[i];
        final name = c['visitor_name'] ?? c['visitor_email'] ?? 'Visitor';
        final lastMsg = c['last_message'] ?? '';
        final when = _formatDate(c['last_message_at']);
        final count = c['message_count'] ?? 0;

        return Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: kWarning.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble, color: kWarning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15, color: kTextDark))),
                Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
              Text('$count messages', style: const TextStyle(fontSize: 12, color: kTextMuted)),
              if (lastMsg.isNotEmpty)
                Text(lastMsg, style: const TextStyle(fontSize: 13, color: kTextMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        );
      },
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 56, color: kBorder),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: kTextMuted, fontSize: 16)),
    ],
  ));
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline, color: kTextMuted, size: 48),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: kTextMuted), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  ));
}

String _formatDate(dynamic val) {
  if (val == null) return '';
  try {
    final dt = DateTime.parse(val.toString()).toLocal();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('h:mm a').format(dt);
    }
    if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  } catch (_) {
    return '';
  }
}
