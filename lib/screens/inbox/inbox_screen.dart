import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

// ── Swipe action config ───────────────────────────────────────────────────────

enum SwipeAction { archive, delete, markRead, markUnread, spam, none }

class InboxSettings {
  final SwipeAction swipeLeft;
  final SwipeAction swipeRight;
  const InboxSettings({
    this.swipeLeft  = SwipeAction.archive,
    this.swipeRight = SwipeAction.markRead,
  });
  InboxSettings copyWith({SwipeAction? swipeLeft, SwipeAction? swipeRight}) =>
      InboxSettings(
        swipeLeft:  swipeLeft  ?? this.swipeLeft,
        swipeRight: swipeRight ?? this.swipeRight,
      );
}

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
  InboxSettings _settings = const InboxSettings();
  final Set<int> _archivedIds = {};
  final Set<int> _deletedIds  = {};
  final Map<int, bool> _readOverride = {};

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

  List<Map<String, dynamic>> get _emails {
    final all = (_data['emails'] as List? ?? []).cast<Map<String, dynamic>>();
    return all.where((e) =>
      !_archivedIds.contains(e['id']) &&
      !_deletedIds.contains(e['id'])
    ).toList();
  }

  int get _unread => _emails.where((e) {
    final override = _readOverride[e['id']];
    return override != null ? !override : e['is_read'] == false;
  }).length;

  void _handleSwipeAction(SwipeAction action, Map<String, dynamic> email) {
    final id = email['id'] as int;
    final api = context.read<AppProvider>().api;

    switch (action) {
      case SwipeAction.archive:
        setState(() => _archivedIds.add(id));
        api.archiveEmail(id).catchError((_) {
          setState(() => _archivedIds.remove(id));
          _showUndoSnackbar('Archive failed', () {});
        });
        _showUndoSnackbar('Archived', () {
          setState(() => _archivedIds.remove(id));
        });
      case SwipeAction.delete:
        setState(() => _deletedIds.add(id));
        api.trashEmail(id).catchError((_) {
          setState(() => _deletedIds.remove(id));
          _showUndoSnackbar('Delete failed', () {});
        });
        _showUndoSnackbar('Deleted', () {
          setState(() => _deletedIds.remove(id));
        });
      case SwipeAction.markRead:
        setState(() => _readOverride[id] = true);
      case SwipeAction.markUnread:
        setState(() => _readOverride[id] = false);
        api.markEmailUnread(id);
      case SwipeAction.spam:
        setState(() => _deletedIds.add(id));
        api.markEmailSpam(id);
        _showUndoSnackbar('Marked as spam', () => setState(() => _deletedIds.remove(id)));
      case SwipeAction.none:
        break;
    }
  }

  void _showUndoSnackbar(String label, VoidCallback undo) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(label),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Undo', textColor: Colors.white, onPressed: undo),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final calls = (_data['calls']  as List? ?? []).cast<Map<String, dynamic>>();
    // "Messages" = left messages / leads awaiting a human (contact_submissions).
    // Bot chat transcripts live in the web chat hub, not the inbox.
    final messages = (_data['messages'] as List? ?? []).cast<Map<String, dynamic>>();
    final unhandled = messages.where((m) => m['handled_at'] == null).length;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Inbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (_unread > 0)
            Text('$_unread unread', style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.tune_outlined), onPressed: _showSettings),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showCompose(context)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kPrimary,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Email${_emails.isEmpty ? '' : ' (${_emails.length})'}'),
            Tab(text: 'Calls${calls.isEmpty ? '' : ' (${calls.length})'}'),
            Tab(text: 'Messages${unhandled == 0 ? '' : ' ($unhandled)'}'),
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
                    _EmailList(
                      emails: _emails,
                      settings: _settings,
                      readOverride: _readOverride,
                      onSwipe: _handleSwipeAction,
                      onRefresh: _load,
                    ),
                    _CallList(calls: calls, onChanged: _load),
                    _MessageList(messages: messages, onChanged: _load),
                  ],
                ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InboxSettingsSheet(
        settings: _settings,
        onChanged: (s) => setState(() => _settings = s),
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

// ── Settings Sheet ────────────────────────────────────────────────────────────

class _InboxSettingsSheet extends StatefulWidget {
  final InboxSettings settings;
  final ValueChanged<InboxSettings> onChanged;
  const _InboxSettingsSheet({required this.settings, required this.onChanged});
  @override State<_InboxSettingsSheet> createState() => _InboxSettingsSheetState();
}

class _InboxSettingsSheetState extends State<_InboxSettingsSheet> {
  late InboxSettings _s;

  @override
  void initState() { super.initState(); _s = widget.settings; }

  static const _labels = {
    SwipeAction.archive:    ('Archive', Icons.archive_outlined, kTextMuted),
    SwipeAction.delete:     ('Delete',  Icons.delete_outlined,  kError),
    SwipeAction.markRead:   ('Mark Read',   Icons.mark_email_read_outlined, kSuccess),
    SwipeAction.markUnread: ('Mark Unread', Icons.mark_email_unread_outlined, kPrimary),
    SwipeAction.none:       ('None', Icons.block, kBorder),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        const Text('Swipe Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 20),

        const Text('Swipe Left  ←', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kError)),
        const SizedBox(height: 6),
        _SwipeSelector(
          current: _s.swipeLeft,
          onChanged: (a) {
            setState(() => _s = _s.copyWith(swipeLeft: a));
            widget.onChanged(_s);
          },
        ),
        const SizedBox(height: 20),
        const Text('→ Swipe Right', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kSuccess)),
        const SizedBox(height: 6),
        _SwipeSelector(
          current: _s.swipeRight,
          onChanged: (a) {
            setState(() => _s = _s.copyWith(swipeRight: a));
            widget.onChanged(_s);
          },
        ),
        const SizedBox(height: 40),
      ])),
    );
  }
}

class _SwipeSelector extends StatelessWidget {
  final SwipeAction current;
  final ValueChanged<SwipeAction> onChanged;
  const _SwipeSelector({required this.current, required this.onChanged});

  static const _options = [
    SwipeAction.archive,
    SwipeAction.delete,
    SwipeAction.markRead,
    SwipeAction.markUnread,
    SwipeAction.spam,
    SwipeAction.none,
  ];

  static const _labels = {
    SwipeAction.archive:    'Archive',
    SwipeAction.delete:     'Delete',
    SwipeAction.markRead:   'Mark Read',
    SwipeAction.markUnread: 'Mark Unread',
    SwipeAction.spam:       'Spam',
    SwipeAction.none:       'None',
  };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        child: Column(children: _options.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            RadioListTile<SwipeAction>(
              value: a,
              groupValue: current,
              onChanged: (v) => onChanged(v!),
              activeColor: kPrimary,
              title: Text(_labels[a]!, style: const TextStyle(fontSize: 15)),
              dense: true,
            ),
            if (i < _options.length - 1)
              const Divider(height: 1, indent: 16),
          ]);
        }).toList()),
      ),
    ]);
  }
}

// ── Email List with Swipe ─────────────────────────────────────────────────────

class _EmailList extends StatelessWidget {
  final List<Map<String, dynamic>> emails;
  final InboxSettings settings;
  final Map<int, bool> readOverride;
  final void Function(SwipeAction, Map<String, dynamic>) onSwipe;
  final VoidCallback onRefresh;
  const _EmailList({
    required this.emails, required this.settings, required this.readOverride,
    required this.onSwipe, required this.onRefresh,
  });

  static const _actionColors = {
    SwipeAction.archive:    kTextMuted,
    SwipeAction.delete:     kError,
    SwipeAction.markRead:   kSuccess,
    SwipeAction.markUnread: kPrimary,
    SwipeAction.spam:       kWarning,
    SwipeAction.none:       kBorder,
  };

  static const _actionIcons = {
    SwipeAction.archive:    Icons.archive_outlined,
    SwipeAction.delete:     Icons.delete_outlined,
    SwipeAction.markRead:   Icons.mark_email_read_outlined,
    SwipeAction.markUnread: Icons.mark_email_unread_outlined,
    SwipeAction.spam:       Icons.report_outlined,
    SwipeAction.none:       Icons.block,
  };

  static const _actionLabels = {
    SwipeAction.archive:    'Archive',
    SwipeAction.delete:     'Delete',
    SwipeAction.markRead:   'Read',
    SwipeAction.markUnread: 'Unread',
    SwipeAction.spam:       'Spam',
    SwipeAction.none:       '',
  };

  @override
  Widget build(BuildContext context) {
    if (emails.isEmpty) {
      return const _EmptyState(icon: Icons.mail_outline, message: 'Inbox is empty');
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: kPrimary,
      child: ListView.builder(
        itemCount: emails.length,
        itemBuilder: (_, i) {
          final e = emails[i];
          final id = e['id'] as int;
          final isRead = readOverride[id] ?? (e['is_read'] == true);

          Widget tile = _EmailRow(
            email: e,
            isRead: isRead,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => EmailDetailScreen(email: e),
            )).then((_) => onRefresh()),
          );

          // Combined swipe — single Dismissible handles both directions
          final hasLeft  = settings.swipeLeft  != SwipeAction.none;
          final hasRight = settings.swipeRight != SwipeAction.none;
          if (hasLeft || hasRight) {
            DismissDirection dir;
            if (hasLeft && hasRight) dir = DismissDirection.horizontal;
            else if (hasLeft)        dir = DismissDirection.endToStart;
            else                     dir = DismissDirection.startToEnd;

            tile = Dismissible(
              key: ValueKey('swipe_$id'),
              direction: dir,
              // right swipe background (startToEnd)
              background: hasRight ? _SwipeBg(
                action: settings.swipeRight,
                alignment: Alignment.centerLeft,
                color: _actionColors[settings.swipeRight]!,
                icon: _actionIcons[settings.swipeRight]!,
                label: _actionLabels[settings.swipeRight]!,
              ) : const SizedBox.shrink(),
              // left swipe background (endToStart)
              secondaryBackground: hasLeft ? _SwipeBg(
                action: settings.swipeLeft,
                alignment: Alignment.centerRight,
                color: _actionColors[settings.swipeLeft]!,
                icon: _actionIcons[settings.swipeLeft]!,
                label: _actionLabels[settings.swipeLeft]!,
              ) : null,
              confirmDismiss: (direction) async {
                final action = direction == DismissDirection.startToEnd
                    ? settings.swipeRight
                    : settings.swipeLeft;
                if (action == SwipeAction.none) return false;
                onSwipe(action, e);
                // Only actually dismiss for archive/delete
                return action == SwipeAction.archive || action == SwipeAction.delete;
              },
              child: tile,
            );
          }

          return tile;
        },
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final SwipeAction action;
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;
  const _SwipeBg({required this.action, required this.alignment,
    required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: Colors.white, size: 22),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _EmailRow extends StatelessWidget {
  final Map<String, dynamic> email;
  final bool isRead;
  final VoidCallback onTap;
  const _EmailRow({required this.email, required this.isRead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final from    = email['from_name'] ?? email['from_address'] ?? 'Unknown';
    final subject = email['subject'] ?? '(no subject)';
    final snippet = email['snippet'] ?? '';
    final when    = _formatDate(email['received_at']);
    final replied = email['owner_action'] == 'replied';
    final category = email['ai_category'] as String?;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? kBackground : kSurface,
          border: const Border(bottom: BorderSide(color: kBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(isRead ? 0.07 : 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              from.isNotEmpty ? from[0].toUpperCase() : '?',
              style: TextStyle(
                color: kPrimary,
                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                fontSize: 16,
              ),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                from + (replied ? '  ✓' : ''),
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                  fontSize: 15, color: kTextDark,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
              Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
            const SizedBox(height: 2),
            Text(subject,
              style: TextStyle(
                fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
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
                child: Text(category, style: const TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600)),
              ),
            ],
          ])),
          if (!isRead) ...[
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8, margin: const EdgeInsets.only(top: 6),
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

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

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
          const SnackBar(content: Text('Reply sent ✓'), backgroundColor: kSuccess));
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
    final from    = widget.email['from_name'] ?? widget.email['from_address'] ?? '';
    final fromAddr = widget.email['from_address'] ?? '';
    final subject = widget.email['subject'] ?? '(no subject)';
    final when    = _formatDate(widget.email['received_at']);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Email'),
        actions: [
          IconButton(
            icon: Icon(_showReply ? Icons.reply : Icons.reply_outlined),
            color: _showReply ? kPrimary : null,
            onPressed: () => setState(() => _showReply = !_showReply),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject, style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: kTextDark, height: 1.3)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: kPrimary.withOpacity(0.12), shape: BoxShape.circle),
                child: Center(child: Text(
                  from.isNotEmpty ? from[0].toUpperCase() : '?',
                  style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                )),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(from.isNotEmpty ? from : fromAddr,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextDark)),
                if (fromAddr.isNotEmpty && from.isNotEmpty)
                  Text(fromAddr, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ])),
            ]),
            const Divider(height: 28),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: kPrimary),
              ))
            else
              Text(_body ?? '', style: const TextStyle(fontSize: 15, height: 1.7, color: kTextDark)),
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
              Row(children: [
                const Icon(Icons.reply, size: 14, color: kTextMuted),
                const SizedBox(width: 4),
                Text('Reply to ${from.isNotEmpty ? from : fromAddr}',
                    style: const TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _replyCtrl,
                maxLines: 5,
                minLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Write your reply...',
                ),
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                  onPressed: () => setState(() { _showReply = false; _replyCtrl.clear(); }),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: _sending ? null : _sendReply,
                  icon: _sending
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: const Text('Send'),
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

  @override
  void dispose() {
    _to.dispose(); _subject.dispose(); _body.dispose(); super.dispose();
  }

  Future<void> _send() async {
    if (_to.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To and message body are required')));
      return;
    }
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: _sending
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: kSurface,
          child: Column(children: [
            _ComposeField(controller: _to, label: 'To', keyboardType: TextInputType.emailAddress),
            const Divider(height: 1, indent: 16),
            _ComposeField(controller: _subject, label: 'Subject'),
            const Divider(height: 1),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _body,
              maxLines: null,
              expands: true,
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Write your message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        ),
      ]),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        SizedBox(width: 60,
          child: Text(label, style: const TextStyle(color: kTextMuted, fontSize: 15))),
        Expanded(child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          style: const TextStyle(fontSize: 15),
        )),
      ]),
    );
  }
}

// ── Call List ─────────────────────────────────────────────────────────────────

class _CallList extends StatelessWidget {
  final List<Map<String, dynamic>> calls;
  final VoidCallback onChanged;
  const _CallList({required this.calls, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) return const _EmptyState(icon: Icons.phone_outlined, message: 'No recent calls');

    return ListView.builder(
      itemCount: calls.length,
      itemBuilder: (_, i) {
        final c = calls[i];
        final caller   = c['caller_name'] ?? c['from_number'] ?? 'Unknown';
        final summary  = (c['summary'] ?? '') as String;
        final intent   = (c['intent']  ?? '') as String;
        final when     = _formatDate(c['started_at'] ?? c['ended_at']);
        final durSecs  = (c['duration_sec'] ?? c['duration_seconds']) as int?;
        final isVm     = (c['voicemail_url'] ?? '').toString().isNotEmpty;
        final vmNew    = isVm && c['voicemail_heard'] != true;
        final duration = durSecs != null
            ? '${durSecs ~/ 60}m ${durSecs % 60}s'
            : '';

        return InkWell(
          onTap: () => _showCallDetail(context, c),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: (isVm ? kError : kSuccess).withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(isVm ? Icons.voicemail : Icons.phone,
                    color: isVm ? kError : kSuccess, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(caller, style: TextStyle(
                      fontWeight: vmNew ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15, color: kTextDark))),
                  if (vmNew)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: kError,
                          borderRadius: BorderRadius.circular(100)),
                      child: const Text('VM', style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                    )
                  else
                    Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ]),
                if (intent.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(intent, style: const TextStyle(
                        fontSize: 13, color: kPrimary, fontWeight: FontWeight.w500)),
                  ),
                if (summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(summary, style: const TextStyle(fontSize: 13, color: kTextMuted),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                if (duration.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(duration, style: const TextStyle(fontSize: 11, color: kTextMuted)),
                  ),
              ])),
              const Icon(Icons.chevron_right, color: kBorder, size: 18),
            ]),
          ),
        );
      },
    );
  }

  void _showCallDetail(BuildContext ctx0, Map<String, dynamic> call) {
    showModalBottomSheet(
      context: ctx0,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: kSuccess.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.phone, color: kSuccess, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(call['caller_name'] ?? call['from_number'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextDark)),
                if (call['from_number'] != null)
                  Text(call['from_number'], style: const TextStyle(color: kTextMuted, fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 20),
            if (call['intent'] != null && (call['intent'] as String).isNotEmpty) ...[
              _DetailSection(title: 'Intent', content: call['intent']),
              const SizedBox(height: 16),
            ],
            if (call['summary'] != null && (call['summary'] as String).isNotEmpty) ...[
              _DetailSection(title: 'Summary', content: call['summary']),
              const SizedBox(height: 16),
            ],
            if ((call['voicemail_transcript'] ?? '').toString().isNotEmpty) ...[
              _DetailSection(title: '🎙 Voicemail',
                  content: call['voicemail_transcript']),
              const SizedBox(height: 12),
            ],
            if ((call['voicemail_url'] ?? '').toString().isNotEmpty &&
                call['voicemail_heard'] != true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Mark voicemail heard'),
                  onPressed: () async {
                    final api = ctx0.read<AppProvider>().api;
                    await api.markVoicemailHeard(call['call_sid'] as String);
                    onChanged();
                    if (ctx0.mounted) Navigator.pop(ctx0);
                  },
                ),
              ),
            if ((call['duration_sec'] ?? call['duration_seconds']) != null) ...[
              _DetailSection(title: 'Duration',
                content: '${((call['duration_sec'] ?? call['duration_seconds']) as int) ~/ 60}m ${((call['duration_sec'] ?? call['duration_seconds']) as int) % 60}s'),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title, content;
  const _DetailSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(
        fontWeight: FontWeight.w700, fontSize: 12, color: kTextMuted,
        letterSpacing: 0.5)),
    const SizedBox(height: 6),
    Text(content, style: const TextStyle(fontSize: 15, height: 1.5, color: kTextDark)),
  ]);
}

// ── Chat List ─────────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final VoidCallback onChanged;
  const _MessageList({required this.messages, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState(icon: Icons.chat_bubble_outline,
          message: 'No messages — when someone leaves a message\nfor the team, it lands here');
    }
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
        final name    = (m['name'] ?? m['email'] ?? 'Someone') as String;
        final msg     = (m['message'] ?? '') as String;
        final when    = _formatDate(m['created_at']);
        final source  = (m['source'] ?? '') as String;
        final handled = m['handled_at'] != null;

        return InkWell(
          onTap: () => _showDetail(context, m),
          child: Container(
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: (handled ? kTextMuted : kWarning).withOpacity(0.12),
                    shape: BoxShape.circle),
                child: Icon(Icons.mark_chat_unread_outlined,
                    color: handled ? kTextMuted : kWarning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name, style: TextStyle(
                      fontWeight: handled ? FontWeight.w500 : FontWeight.w800,
                      fontSize: 15, color: kTextDark))),
                  if (!handled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: kPrimary,
                          borderRadius: BorderRadius.circular(100)),
                      child: const Text('NEW', style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                    )
                  else
                    Text(when, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ]),
                const SizedBox(height: 2),
                Text(msg, style: const TextStyle(fontSize: 13, color: kTextMuted),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('$source · $when',
                    style: const TextStyle(fontSize: 11, color: kTextMuted)),
              ])),
            ]),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MessageDetailSheet(message: m, onChanged: onChanged),
    );
  }
}

class _MessageDetailSheet extends StatefulWidget {
  final Map<String, dynamic> message;
  final VoidCallback onChanged;
  const _MessageDetailSheet({required this.message, required this.onChanged});
  @override State<_MessageDetailSheet> createState() => _MessageDetailSheetState();
}

class _MessageDetailSheetState extends State<_MessageDetailSheet> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final email = (m['email'] ?? '') as String;
    final handled = m['handled_at'] != null;
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(m['name'] ?? email,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: kTextDark))),
          TextButton(
            onPressed: () async {
              final api = context.read<AppProvider>().api;
              await api.markMessageHandled(m['id'] as int, !handled);
              widget.onChanged();
              if (mounted) Navigator.pop(context);
            },
            child: Text(handled ? 'Reopen' : 'Mark handled',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        if (email.isNotEmpty)
          Text(email, style: const TextStyle(fontSize: 13, color: kTextMuted)),
        if ((m['phone'] ?? '').toString().isNotEmpty)
          Text(m['phone'], style: const TextStyle(fontSize: 13, color: kTextMuted)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBackground,
              borderRadius: BorderRadius.circular(12)),
          child: Text(m['message'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.5, color: kTextDark)),
        ),
        if (m['replied_at'] != null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('✓ Replied', style: TextStyle(fontSize: 12,
                color: kSuccess, fontWeight: FontWeight.w700)),
          ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _reply, maxLines: 4, minLines: 2,
            decoration: InputDecoration(
              hintText: 'Reply to $email — sends from your mailbox…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _sending ? null : () async {
              final body = _reply.text.trim();
              if (body.isEmpty) return;
              setState(() => _sending = true);
              final api = context.read<AppProvider>().api;
              final res = await api.replyToMessage(m['id'] as int, body);
              if (!mounted) return;
              if (res['sent'] == true) {
                widget.onChanged();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply sent ✓')));
              } else {
                setState(() => _sending = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed: ${res['error'] ?? 'unknown'}')));
              }
            },
            child: Text(_sending ? 'Sending…' : 'Send Reply'),
          )),
        ],
      ]),
    );
  }
}

// ── Shared widgets & helpers ──────────────────────────────────────────────────

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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(error, style: const TextStyle(color: kTextMuted),
            textAlign: TextAlign.center),
      ),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  ));
}

String _formatDate(dynamic val) {
  if (val == null) return '';
  try {
    final dt  = DateTime.parse(val.toString()).toLocal();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('h:mm a').format(dt);
    }
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  } catch (_) { return ''; }
}
