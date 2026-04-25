import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/profile.dart';
import '../../utils/slipnet_codec.dart';
import '../../theme/app_theme.dart';

class ExportSheet extends StatefulWidget {
  final Profile profile;
  const ExportSheet({super.key, required this.profile});

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final _passwordCtrl = TextEditingController();
  bool _encrypt = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _uri {
    if (_encrypt) {
      final password = _passwordCtrl.text.trim();
      if (password.isNotEmpty) {
        return SlipnetCodec.encodeEncrypted(widget.profile, password);
      }
    }
    return SlipnetCodec.encode(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
    final uri = _uri;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Export "${widget.profile.name}"',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: _encrypt ? AppColors.primary : AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => setState(() => _encrypt = !_encrypt),
                  child: Text(
                    _encrypt ? 'Encrypted Export On' : 'Encrypted Export Off',
                    style: TextStyle(
                      color: _encrypt ? CupertinoColors.white : AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_encrypt) ...[
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _passwordCtrl,
              obscureText: true,
              placeholder: 'Password for slipnet-enc://',
              padding: const EdgeInsets.all(10),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: uri,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: CupertinoColors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Color(0xFF111827),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // URI preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              uri.length > 80 ? '${uri.substring(0, 80)}…' : uri,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'SF Mono',
                color: AppColors.muted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: CupertinoIcons.doc_on_clipboard,
                  label: 'Copy Link',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: uri));
                    Navigator.pop(context);
                    _showToast(context, 'Link copied');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionBtn(
                  icon: CupertinoIcons.share,
                  label: 'Share',
                  isPrimary: true,
                  onTap: () => _shareProfile(uri),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showToast(BuildContext context, String msg) {
    // ساده — بعدا می‌تونی overlay toast بذاری
  }

  Future<void> _shareProfile(String uri) async {
    final decodedUrl = widget.profile.toSlipnetUri();
    final text = '''
DNSly Profile: ${widget.profile.name}

Decoded URL:
$decodedUrl

Encoded URL:
$uri
''';

    try {
      final qrBytes = await _buildQrPng(uri);
      final file = XFile.fromData(
        qrBytes,
        mimeType: 'image/png',
        name: '${widget.profile.name}_qr.png',
      );
      await Share.shareXFiles(
        [file],
        text: text,
        subject: 'DNSly Profile: ${widget.profile.name}',
      );
    } catch (_) {
      await Share.share(
        text,
        subject: 'DNSly Profile: ${widget.profile.name}',
      );
    }
  }

  Future<Uint8List> _buildQrPng(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.circle,
        color: Color(0xFF111827),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.circle,
        color: Color(0xFF111827),
      ),
      gapless: true,
    );

    final imageData = await painter.toImageData(
      1024,
      format: ui.ImageByteFormat.png,
    );
    if (imageData == null) {
      throw StateError('QR image generation failed');
    }
    return imageData.buffer.asUint8List();
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.connectGradient : null,
          color: isPrimary ? null : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isPrimary ? CupertinoColors.white : AppColors.muted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? CupertinoColors.white : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
