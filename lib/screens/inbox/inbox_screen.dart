import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getInbox();
      final list = (res['messages'] ?? res['data']?['messages'] ?? res['items'] ?? []) as List;
      setState(() { _messages = list.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Inbox')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: kTextMuted)),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kPrimary,
                  child: _messages.isEmpty
                      ? const Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 48, color: kTextMuted),
                            SizedBox(height: 12),
                            Text('Inbox is empty', style: TextStyle(color: kTextMuted, fontSize: 16)),
                          ],
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final m = _messages[i];
                            final isUnread = m['is_read'] == false || m['read'] == false;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: cardDecoration(),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: kPrimary.withOpacity(0.1),
                                  child: Text(
                                    ((m['from_name'] ?? m['sender'] ?? '?').toString().isNotEmpty
                                        ? (m['from_name'] ?? m['sender']).toString()[0].toUpperCase()
                                        : '?'),
                                    style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Text(
                                  m['from_name'] ?? m['sender'] ?? m['subject'] ?? 'Message',
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                                    fontSize: 15,
                                    color: kTextDark,
                                  ),
                                ),
                                subtitle: Text(
                                  m['subject'] ?? m['summary'] ?? m['body'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: kTextMuted),
                                ),
                                trailing: isUnread
                                    ? Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                                      )
                                    : null,
                                onTap: () {
                                  // TODO: open message detail
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
