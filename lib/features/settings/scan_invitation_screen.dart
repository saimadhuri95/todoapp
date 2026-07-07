import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef InvitationScannerBuilder =
    Widget Function(
      BuildContext context,
      MobileScannerController controller,
      void Function(String value) onValue,
    );

/// Camera QR scanner for pairing invitations (TASKS.md 6.1). Pops with the
/// first decoded QR payload; validation happens in the caller's accept flow,
/// so a wrong QR (someone's Wi-Fi code) fails with the normal error message.
class ScanInvitationScreen extends StatefulWidget {
  const ScanInvitationScreen({super.key, this.scannerBuilder});

  final InvitationScannerBuilder? scannerBuilder;

  @override
  State<ScanInvitationScreen> createState() => _ScanInvitationScreenState();
}

class _ScanInvitationScreenState extends State<ScanInvitationScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  var _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return; // onDetect keeps firing while the sheet pops
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _acceptValue(value);
  }

  void _acceptValue(String value) {
    if (_done || value.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan invitation')),
    body: Stack(
      alignment: Alignment.center,
      children: [
        widget.scannerBuilder?.call(context, _controller, _acceptValue) ??
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Camera unavailable: ${error.errorDetails?.message ?? error.errorCode.name}.\n\n'
                    'Check the camera permission for Knot in system settings, '
                    'or use "Enter invitation" to paste the text instead.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        // Aiming frame so users know roughly where to hold the code.
        IgnorePointer(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    ),
  );
}
