import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

/// Customer lookup: search by name or email, open a person to see every
/// ticket they've bought, resend any ticket's email.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _customers = const [];

  @override
  void initState() {
    super.initState();
    _run(''); // initial recent-customers list
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<AppProvider>().api.searchCustomers(q.trim());
      final list = (res['customers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (mounted) setState(() { _customers = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _onChanged,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search name or email…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _search.clear(); _run(''); },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: kError)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _customers.isEmpty
                    ? const Center(
                        child: Text('No customers found',
                            style: TextStyle(color: kTextMuted)))
                    : ListView.separated(
                        itemCount: _customers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final c = _customers[i];
                          final name = (c['name'] ?? 'Member').toString();
                          final email = (c['email'] ?? '').toString();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: kPrimary.withValues(alpha: .12),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: kPrimary, fontWeight: FontWeight.w800),
                              ),
                            ),
                            title: Text(name,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(email.isEmpty ? 'No email' : email),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: email.isEmpty
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CustomerTicketsScreen(
                                            name: name, email: email),
                                      ),
                                    ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Every ticket a customer has bought, with per-ticket resend.
class CustomerTicketsScreen extends StatefulWidget {
  final String name;
  final String email;
  const CustomerTicketsScreen({super.key, required this.name, required this.email});

  @override
  State<CustomerTicketsScreen> createState() => _CustomerTicketsScreenState();
}

class _CustomerTicketsScreenState extends State<CustomerTicketsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tickets = const [];
  final Set<int> _resending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res =
          await context.read<AppProvider>().api.getCustomerTickets(widget.email);
      final list = (res['tickets'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (mounted) setState(() { _tickets = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _resend(Map<String, dynamic> t) async {
    final id = t['id'];
    if (id is! int || _resending.contains(id)) return;
    setState(() => _resending.add(id));
    try {
      final res = await context.read<AppProvider>().api.resendTicket(id);
      if (!mounted) return;
      final to = (res['to'] ?? widget.email).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket resent to $to')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Resend failed: ${e.toString().replaceFirst('ApiException: ', '')}'),
        backgroundColor: kError,
      ));
    } finally {
      if (mounted) setState(() => _resending.remove(id));
    }
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '';
    try {
      return DateFormat('EEE, MMM d · h:mm a')
          .format(DateTime.parse(iso.toString()).toLocal());
    } catch (_) {
      return iso.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name, style: const TextStyle(fontSize: 16)),
            Text(widget.email,
                style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kError)),
                  ),
                )
              : _tickets.isEmpty
                  ? const Center(
                      child: Text('No tickets for this customer',
                          style: TextStyle(color: kTextMuted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _tickets.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, i) {
                          final t = _tickets[i];
                          final id = t['id'];
                          final checkedIn = t['checked_in_at'] != null;
                          final qty = t['quantity'] ?? 1;
                          final busy = id is int && _resending.contains(id);
                          return ListTile(
                            isThreeLine: true,
                            title: Text(
                                (t['event_title'] ?? 'Event').toString(),
                                style:
                                    const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_fmtDate(t['starts_at'])),
                                Text(
                                  [
                                    '$qty ticket${qty == 1 ? '' : 's'}',
                                    if ((t['tier_name'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      t['tier_name'].toString(),
                                    checkedIn ? 'Checked in' : 'Not checked in',
                                  ].join(' · '),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          checkedIn ? kSuccess : kTextMuted),
                                ),
                              ],
                            ),
                            trailing: busy
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: kPrimary))
                                : IconButton(
                                    tooltip: 'Resend ticket email',
                                    icon: const Icon(Icons.forward_to_inbox,
                                        color: kPrimary),
                                    onPressed: () => _resend(t),
                                  ),
                          );
                        },
                      ),
                    ),
    );
  }
}
