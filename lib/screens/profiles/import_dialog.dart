import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/profile/profile_event.dart';
import '../../theme/app_theme.dart';

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _ctrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;
  bool _hasEncrypted = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onUriChanged() {
    final text = _ctrl.text.trim();
    final hasEncrypted = text.contains('slipnet-enc://');
    if (hasEncrypted != _hasEncrypted) {
      setState(() => _hasEncrypted = hasEncrypted);
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onUriChanged);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Import Profile'),
      content: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            'Paste slipnet:// or slipnet-enc:// links',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _ctrl,
            placeholder:
                'Paste one to 10 slipnet:// URIs (separated by newline or space)',
            placeholderStyle:
                const TextStyle(fontSize: 11, color: AppColors.dim),
            style: const TextStyle(fontSize: 12, color: AppColors.text),
            maxLines: 10,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          if (_hasEncrypted) ...[
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _passwordCtrl,
              placeholder: 'Password for encrypted profiles',
              placeholderStyle:
                  const TextStyle(fontSize: 11, color: AppColors.dim),
              style: const TextStyle(fontSize: 12, color: AppColors.text),
              obscureText: true,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoDialogAction(
          child: const Text('Import'),
          onPressed: () {
            final rawInput = _ctrl.text.trim();
            final password = _passwordCtrl.text.trim();
            final items = rawInput
                .split(RegExp(r'[\n\s]+'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

            if (items.isEmpty) {
              setState(() => _error = 'Paste at least one link');
              return;
            }

            final hasInvalid = items.any(
              (e) => !(e.startsWith('slipnet://') ||
                  e.startsWith('slipnet-enc://')),
            );

            if (hasInvalid) {
              setState(
                () => _error =
                    'Invalid link format. Use slipnet:// or slipnet-enc://',
              );
              return;
            }

            final hasEncrypted = items.any((e) => e.startsWith('slipnet-enc://'));
            if (hasEncrypted && password.isEmpty) {
              setState(() => _error = 'Password required for encrypted profiles');
              return;
            }

            final bloc = context.read<ProfileBloc>();
            for (final item in items) {
              if (item.startsWith('slipnet-enc://')) {
                bloc.add(ProfileImportedEncrypted(item, password));
              } else {
                bloc.add(ProfileImported(item));
              }
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
