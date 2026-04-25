import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/profile/profile_event.dart';
import '../../utils/slipnet_codec.dart';
import '../../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Scan QR Code'),
        backgroundColor: AppColors.accent.withOpacity(0.9),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.bolt, size: 20),
          onPressed: () => _controller.toggleTorch(),
        ),
      ),
      child: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary, width: 2.5),
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Point camera at a slipnet:// QR code',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    if (!SlipnetCodec.isValid(raw)) {
      _showError('Not a valid slipnet:// link');
      return;
    }

    // Encrypted QR codes are allowed: they import as a locked profile.
    final profile =
        SlipnetCodec.isEncrypted(raw) ? null : SlipnetCodec.decode(raw);

    setState(() => _scanned = true);
    context.read<ProfileBloc>().add(ProfileImported(raw));

    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Profile Imported'),
        content: Text(
          profile == null
              ? 'Encrypted profile added (locked).'
              : '"${profile.name}" added successfully',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // scanner
            },
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Scan Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
