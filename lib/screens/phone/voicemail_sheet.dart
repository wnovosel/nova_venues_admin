import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet for a single voicemail: listen to the recording and read the
/// full transcript.
///
/// Data comes from the dashboard/calls payload, which supplies:
///   recording_url / voicemail_url, voicemail_transcript, summary, intent,
///   caller_name, from_number, started_at, duration_seconds
Future<void> showVoicemailSheet(BuildContext context, Map<String, dynamic> call) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VoicemailSheet(call: call),
  );
}

class _VoicemailSheet extends StatefulWidget {
  final Map<String, dynamic> call;
  const _VoicemailSheet({required this.call});

  @override
  State<_VoicemailSheet> createState() => _VoicemailSheetState();
}

class _VoicemailSheetState extends State<_VoicemailSheet> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String get _url =>
      (widget.call['recording_url'] ?? widget.call['voicemail_url'] ?? '').toString();

  String get _transcript =>
      (widget.call['voicemail_transcript'] ?? widget.call['transcript'] ?? '')
          .toString()
          .trim();

  String get _summary => (widget.call['summary'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _position = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_url.isEmpty) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        setState(() { _loading = true; _error = null; });
        await _player.play(UrlSource(_url));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not play this recording.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final caller = (widget.call['caller_name'] ??
            widget.call['from_number'] ??
            'Unknown caller')
        .toString();
    final number = (widget.call['from_number'] ?? '').toString();
    final when = widget.call['started_at'];
    String whenText = '';
    try {
      if (when != null && when.toString().isNotEmpty) {
        whenText = DateFormat('EEE, MMM d · h:mm a')
            .format(DateTime.parse(when.toString()).toLocal());
      }
    } catch (_) {}

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(100)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.voicemail, color: kError),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(caller,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark)),
                      if (whenText.isNotEmpty || number.isNotEmpty)
                        Text(
                          [if (number.isNotEmpty && number != caller) number, whenText]
                              .where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(fontSize: 12, color: kTextMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Listen ──
            if (_url.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _loading ? null : _toggle,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 46, height: 46,
                        decoration: const BoxDecoration(
                            color: kPrimary, shape: BoxShape.circle),
                        child: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(_playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_duration.inMilliseconds > 0)
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              ),
                              child: Slider(
                                value: _position.inMilliseconds
                                    .clamp(0, _duration.inMilliseconds)
                                    .toDouble(),
                                max: _duration.inMilliseconds.toDouble(),
                                activeColor: kPrimary,
                                inactiveColor: kBorder,
                                onChanged: (v) => _player
                                    .seek(Duration(milliseconds: v.round())),
                              ),
                            )
                          else
                            const Text('Tap play to listen',
                                style: TextStyle(fontSize: 12, color: kTextMuted)),
                          if (_duration.inMilliseconds > 0)
                            Text('${_fmtDur(_position)} / ${_fmtDur(_duration)}',
                                style: const TextStyle(fontSize: 11, color: kTextMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 12, color: kError)),
              ],
              const SizedBox(height: 18),
            ],

            // ── Read ──
            const Text('TRANSCRIPT',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: kTextMuted, letterSpacing: 1)),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  _transcript.isNotEmpty
                      ? _transcript
                      : (_summary.isNotEmpty
                          ? _summary
                          : 'No transcript available for this voicemail. Play the recording to listen.'),
                  style: TextStyle(
                    fontSize: 15, height: 1.55,
                    color: (_transcript.isEmpty && _summary.isEmpty)
                        ? kTextMuted : kTextDark,
                    fontStyle: (_transcript.isEmpty && _summary.isEmpty)
                        ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),

            if (_transcript.isNotEmpty && _summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('SUMMARY',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: kTextMuted, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(_summary,
                  style: const TextStyle(fontSize: 13, color: kTextMuted, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}
