import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/admin_api.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final _picker = ImagePicker();
  final _mediaSearch = TextEditingController();

  late final TabController _tabs;
  List<Map<String, dynamic>> _posts = const [];
  List<Map<String, dynamic>> _media = const [];
  bool _loadingQueue = true;
  bool _loadingMedia = false;
  bool _working = false;
  String? _queueError;
  String? _mediaError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadQueue();
    _loadMedia();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _mediaSearch.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await _storage.read(key: 'admin_token');
    if (token == null || token.isEmpty) {
      throw const ApiException('Your session has expired. Please sign in again.');
    }
    return token;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = decoded.cast<String, dynamic>();
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        (body['error'] ?? body['message'] ?? 'Request failed (${response.statusCode})')
            .toString(),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(
      Uri.parse('$kApiBase$path'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    ).timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$kApiBase$path'),
          headers: {
            'Authorization': 'Bearer ${await _token()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _multipart(
    String path,
    List<XFile> files, {
    required String field,
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$kApiBase$path'));
    request.headers['Authorization'] = 'Bearer ${await _token()}';
    request.fields.addAll(fields);
    for (final file in files) {
      request.files.add(http.MultipartFile.fromBytes(
        field,
        await File(file.path).readAsBytes(),
        filename: file.name.isEmpty ? 'photo.jpg' : file.name,
      ));
    }
    final streamed = await request.send().timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<void> _loadQueue() async {
    if (mounted) {
      setState(() {
        _loadingQueue = true;
        _queueError = null;
      });
    }
    try {
      final response = await context.read<AppProvider>().api.getMarketingQueue();
      final posts = (response['posts'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      if (mounted) setState(() => _posts = posts);
    } catch (error) {
      if (mounted) setState(() => _queueError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingQueue = false);
    }
  }

  Future<void> _loadMedia([String? query]) async {
    if (mounted) {
      setState(() {
        _loadingMedia = true;
        _mediaError = null;
      });
    }
    try {
      final q = (query ?? _mediaSearch.text).trim();
      final response = await _get(
          '/api/v1/marketing/media${q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}');
      final raw = response['media'] ?? response['items'] ?? response['uploaded'];
      final items = (raw as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      if (mounted) setState(() => _media = items);
    } catch (error) {
      if (mounted) setState(() => _mediaError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  Future<void> _snapAndPost() async {
    final setup = await _showSnapSetup();
    if (setup == null) return;
    final source = await _pickSource();
    if (source == null) return;
    final image = await _picker.pickImage(source: source, imageQuality: 88);
    if (image == null) return;

    setState(() => _working = true);
    try {
      final response = await _multipart(
        '/api/v1/marketing/snap',
        [image],
        field: 'photo',
        fields: {
          'platform': setup.$1,
          if (setup.$2.trim().isNotEmpty) 'instruction': setup.$2.trim(),
        },
      );
      if (!mounted) return;
      await _showPreview(response);
      await _loadQueue();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<(String, String)?> _showSnapSetup() async {
    var platform = 'instagram';
    final instruction = TextEditingController();
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Snap & Post',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Nova will study the photo and write an on-brand caption.'),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'instagram', label: Text('Instagram')),
                  ButtonSegment(value: 'facebook', label: Text('Facebook')),
                ],
                selected: {platform},
                onSelectionChanged: (value) =>
                    setSheetState(() => platform = value.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: instruction,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Optional direction',
                  hintText: 'Example: Focus on the sunset and invite people this weekend',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Choose photo'),
                  onPressed: () =>
                      Navigator.pop(context, (platform, instruction.text)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    instruction.dispose();
    return result;
  }

  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Photos'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ]),
        ),
      );

  Future<void> _showPreview(Map<String, dynamic> post) async {
    final id = int.tryParse('${post['queue_id']}');
    if (id == null) throw const ApiException('Nova did not return a queue ID.');
    final caption = TextEditingController(text: '${post['caption'] ?? ''}');
    final imageUrl = '${post['image_url'] ?? ''}';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              18, 2, 18, 22 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ready to publish',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(imageUrl,
                        height: 230, width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: caption,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                await _postJson(
                                    '/api/v1/marketing/snap/$id/reject', {});
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                _success('Post rejected');
                              } catch (error) {
                                _error(error);
                                setSheetState(() => saving = false);
                              }
                            },
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                await _postJson(
                                  '/api/v1/marketing/snap/$id/approve',
                                  {'caption': caption.text.trim()},
                                );
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                _success('Approved — publishes within about 5 minutes');
                              } catch (error) {
                                _error(error);
                                setSheetState(() => saving = false);
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.rocket_launch_rounded),
                      label: const Text('Approve & Publish'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    caption.dispose();
  }

  Future<void> _saveToLibrary() async {
    final files = await _picker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;
    setState(() => _working = true);
    try {
      final response = await _multipart(
        '/api/v1/marketing/media',
        files,
        field: 'photos',
      );
      final uploaded = (response['uploaded'] as List? ?? const []).length;
      final errors = (response['errors'] as List? ?? const []).length;
      _success('$uploaded photo${uploaded == 1 ? '' : 's'} saved to the library${errors > 0 ? ' · $errors failed' : ''}');
      _tabs.animateTo(1);
      await _loadMedia();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _success(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: kSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error.toString().replaceFirst('ApiException: ', '')),
      backgroundColor: kError,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final needsReview = _posts.where((p) => p['status'] == 'needs_review').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: needsReview == 0 ? 'Queue' : 'Queue ($needsReview)'),
            const Tab(text: 'Media Library'),
          ],
        ),
      ),
      body: Stack(children: [
        TabBarView(
          controller: _tabs,
          children: [_queueTab(), _libraryTab()],
        ),
        if (_working)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: .24),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ]),
    );
  }

  Widget _queueTab() => RefreshIndicator(
        onRefresh: _loadQueue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              sliver: SliverToBoxAdapter(
                child: _MarketingHero(
                  onSnap: _snapAndPost,
                  onLibrary: _saveToLibrary,
                ),
              ),
            ),
            if (_loadingQueue)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_queueError != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_queueError!, textAlign: TextAlign.center),
                  ),
                ),
              )
            else if (_posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Your marketing queue is clear.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                sliver: SliverList.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, index) => _PostCard(
                    post: _posts[index],
                    onRefresh: _loadQueue,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _libraryTab() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _mediaSearch,
            textInputAction: TextInputAction.search,
            onSubmitted: _loadMedia,
            decoration: InputDecoration(
              hintText: 'Search photos: sunset, wine, festival…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                tooltip: 'Add photos',
                onPressed: _saveToLibrary,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        if (_mediaError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_mediaError!, style: const TextStyle(color: kError)),
          ),
        Expanded(
          child: _loadingMedia
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadMedia,
                  child: _media.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 140),
                          Icon(Icons.photo_library_outlined,
                              size: 56, color: kTextMuted),
                          SizedBox(height: 12),
                          Center(child: Text('No matching photos yet')),
                        ])
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: .86,
                          ),
                          itemCount: _media.length,
                          itemBuilder: (context, index) =>
                              _MediaCard(item: _media[index]),
                        ),
                ),
        ),
      ]);
}

class _MarketingHero extends StatelessWidget {
  const _MarketingHero({required this.onSnap, required this.onLibrary});
  final VoidCallback onSnap;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Create in the moment',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimary, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Take a photo. Nova writes the post. You approve it.',
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: .82))),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimary,
                  foregroundColor: scheme.primary),
              onPressed: onSnap,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Snap & Post'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Save photos to library',
            onPressed: onLibrary,
            icon: const Icon(Icons.collections_rounded),
          ),
        ]),
      ]),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onRefresh});
  final Map<String, dynamic> post;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = '${post['status'] ?? ''}';
    final platform = '${post['platform'] ?? 'Post'}';
    final copy = '${post['copy'] ?? post['caption'] ?? ''}';
    final image = '${post['image_url'] ?? ''}';
    final color = status == 'needs_review'
        ? kWarning
        : status == 'approved'
            ? kSuccess
            : kPrimary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image.isNotEmpty)
          Image.network(image,
              height: 190, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(platform.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.replaceAll('_', ' '),
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(copy, style: const TextStyle(height: 1.4)),
            if (post['scheduled_for'] != null) ...[
              const SizedBox(height: 8),
              Text(_formatDate(post['scheduled_for']),
                  style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ],
            if (status == 'needs_review') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await context
                          .read<AppProvider>()
                          .api
                          .approvePost(post['id']);
                      await onRefresh();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Post approved'),
                            backgroundColor: kSuccess));
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(error.toString()),
                            backgroundColor: kError));
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final url = '${item['url'] ?? item['image_url'] ?? ''}';
    final label = '${item['label'] ?? 'Photo'}';
    final tags = item['tags'] is List
        ? (item['tags'] as List).join(', ')
        : '${item['tags'] ?? ''}';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: url.isEmpty
              ? const Center(child: Icon(Icons.image_outlined))
              : Image.network(url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_outlined))),
        ),
        Padding(
          padding: const EdgeInsets.all(9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (tags.isNotEmpty)
              Text(tags,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ),
      ]),
    );
  }
}

String _formatDate(dynamic value) {
  if (value == null) return '';
  try {
    return DateFormat('MMM d, h:mm a')
        .format(DateTime.parse(value.toString()).toLocal());
  } catch (_) {
    return value.toString();
  }
}
