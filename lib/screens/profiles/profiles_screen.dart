import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/services.dart';

import '../../models/profile.dart';
import '../../theme/app_colors.dart';
import '../../utils/slipnet_codec.dart';
import '../dns_scanner/dns_scanner_bloc.dart';
import '../dns_scanner/dns_scanner_screen.dart';
import 'profile_editor_screen.dart';
import 'profile_reachability_screen.dart';
import 'import_dialog.dart';
import 'export_sheet.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/profile/profile_event.dart';
import '../../blocs/profile/profile_state.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final Set<String> _selectedProfileIds = <String>{};
  bool _selectionMode = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.card,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Profiles'),
        backgroundColor: AppColors.surface,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectionMode)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _clearSelection,
                child: const Icon(CupertinoIcons.xmark_circle, size: 22),
              )
            else
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _selectionMode = true),
                child: const Icon(CupertinoIcons.check_mark_circled, size: 22),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showImportDialog(context),
              child: const Icon(CupertinoIcons.arrow_down_doc, size: 22),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _navigateToEditor(context),
              child: const Icon(CupertinoIcons.add, size: 22),
            ),
          ],
        ),
      ),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          final existingIds = state.profiles.map((p) => p.id).toSet();
          _selectedProfileIds.removeWhere((id) => !existingIds.contains(id));
          if (state.profiles.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildProfileList(context, state);
        },
      ),
    );
  }

  // ────────────────────────────────────────────
  // Empty state
  // ────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.person_2,
              size: 64, color: AppColors.muted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'No Profiles Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a profile, import slipnet:// links, or encrypted slipnet-enc:// links',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton.filled(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                onPressed: () => _navigateToEditor(context),
                child: const Text('Create Profile'),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                onPressed: () => _showImportDialog(context),
                child: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Profile list
  // ────────────────────────────────────────────

  Widget _buildProfileList(BuildContext context, ProfileState state) {
    return SafeArea(
      child: Column(
        children: [
          if (_selectionMode) _buildSelectionBar(context, state) else _buildActionsMenu(context, state),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final profile = state.profiles[index];
                final isActive = state.activeProfile?.id == profile.id;
                final isSelected = _selectedProfileIds.contains(profile.id);
                return _ProfileCard(
                  profile: profile,
                  isActive: isActive,
                  selectionMode: _selectionMode,
                  isSelected: isSelected,
                  onTap: () {
                    if (_selectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedProfileIds.remove(profile.id);
                        } else {
                          _selectedProfileIds.add(profile.id);
                        }
                      });
                    } else {
                      context.read<ProfileBloc>().add(ProfileActivated(profile));
                    }
                  },
                  onEdit: () => _navigateToEditor(context, profile: profile),
                  onExport: () => _showExportSheet(context, profile),
                  onDelete: () => _confirmDelete(context, profile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context, ProfileState state) {
    final selectedCount = _selectedProfileIds.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minSize: 28,
            onPressed: state.profiles.isEmpty
                ? null
                : () => setState(() {
                      if (_selectedProfileIds.length == state.profiles.length) {
                        _selectedProfileIds.clear();
                      } else {
                        _selectedProfileIds
                          ..clear()
                          ..addAll(state.profiles.map((p) => p.id));
                      }
                    }),
            child: Text(
              _selectedProfileIds.length == state.profiles.length
                  ? 'Clear'
                  : 'All',
            ),
          ),
          const SizedBox(width: 6),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onPressed: selectedCount == 0 ? null : () => _addDnsToSelected(context, state),
            child: const Text('Add DNS'),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            onPressed: selectedCount == 0 ? null : () => _showSelectedActionsMenu(context, state),
            child: const Icon(CupertinoIcons.ellipsis, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(BuildContext context, ProfileState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: state.profiles.isEmpty ? null : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        onPressed: state.profiles.isEmpty ? null : () => _showAllActionsMenu(context, state),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.ellipsis, size: 20),
            SizedBox(width: 8),
            Text('Actions'),
          ],
        ),
      ),
    );
  }

  void _showAllActionsMenu(BuildContext context, ProfileState state) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Ping All'),
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToReachabilityScreen(context, state.profiles);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Test Reachability All'),
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToReachabilityScreen(context, state.profiles);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Export All'),
            onPressed: () {
              Navigator.of(context).pop();
              _exportAllProfiles(context, state);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Delete Duplicates'),
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteDuplicates(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete All'),
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteAll(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showSelectedActionsMenu(BuildContext context, ProfileState state) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Ping Selected'),
            onPressed: () {
              Navigator.of(context).pop();
              _pingSelectedProfiles(context, state);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Test Reachability Selected'),
            onPressed: () {
              Navigator.of(context).pop();
              _pingSelectedProfiles(context, state);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Export Selected'),
            onPressed: () {
              Navigator.of(context).pop();
              _exportSelectedProfiles(context, state);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete Selected'),
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteSelected(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete All'),
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteAll(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _navigateToReachabilityScreen(BuildContext context, List<Profile> profiles) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProfilesReachabilityScreen(profiles: profiles),
      ),
    );
  }

  void _pingSelectedProfiles(BuildContext context, ProfileState state) {
    final selected = state.profiles.where((p) => _selectedProfileIds.contains(p.id)).toList();
    if (selected.isEmpty) return;
    _navigateToReachabilityScreen(context, selected);
  }

  void _confirmDeleteDuplicates(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Duplicates'),
        content: const Text(
          'Remove duplicate profiles and keep the first occurrence of each unique profile.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop();
              context.read<ProfileBloc>().add(const ProfileDeletedDuplicates());
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete All Profiles'),
        content: const Text(
          'Permanently delete all profiles from the app. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete All'),
            onPressed: () {
              Navigator.of(context).pop();
              context.read<ProfileBloc>().add(const ProfileDeletedAll());
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Selected Profiles'),
        content: Text(
          'Permanently delete ${_selectedProfileIds.length} profile(s). This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSelectedProfiles(context);
            },
          ),
        ],
      ),
    );
  }

  void _deleteSelectedProfiles(BuildContext context) {
    for (final id in _selectedProfileIds) {
      context.read<ProfileBloc>().add(ProfileDeleted(id));
    }
    setState(() {
      _selectedProfileIds.clear();
    });
  }

  Future<void> _exportAllProfiles(BuildContext context, ProfileState state) async {
    if (state.profiles.isEmpty) return;
    await _copyProfilesToClipboard(state.profiles);
    if (mounted) {
      setState(() => _selectionMode = false);
    }
  }

  Future<void> _exportSelectedProfiles(BuildContext context, ProfileState state) async {
    final selected = state.profiles.where((p) => _selectedProfileIds.contains(p.id)).toList();
    if (selected.isEmpty) return;
    await _copyProfilesToClipboard(selected);
    if (mounted) {
      setState(() => _selectionMode = false);
    }
  }

  Future<void> _copyProfilesToClipboard(List<Profile> profiles) async {
    try {
      final uris = profiles.map((p) => SlipnetCodec.encode(p)).toList();
      final text = uris.join('\n');
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Exported'),
            content: Text('${profiles.length} profile(s) copied to clipboard'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to copy to clipboard'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _addDnsToSelected(BuildContext context, ProfileState state) async {
    final targetProfiles = state.profiles.where((p) => _selectedProfileIds.contains(p.id)).toList();
    if (targetProfiles.isEmpty) return;

    final seedResolvers = targetProfiles
        .expand((p) => p.dnsResolver.split(RegExp(r'[\n,;\s]+')))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final selected = await Navigator.of(context).push<List<DnsScanResult>>(
      CupertinoPageRoute(
        builder: (_) => DnsScannerScreen(
          initialDomain: targetProfiles.first.domain.isEmpty ? 'example.com' : targetProfiles.first.domain,
          initialResolvers: seedResolvers,
          allowSelection: true,
        ),
      ),
    );

    if (!mounted || selected == null || selected.isEmpty) return;

    final pickedResolvers = selected.map((e) => e.resolver.trim()).where((e) => e.isNotEmpty).toSet();
    if (pickedResolvers.isEmpty) return;

    final bloc = context.read<ProfileBloc>();
    for (final profile in targetProfiles) {
      final current = profile.dnsResolver
          .split(RegExp(r'[\n,;\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      final merged = {...current, ...pickedResolvers};
      final firstProtocol = selected.first.protocol.toUpperCase();
      final transport = firstProtocol == 'DOH'
          ? DnsTransport.doh
          : firstProtocol == 'DOT'
              ? DnsTransport.dot
              : firstProtocol == 'TCP'
                  ? DnsTransport.tcp
                  : profile.dnsTransport;
      bloc.add(ProfileUpdated(profile.copyWith(
        dnsResolver: merged.join(','),
        dnsTransport: transport,
      )));
    }

    _showBulkUpdatedToast(targetProfiles.length, pickedResolvers.length);
  }

  void _showBulkUpdatedToast(int profileCount, int resolverCount) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Updated'),
        content: Text('Added $resolverCount DNS resolver(s) to $profileCount profile(s).'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedProfileIds.clear();
    });
  }

  // ────────────────────────────────────────────
  // Navigation
  // ────────────────────────────────────────────

  void _navigateToEditor(BuildContext context, {Profile? profile}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProfileBloc>(),
          child: ProfileEditorScreen(profile: profile),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Import dialog
  // ────────────────────────────────────────────

  void _showImportDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BlocProvider.value(
        value: context.read<ProfileBloc>(),
        child: const ImportDialog(),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Delete confirmation
  // ────────────────────────────────────────────

  void _confirmDelete(BuildContext context, Profile profile) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Delete "${profile.name}"? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              context.read<ProfileBloc>().add(ProfileDeleted(profile.id));
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExportSheet(BuildContext context, Profile profile) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => ExportSheet(profile: profile),
    );
  }
}

// ══════════════════════════════════════════════
// Profile Card Widget
// ══════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final bool isActive;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isActive ? AppColors.accent.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.accent.withOpacity(0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            // Lock / active indicator
            Icon(
              selectionMode
                  ? (isSelected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle)
                  : profile.isLocked
                      ? CupertinoIcons.lock_fill
                      : isActive
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
              color: profile.isLocked
                  ? (selectionMode
                      ? (isSelected ? AppColors.accent : AppColors.muted)
                      : CupertinoColors.systemOrange)
                  : selectionMode
                      ? (isSelected ? AppColors.accent : AppColors.muted)
                      : isActive
                          ? AppColors.accent
                          : AppColors.muted,
              size: 22,
            ),
            const SizedBox(width: 12),

            // Profile info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.isLocked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                CupertinoColors.systemOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LOCKED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.tunnelType.name}  •  '
                    '${profile.server}:${profile.port}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Actions
            if (!selectionMode) ...[
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: onEdit,
                child: const Icon(CupertinoIcons.pencil,
                    size: 18, color: AppColors.muted),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: onExport,
                child: const Icon(CupertinoIcons.share,
                    size: 18, color: AppColors.muted),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: onDelete,
                child: const Icon(CupertinoIcons.trash,
                    size: 18, color: CupertinoColors.destructiveRed),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
