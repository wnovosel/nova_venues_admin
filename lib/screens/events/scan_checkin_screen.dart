import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/app_provider.dart';
import '../../theme/app_theme.dart';

/// Door check-in: scan a ticket QR and check the guest in.
///
/// Backend contract (mobile_api.py::admin_scan_checkin):
///   POST /admin/events/scan-checkin {token}
///   -> {checked_in, already_checked_in, name, event_name, quantity}
/// The token may be a bare UUID or a full ticket URL — the backend handles both.
class ScanCheckinScreen extends StatefulWidget {
  final String? eventName;
  const ScanCheckinScreen({super.key, this.eventName});

  @override
  State<ScanCheckinScreen> createState() => _ScanCheckinScreenState();
}

class _ScanCheckinScreenState extends State<ScanCheckinScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _busy = false;
  String? _lastToken;
  int _scannedCount = 0;

  // Result of the most recent scan, shown as a full-width banner.
  String? _resultName;
  String? _resultDetail;
  _ResultKind _resultKind = _ResultKind.none;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.trim().isEmpty) return;
    final token = raw.trim();
    // Guard against the same ticket firing repeatedly while it sits in frame.
    if (token == _lastToken) return;

    setState(() { _busy = true; _lastToken = token; });

    try {
      final api = context.read<AppProvider>().api;
      final res = await api.scanCheckin(token);
      final already = res['already_checked_in'] == true;
      final name = (res['name'] ?? 'Guest').toString();
      final qty = res['quantity'];
      final eventName = (res['event_name'] ?? '').toString();

      setState(() {
        _resultKind = already ? _ResultKind.duplicate : _ResultKind.success;
        _resultName = name;
        _resultDetail = [
          if (qty != null) '$qty ticket${qty == 1 ? '' : 's'}',
          if (eventName.isNotEmpty) eventName,
        ].join(' · ');
        if (!already) _scannedCount++;
      });
    } catch (e) {
      setState(() {
        _resultKind = _ResultKind.error;
        _resultName = 'Not recognized';
        _resultDetail = e.toString().replaceFirst('ApiException: ', '');
      });
    } finally {
      // Brief cooldown so the operator can read the result before the next scan.
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearLast() => setState(() {
        _lastToken = null;
        _resultKind = _ResultKind.none;
        _resultName = null;
        _resultDetail = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.eventName ?? 'Scan Tickets',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 44),
                    const SizedBox(height: 12),
                    const Text('Camera unavailable',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Grant camera access in Settings, or check in guests manually from the attendee list.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Aiming frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),

          // Running count
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('$_scannedCount checked in',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),

          // Result banner
          if (_resultKind != _ResultKind.none)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _ResultBanner(
                kind: _resultKind,
                name: _resultName ?? '',
                detail: _resultDetail ?? '',
                onDismiss: _clearLast,
              ),
            ),
        ],
      ),
    );
  }
}

enum _ResultKind { none, success, duplicate, error }

class _ResultBanner extends StatelessWidget {
  final _ResultKind kind;
  final String name;
  final String detail;
  final VoidCallback onDismiss;

  const _ResultBanner({
    required this.kind,
    required this.name,
    required this.detail,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final IconData icon;
    late final String label;
    switch (kind) {
      case _ResultKind.success:
        bg = kSuccess; icon = Icons.check_circle_outline; label = 'Checked in';
        break;
      case _ResultKind.duplicate:
        bg = kWarning; icon = Icons.info_outline; label = 'Already checked in';
        break;
      case _ResultKind.error:
        bg = kError; icon = Icons.error_outline; label = 'Scan failed';
        break;
      case _ResultKind.none:
        bg = kSurface; icon = Icons.qr_code; label = '';
        break;
    }

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800,
                          letterSpacing: .6)),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  if (detail.isNotEmpty)
                    Text(detail,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
