import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});
  @override State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _snapping = false;
  bool _archiving = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppProvider>().api.getMarketingQueue();
      setState(() {
        _posts = (res['posts'] as List? ?? []).cast<Map<String,dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsReview = _posts.where((p) => p['status'] == 'needs_review').toList();
    final scheduled   = _posts.where((p) => p['status'] == 'scheduled').toList();
    final approved    = _posts.where((p) => p['status'] == 'approved').toList();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('Marketing${needsReview.isEmpty ? '' : ' (${needsReview.length})'}'),
      ),
      body: Column(children: [
        // ── Top action bar ──────────────────────────────────────────────────
        Container(
          color: kSurface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: _SnapButton(
                icon: Icons.camera_alt,
                label: 'Snap & Post',
                color: kPrimary,
                loading: _snapping,
                onTap: () => _snapPost(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SnapButton(
                icon: Icons.archive_outlined,
                label: 'Snap & Archive',
                color: kTextMuted,
                loading: _archiving,
                onTap: () => _snapArchive(context),
              ),
            ),
          ]),
        ),

        // ── Posts list ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kPrimary,
                  child: _posts.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.campaign_outlined, size: 48, color: kBorder),
                          SizedBox(height: 12),
                          Text('No posts in queue', style: TextStyle(color: kTextMuted, fontSize: 16)),
                        ]))
                      : ListView(padding: const EdgeInsets.all(16), children: [
                          if (needsReview.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Needs Review',
                              count: needsReview.length,
                              color: kWarning,
                            ),
                            const SizedBox(height: 8),
                            ...needsReview.map((p) => _PostCard(post: p, onRefresh: _load)),
                            const SizedBox(height: 20),
                          ],
                          if (scheduled.isNotEmpty) ...[
                            _SectionHeader(title: 'Scheduled', count: scheduled.length, color: kPrimary),
                            const SizedBox(height: 8),
                            ...scheduled.map((p) => _PostCard(post: p, onRefresh: _load)),
                            const SizedBox(height: 20),
                          ],
                          if (approved.isNotEmpty) ...[
                            _SectionHeader(title: 'Approved', count: approved.length, color: kSuccess),
                            const SizedBox(height: 8),
                            ...approved.map((p) => _PostCard(post: p, onRefresh: _load)),
                          ],
                        ]),
                ),
        ),
      ]),
    );
  }

  Future<void> _snapPost(BuildContext context) async {
    // Show platform picker first
    final platform = await _pickPlatform(context);
    if (platform == null) return;

    setState(() => _snapping = true);
    try {
      // Get presigned upload URL
      final api = context.read<AppProvider>().api;
      final urlRes = await api.getR2UploadUrl();
      final uploadUrl = urlRes['upload_url'] as String?;
      final publicUrl = urlRes['public_url'] as String?;

      if (uploadUrl == null) {
        _showError('Upload URL unavailable');
        return;
      }

      // Pick image from camera
      final imageBytes = await _pickFromCamera(context);
      if (imageBytes == null) return;

      // Upload to R2
      await api.uploadToR2(uploadUrl, imageBytes);

      // Generate caption and queue
      final res = await api.snapPost(publicUrl!, platform, 'queue');

      if (mounted) {
        _showSuccess('Post queued for review!\n"${(res['caption'] ?? '').toString().substring(0, (res['caption'] ?? '').toString().length.clamp(0, 60))}..."');
        _load();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _snapping = false);
    }
  }

  Future<void> _snapArchive(BuildContext context) async {
    setState(() => _archiving = true);
    try {
      final api = context.read<AppProvider>().api;
      final urlRes = await api.getR2UploadUrl();
      final uploadUrl = urlRes['upload_url'] as String?;
      final publicUrl = urlRes['public_url'] as String?;

      if (uploadUrl == null) { _showError('Upload URL unavailable'); return; }

      final imageBytes = await _pickFromCamera(context);
      if (imageBytes == null) return;

      await api.uploadToR2(uploadUrl, imageBytes);
      final res = await api.snapArchive(publicUrl!);

      if (mounted) {
        _showSuccess('Archived as "${res['name']}"\nCategory: ${res['category']}');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Future<String?> _pickPlatform(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Post to...', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          for (final p in ['instagram', 'facebook', 'email', 'sms'])
            ListTile(
              leading: Icon(_platformIcon(p), color: kPrimary),
              title: Text(p[0].toUpperCase() + p.substring(1)),
              onTap: () => Navigator.pop(context, p),
            ),
        ]),
      ),
    );
  }

  Future<List<int>?> _pickFromCamera(BuildContext context) async {
    // In production: use image_picker. For now show placeholder.
    _showError('Camera requires image_picker plugin — add to pubspec and rebuild via Xcode Cloud');
    return null;
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: kSuccess,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: kError,
      behavior: SnackBarBehavior.floating,
    ));
  }

  IconData _platformIcon(String p) => switch (p) {
    'instagram' => Icons.camera_alt_outlined,
    'facebook'  => Icons.facebook,
    'email'     => Icons.mail_outline,
    'sms'       => Icons.sms_outlined,
    _           => Icons.campaign_outlined,
  };
}

// ── Snap button ───────────────────────────────────────────────────────────────

class _SnapButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _SnapButton({required this.icon, required this.label,
    required this.color, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: loading
            ? Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    ),
  ]);
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onRefresh;
  const _PostCard({required this.post, required this.onRefresh});

  Color get _statusColor => switch (post['status'] ?? '') {
    'needs_review' => kWarning,
    'approved'     => kSuccess,
    'scheduled'    => kPrimary,
    _              => kTextMuted,
  };

  IconData _platformIcon(String p) => switch (p.toLowerCase()) {
    'instagram' => Icons.camera_alt_outlined,
    'facebook'  => Icons.facebook,
    'email'     => Icons.mail_outline,
    'sms'       => Icons.sms_outlined,
    _           => Icons.campaign_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final status   = post['status'] ?? '';
    final platform = post['platform'] ?? '';
    final copy     = post['copy'] ?? '';
    final scheduled = post['scheduled_for'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_platformIcon(platform), size: 16, color: kTextMuted),
          const SizedBox(width: 6),
          Text(platform.isEmpty ? 'Post' : platform[0].toUpperCase() + platform.substring(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextMuted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status.replaceAll('_', ' '),
                style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w600)),
          ),
        ]),

        if (post['image_url'] != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(post['image_url'], height: 160, width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 80, color: kBorder,
                child: const Center(child: Icon(Icons.image_not_supported, color: kTextMuted))),
            ),
          ),
        ],

        const SizedBox(height: 10),
        Text(copy, style: const TextStyle(fontSize: 14, color: kTextDark, height: 1.4)),

        if (scheduled != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.schedule, size: 12, color: kTextMuted),
            const SizedBox(width: 4),
            Text(_formatDate(scheduled), style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ],

        // Approve button for needs_review
        if (status == 'needs_review') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('Edit', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => _approve(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 13)),
            )),
          ]),
        ],
      ]),
    );
  }

  Future<void> _approve(BuildContext context) async {
    await context.read<AppProvider>().api.approvePost(post['id']);
    onRefresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post approved ✓'), backgroundColor: kSuccess,
        behavior: SnackBarBehavior.floating));
  }
}

String _formatDate(dynamic val) {
  if (val == null) return '';
  try {
    return DateFormat('MMM d, h:mm a').format(DateTime.parse(val.toString()).toLocal());
  } catch (_) { return val.toString(); }
}
