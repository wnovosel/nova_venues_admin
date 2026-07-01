import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class MorningScreen extends StatefulWidget {
  const MorningScreen({super.key});
  @override State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getMorningData();
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      backgroundColor: kBackground,
      body: RefreshIndicator(
        onRefresh: _load,
        color: kPrimary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: kSurface,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: const TextStyle(fontSize: 13, color: kTextMuted, fontWeight: FontWeight.w400)),
                  Text(DateFormat('EEEE, MMMM d').format(now),
                      style: const TextStyle(fontSize: 17, color: kTextDark, fontWeight: FontWeight.w700)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: kTextMuted),
                  onPressed: _load,
                ),
              ],
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: kPrimary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: kTextMuted, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: kTextMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  _SalesSection(data: _data?['sales']),
                  const SizedBox(height: 16),
                  _MoneySection(data: _data?['money']),
                  const SizedBox(height: 16),
                  _ResponsesSection(data: _data?['responses']),
                  const SizedBox(height: 16),
                  _SocialSection(data: _data?['social']),
                  const SizedBox(height: 32),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Sales Section ─────────────────────────────────────────────────────────────

class _SalesSection extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _SalesSection({this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null || data!['available'] != true) {
      return _SectionCard(title: 'Yesterday\'s Sales', icon: Icons.point_of_sale,
          child: const _Unavailable(message: 'Sales data unavailable'));
    }
    final gross = (data!['gross'] ?? 0).toDouble();
    final count = data!['order_count'] ?? 0;
    final topSellers = (data!['top_sellers'] as List? ?? []).cast<Map<String, dynamic>>();

    return _SectionCard(
      title: 'Yesterday\'s Sales',
      icon: Icons.point_of_sale,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _StatBox(
            label: 'Revenue',
            value: '\$${gross.toStringAsFixed(0)}',
            color: kSuccess,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatBox(
            label: 'Orders',
            value: '$count',
            color: kPrimary,
          )),
        ]),
        if (topSellers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Top Sellers', style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
          const SizedBox(height: 8),
          ...topSellers.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, color: kTextDark))),
              Text('${s['units']} sold', style: const TextStyle(fontSize: 12, color: kTextMuted)),
              const SizedBox(width: 12),
              Text('\$${(s['revenue'] ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ── Money Section ─────────────────────────────────────────────────────────────

class _MoneySection extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _MoneySection({this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null || data!['available'] != true) {
      return _SectionCard(title: 'This Month', icon: Icons.account_balance_wallet,
          child: const _Unavailable(message: 'Financial data unavailable'));
    }
    final revenue  = (data!['revenue_mtd']  ?? 0).toDouble();
    final expenses = (data!['expenses_mtd'] ?? 0).toDouble();
    final profit   = (data!['profit_mtd']   ?? 0).toDouble();
    final margin   = (data!['margin_pct']   ?? 0).toDouble();
    final bills    = (data!['upcoming_bills'] as List? ?? []).cast<Map<String, dynamic>>();

    return _SectionCard(
      title: 'This Month',
      icon: Icons.account_balance_wallet,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _StatBox(label: 'Revenue', value: '\$${revenue.toStringAsFixed(0)}', color: kSuccess)),
          const SizedBox(width: 8),
          Expanded(child: _StatBox(label: 'Expenses', value: '\$${expenses.toStringAsFixed(0)}', color: kWarning)),
          const SizedBox(width: 8),
          Expanded(child: _StatBox(label: 'Profit', value: '\$${profit.toStringAsFixed(0)}', color: profit >= 0 ? kSuccess : kError)),
        ]),
        const SizedBox(height: 8),
        Text('Margin: ${margin.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, color: kTextMuted)),
        if (bills.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Upcoming Bills', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
          const SizedBox(height: 8),
          ...bills.take(3).map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: Text(b['vendor'] ?? '', style: const TextStyle(fontSize: 14))),
              Text(b['due_date'] ?? '', style: const TextStyle(fontSize: 12, color: kTextMuted)),
              const SizedBox(width: 12),
              Text('\$${(b['amount'] ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kWarning)),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ── Responses Section ─────────────────────────────────────────────────────────

class _ResponsesSection extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _ResponsesSection({this.data});

  @override
  Widget build(BuildContext context) {
    final calls = (data?['calls'] as List? ?? []).cast<Map<String, dynamic>>();
    final emails = (data?['needs_reply'] as List? ?? []).cast<Map<String, dynamic>>();

    return _SectionCard(
      title: 'Needs Attention',
      icon: Icons.inbox,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (calls.isEmpty && emails.isEmpty)
          const Text('All caught up! 🎉', style: TextStyle(color: kTextMuted, fontSize: 14)),

        if (calls.isNotEmpty) ...[
          const Text('Recent Calls', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
          const SizedBox(height: 8),
          ...calls.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.phone, size: 16, color: kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['caller'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (c['summary'] != null)
                  Text(c['summary'], style: const TextStyle(fontSize: 12, color: kTextMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          )),
        ],

        if (emails.isNotEmpty) ...[
          if (calls.isNotEmpty) const SizedBox(height: 12),
          const Text('Email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextMuted)),
          const SizedBox(height: 8),
          ...emails.take(3).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kWarning.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.mail_outline, size: 16, color: kWarning),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['from'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(e['subject'] ?? '', style: const TextStyle(fontSize: 12, color: kTextMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ── Social Section ────────────────────────────────────────────────────────────

class _SocialSection extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _SocialSection({this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null || data!['available'] != true) return const SizedBox.shrink();
    final posts = (data!['posts'] as List? ?? []).cast<Map<String, dynamic>>();
    if (posts.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Marketing Queue',
      icon: Icons.campaign,
      child: Column(children: posts.take(3).map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          _StatusChip(p['status'] ?? ''),
          const SizedBox(width: 10),
          Expanded(child: Text(p['copy'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      )).toList()),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: kPrimary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextDark)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: statCardDecoration(color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  Color get _color => switch (status) {
    'needs_review' => kWarning,
    'approved'     => kSuccess,
    'scheduled'    => kPrimary,
    _              => kTextMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final String message;
  const _Unavailable({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.info_outline, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(message, style: const TextStyle(color: kTextMuted, fontSize: 13)),
    ]);
  }
}
