import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../theme/app_colors.dart';
import '../../theme/app_defaults.dart';
import '../../models/dns_record_type.dart';
import '../../models/profile.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/profile/profile_event.dart';
import '../profiles/widgets/record_type_picker.dart';
import 'dns_scanner_bloc.dart';

class DnsScannerScreen extends StatefulWidget {
  final String? initialDomain;
  final List<String>? initialResolvers;
  final bool allowSelection;

  const DnsScannerScreen({
    super.key,
    this.initialDomain,
    this.initialResolvers,
    this.allowSelection = false,
  });

  @override
  State<DnsScannerScreen> createState() => _DnsScannerScreenState();
}

class _DnsScannerScreenState extends State<DnsScannerScreen> {
  late final TextEditingController _domainCtrl;
  final _resolversCtrl = TextEditingController();
  bool _shuffleResolvers = false;
  bool _verifyHttp = false;
  bool _verifySsh = false;
  bool _showOnlyWorking = true;
  _DnsResultSort _sortBy = _DnsResultSort.speed;
  bool _sortAscending = true;
  final Set<String> _selectedResults = <String>{};
  bool _addToProfileMode = false;
  final Set<ScanProtocol> _scanProtocols = {ScanProtocol.udp};
  DnsRecordType _recordType = DnsRecordType.txt;
  final _queryLengthCtrl = TextEditingController(text: '101');

  static const _defaultResolvers = [
    '1.1.1.1',
    '1.0.0.1',
    '8.8.8.8',
    '8.8.4.4',
    '9.9.9.9',
    '208.67.222.222',
    '185.228.168.9',
    '76.76.19.19',
    'https://cloudflare-dns.com/dns-query',
    'https://dns.google/dns-query',
  ];

  @override
  void initState() {
    super.initState();
    _domainCtrl = TextEditingController(text: widget.initialDomain ?? 'example.com');
    final seedResolvers = widget.initialResolvers ?? _defaultResolvers;
    _resolversCtrl.text = seedResolvers.join('\n');
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _resolversCtrl.dispose();
    _queryLengthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DnsScannerBloc(),
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.scaffold,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppColors.surface.withOpacity(0.9),
          border: const Border(
            bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
          ),
          middle: const Text('DNS Scanner',
              style: TextStyle(color: AppColors.textPrimary)),
        ),
        child: SafeArea(
          child: BlocBuilder<DnsScannerBloc, DnsScannerState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildDomainInput(context, state),
                  const SizedBox(height: 16),
                  _buildResolversInput(),
                  const SizedBox(height: 16),
                  _buildScanOptions(),
                  const SizedBox(height: 16),
                  _buildRecordAndLength(),
                  const SizedBox(height: 16),
                  _buildProgressSection(state),
                  if (state.bestResult != null) ...[
                    const SizedBox(height: 16),
                    _buildBestResult(state.bestResult!),
                  ],
                  if (state.results.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildResultsList(state),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Domain Input + Start/Stop ──
  Widget _buildDomainInput(BuildContext context, DnsScannerState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.search, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Test Domain',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: _domainCtrl,
            placeholder: 'example.com',
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffold,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontFamily: 'SF Mono',
            ),
            placeholderStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            enabled: !state.isScanning,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 13),
              borderRadius: BorderRadius.circular(12),
              color: state.isScanning ? AppColors.error : AppColors.primary,
              onPressed: () {
                final bloc = context.read<DnsScannerBloc>();
                if (state.isScanning) {
                  bloc.add(DnsScanStopped());
                } else {
                  final resolvers = _parseResolvers(_resolversCtrl.text);
                  if (resolvers.isEmpty) {
                    _showError('Please add at least one resolver.');
                    return;
                  }
                  bloc.add(DnsScanStarted(
                    domain: _domainCtrl.text.trim(),
                    resolvers: resolvers,
                    shuffleResolvers: _shuffleResolvers,
                    verifyHttp: _verifyHttp,
                    verifySsh: _verifySsh,
                    protocols: _scanProtocols,
                    recordType: _recordType,
                    queryLength: int.tryParse(_queryLengthCtrl.text.trim()) ?? 101,
                  ));
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    state.isScanning
                        ? CupertinoIcons.stop_fill
                        : CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isScanning ? 'Stop Scan' : 'Start Scan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolversInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resolvers (one per line)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: _resolversCtrl,
            maxLines: 6,
            minLines: 4,
            padding: const EdgeInsets.all(12),
            placeholder: '1.1.1.1\n8.8.8.8',
            decoration: BoxDecoration(
              color: AppColors.scaffold,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'SF Mono'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _importFromTxt,
                  child: const Text('Import TXT', style: TextStyle(color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => _resolversCtrl.text = _defaultResolvers.join('\n'),
                  child: const Text('Use Default', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildScanOptions() {
    Widget tile(String title, bool value, ValueChanged<bool> onChanged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(color: AppColors.textSecondary))),
            CupertinoSwitch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan Protocols',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ScanProtocol.values.map((p) {
              final selected = _scanProtocols.contains(p);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      if (_scanProtocols.length > 1) {
                        _scanProtocols.remove(p);
                      }
                    } else {
                      _scanProtocols.add(p);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.scaffold,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          tile('Shuffle IP list', _shuffleResolvers, (v) => setState(() => _shuffleResolvers = v)),
          tile('HTTP verification (port 80)', _verifyHttp, (v) => setState(() => _verifyHttp = v)),
          tile('SSH verification (port 22)', _verifySsh, (v) => setState(() => _verifySsh = v)),
          tile('Show only working', _showOnlyWorking, (v) => setState(() => _showOnlyWorking = v)),
        ],
      ),
    );
  }

  Widget _buildRecordAndLength() {
    return Column(
      children: [
        RecordTypePicker(
          selected: _recordType,
          onChanged: (value) => setState(() => _recordType = value),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: CupertinoTextField(
            controller: _queryLengthCtrl,
            keyboardType: TextInputType.number,
            placeholder: 'Query Length (30-253)',
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffold,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  // ── Progress ──
  Widget _buildProgressSection(DnsScannerState state) {
    if (!state.isScanning && state.progress == 0.0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  state.isScanning
                      ? 'Scanning ${state.currentResolver ?? ""}...'
                      : 'Scan Complete',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(state.progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFamily: 'SF Mono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress,
              backgroundColor: AppColors.scaffold,
              valueColor: AlwaysStoppedAnimation<Color>(
                state.isScanning ? AppColors.primary : AppColors.connected,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Best Result ──
  Widget _buildBestResult(DnsScanResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.connected.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.connected.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.connected.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.checkmark_seal_fill,
                color: AppColors.connected, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Best Resolver',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  result.resolver,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'SF Mono',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.latencyMs} ms',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.connected,
                  fontFamily: 'SF Mono',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                result.protocol,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Results List ──
  Widget _buildResultsList(DnsScannerState state) {
    final visible = (_showOnlyWorking
        ? state.results.where((r) => r.success).toList()
        : state.results)
      ..sort(_buildSortComparator());
    final hasWorking = state.results.any((r) => r.success);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Results',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${state.results.where((r) => r.success).length}/${state.results.length} OK',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: 'SF Mono',
                    ),
                  ),
                  if (!widget.allowSelection && hasWorking) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _addToProfileMode = !_addToProfileMode;
                        if (!_addToProfileMode) _selectedResults.clear();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _addToProfileMode
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.scaffold,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _addToProfileMode ? AppColors.primary : AppColors.cardBorder,
                          ),
                        ),
                        child: Text(
                          _addToProfileMode ? 'Cancel' : '+ Profile',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _addToProfileMode ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSortControls(),
          const SizedBox(height: 12),
          ...visible.map((r) => _resultRow(r)),
          if (widget.allowSelection) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                onPressed: _selectedResults.isEmpty
                    ? null
                    : () {
                        final selected = state.results.where((r) {
                          final key = '${r.resolver}::${r.protocol}';
                          return _selectedResults.contains(key);
                        }).toList();
                        Navigator.of(context).pop(selected);
                      },
                child: Text('Add Selected (${_selectedResults.length})'),
              ),
            ),
          ],
          if (_addToProfileMode) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                onPressed: _selectedResults.isEmpty
                    ? null
                    : () => _showProfilePicker(state),
                child: Text('Add to Profile (${_selectedResults.length})'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortControls() {
    final labels = <_DnsResultSort, String>{
      _DnsResultSort.speed: 'Speed',
      _DnsResultSort.protocol: 'Type',
      _DnsResultSort.status: 'Status',
      _DnsResultSort.name: 'Name',
    };
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _DnsResultSort.values.map((sort) {
              final selected = _sortBy == sort;
              return GestureDetector(
                onTap: () => setState(() => _sortBy = sort),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.scaffold,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder),
                  ),
                  child: Text(
                    labels[sort]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: AppColors.scaffold,
          borderRadius: BorderRadius.circular(10),
          onPressed: () => setState(() => _sortAscending = !_sortAscending),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _sortAscending ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                color: AppColors.textSecondary,
                size: 14,
              ),
              const SizedBox(width: 6),
              const Text(
                'Order',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Comparator<DnsScanResult> _buildSortComparator() {
    int compare(DnsScanResult a, DnsScanResult b) {
      switch (_sortBy) {
        case _DnsResultSort.speed:
          final aLatency = a.success ? a.latencyMs : 1 << 30;
          final bLatency = b.success ? b.latencyMs : 1 << 30;
          return aLatency.compareTo(bLatency);
        case _DnsResultSort.protocol:
          return a.protocol.toLowerCase().compareTo(b.protocol.toLowerCase());
        case _DnsResultSort.status:
          if (a.success == b.success) return a.latencyMs.compareTo(b.latencyMs);
          return a.success ? -1 : 1;
        case _DnsResultSort.name:
          return a.resolver.toLowerCase().compareTo(b.resolver.toLowerCase());
      }
    }

    return (a, b) {
      final value = compare(a, b);
      return _sortAscending ? value : -value;
    };
  }

  Widget _resultRow(DnsScanResult r) {
    final color = !r.success
        ? AppColors.error
        : r.latencyMs < 50
        ? AppColors.connected
        : r.latencyMs < 120
        ? AppColors.warning
        : AppColors.error;

    final resultKey = '${r.resolver}::${r.protocol}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.scaffold,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (widget.allowSelection || _addToProfileMode)
              GestureDetector(
                onTap: r.success
                    ? () => setState(() {
                          if (_selectedResults.contains(resultKey)) {
                            _selectedResults.remove(resultKey);
                          } else {
                            _selectedResults.add(resultKey);
                          }
                        })
                    : null,
                child: Icon(
                  _selectedResults.contains(resultKey)
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: _selectedResults.contains(resultKey)
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 20,
                ),
              ),
            if (widget.allowSelection || _addToProfileMode) const SizedBox(width: 8),
            Icon(
              r.success
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.xmark_circle_fill,
              color: r.success ? AppColors.connected : AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                r.resolver,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'SF Mono',
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                r.protocol,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            const SizedBox(width: 8),
            if (_verifyHttp || _verifySsh)
              SizedBox(
                width: 64,
                child: Text(
                  '${_verifyHttp ? (r.httpOk ? "H+" : "H-") : ""}${_verifySsh ? (r.sshOk ? " S+" : " S-") : ""}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
            if (_verifyHttp || _verifySsh) const SizedBox(width: 6),
            SizedBox(
              width: 60,
              child: Text(
                r.success ? '${r.latencyMs} ms' : r.error ?? 'Fail',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF Mono',
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfilePicker(DnsScannerState scanState) async {
    final profileBloc = context.read<ProfileBloc>();
    final profiles = profileBloc.state.profiles;

    if (profiles.isEmpty) {
      _showError('No profiles found. Create a profile first.');
      return;
    }

    final selected = scanState.results.where((r) {
      final key = '${r.resolver}::${r.protocol}';
      return _selectedResults.contains(key);
    }).toList();

    final profile = await showCupertinoModalPopup<Profile>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Add to Profile'),
        message: Text('Add ${selected.length} resolver(s) to which profile?'),
        actions: profiles.map((p) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(p),
            child: Text(p.name),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (profile == null) return;

    final existingResolvers = profile.dnsResolver
        .split(RegExp(r'[\n,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final newResolvers = selected.map((r) => r.resolver.trim()).where((e) => e.isNotEmpty);
    final merged = {...existingResolvers, ...newResolvers}.join(',');

    DnsTransport transport = profile.dnsTransport;
    final firstProtocol = selected.first.protocol.toUpperCase();
    if (firstProtocol == 'DOH') {
      transport = DnsTransport.doh;
    } else if (firstProtocol == 'DOT') {
      transport = DnsTransport.dot;
    } else if (firstProtocol == 'TCP') {
      transport = DnsTransport.tcp;
    } else {
      transport = DnsTransport.classic;
    }

    profileBloc.add(ProfileUpdated(profile.copyWith(
      dnsResolver: merged,
      dnsTransport: transport,
    )));

    setState(() {
      _addToProfileMode = false;
      _selectedResults.clear();
    });

    if (mounted) {
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Done'),
          content: Text('Added ${selected.length} resolver(s) to "${profile.name}".'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<String> _parseResolvers(String input) {
    final values = input
        .split(RegExp(r'[\n,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return values;
  }

  Future<void> _importFromTxt() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) {
      _showError('Selected file not found.');
      return;
    }
    final content = await file.readAsString();
    final imported = _parseResolvers(content);
    if (imported.isEmpty) {
      _showError('No valid resolvers found in TXT file.');
      return;
    }
    setState(() {
      final merged = {..._parseResolvers(_resolversCtrl.text), ...imported}.toList();
      _resolversCtrl.text = merged.join('\n');
    });
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

enum _DnsResultSort {
  speed,
  protocol,
  status,
  name,
}
