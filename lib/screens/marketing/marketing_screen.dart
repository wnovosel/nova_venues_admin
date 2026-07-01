import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});
  @override State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getMarketingQueue();
      final list = (res['posts'] ?? res['queue'] ?? res['data']?['posts'] ?? []) as List;
      setState(() { _posts = list.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Marketing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              onRefresh: _load,
              color: kPrimary,
              child: _posts.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined, size: 48, color: kTextMuted),
                        SizedBox(height: 12),
                        Text('No posts in queue', style: TextStyle(color: kTextMuted, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Create content from the web admin', style: TextStyle(color: kTextMuted, fontSize: 13)),
                      ],
                    ))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final p = _posts[i];
                        final status = p['status'] ?? '';
                        final statusColor = switch (status) {
                          'needs_review' => kWarning,
                          'approved'     => kSuccess,
                          'scheduled'    => kPrimary,
                          _              => kTextMuted,
                        };

                        return Container(
                          decoration: cardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(_platformIcon(p['platform'] ?? ''), size: 18, color: kTextMuted),
                              const SizedBox(width: 8),
                              Text((p['platform'] ?? 'Post').toString().toUpperCase(),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextMuted)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(status.replaceAll('_', ' '),
                                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text(p['copy'] ?? '', style: const TextStyle(fontSize: 14, color: kTextDark)),
                            if (status == 'needs_review') ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: OutlinedButton(
                                  onPressed: () {},
                                  child: const Text('Edit'),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: ElevatedButton(
                                  onPressed: () {},
                                  child: const Text('Approve'),
                                )),
                              ]),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
    );
  }

  IconData _platformIcon(String platform) => switch (platform.toLowerCase()) {
    'instagram' => Icons.camera_alt_outlined,
    'facebook'  => Icons.facebook,
    'email'     => Icons.mail_outline,
    'sms'       => Icons.sms_outlined,
    _           => Icons.campaign_outlined,
  };
}
