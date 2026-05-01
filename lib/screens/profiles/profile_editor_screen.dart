import 'package:dnsly_app/theme/app_defaults.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/profile/profile_event.dart';
import '../../models/dns_record_type.dart';
import '../../models/profile.dart';
import '../../utils/slipnet_codec.dart';
// import '../../models/connection_status.dart';
import '../../theme/app_theme.dart';
import '../dns_scanner/dns_scanner_bloc.dart';
import '../dns_scanner/dns_scanner_screen.dart';
// import '../../utils/constants.dart';
import 'widgets/form_field_tile.dart';
import 'widgets/record_type_picker.dart';
import 'widgets/section_header.dart';
import 'widgets/tunnel_picker.dart';
import 'export_sheet.dart';

class ProfileEditorScreen extends StatefulWidget {
  final Profile? profile;

  const ProfileEditorScreen({super.key, this.profile});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.profile != null;
  late bool _isLocked;
  Profile? _currentProfile;
  final _unlockPasswordCtrl = TextEditingController();

  // ─── Controllers ───
  late final TextEditingController _nameCtrl;
  late final TextEditingController _serverCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _domainCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _resolverCtrl;
  late final TextEditingController _sshHostCtrl;
  late final TextEditingController _sshPortCtrl;
  late final TextEditingController _sshUserCtrl;
  late final TextEditingController _sshPassCtrl;
  late final TextEditingController _sshKeyCtrl;
  late final TextEditingController _socksUserCtrl;
  late final TextEditingController _socksPassCtrl;
  late final TextEditingController _mtuCtrl;
  late final TextEditingController _timeoutCtrl;
  late final TextEditingController _queryLengthCtrl;
  late final TextEditingController _queryRateLimitCtrl;
  late final TextEditingController _idleTimeoutCtrl;
  late final TextEditingController _udpTimeoutCtrl;
  late final TextEditingController _maxLabelsCtrl;
  late final TextEditingController _clientIdSizeCtrl;

  // ─── State ───
  bool _advancedExpanded = false;
  late TunnelType _tunnelType;
  late DnsTransport _dnsTransport;
  late SshCipher _sshCipher;
  late SshAuthType _sshAuthType;
  late ConnectionMethod _connectionMethod;
  late DnsRecordType _recordType;
  late bool _compression;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _currentProfile = p;
    _isLocked = p?.isLocked ?? false;

    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _serverCtrl = TextEditingController(text: p?.server ?? '');
    _portCtrl =
        TextEditingController(text: '${p?.port ?? AppDefaults.defaultDnsPort}');
    _domainCtrl = TextEditingController(text: p?.domain ?? '');
    _passwordCtrl = TextEditingController(text: p?.password ?? '');
    _resolverCtrl = TextEditingController(
        text: p?.dnsResolver ?? AppDefaults.defaultResolvers[0]);
    _sshHostCtrl = TextEditingController(text: p?.sshHost ?? '');
    _sshPortCtrl = TextEditingController(
        text: '${p?.sshPort ?? AppDefaults.defaultSshPort}');
    _sshUserCtrl = TextEditingController(text: p?.sshUser ?? '');
    _sshPassCtrl = TextEditingController(text: p?.sshPassword ?? '');
    _sshKeyCtrl = TextEditingController(text: p?.sshKey ?? '');
    _socksUserCtrl = TextEditingController(text: p?.socksUser ?? '');
    _socksPassCtrl = TextEditingController(text: p?.socksPassword ?? '');
    _mtuCtrl = TextEditingController(text: '${p?.mtu ?? 1400}');
    _timeoutCtrl = TextEditingController(text: '${p?.timeout ?? 30}');
    _queryLengthCtrl = TextEditingController(text: '${p?.queryLength ?? 101}');
    _queryRateLimitCtrl = TextEditingController(text: '${p?.queryRateLimit ?? 0}');
    _idleTimeoutCtrl = TextEditingController(text: p?.idleTimeout != null ? '${p!.idleTimeout}' : '');
    _udpTimeoutCtrl = TextEditingController(text: p?.udpTimeout != null ? '${p!.udpTimeout}' : '');
    _maxLabelsCtrl = TextEditingController(text: p?.maxLabels != null ? '${p!.maxLabels}' : '');
    _clientIdSizeCtrl = TextEditingController(text: '${p?.clientIdSize ?? 2}');

    _tunnelType = p?.tunnelType ?? TunnelType.vayDns;
    _dnsTransport = p?.dnsTransport ?? DnsTransport.doh;
    _sshCipher = p?.sshCipher ?? SshCipher.chacha20Poly1305;
    _sshAuthType = p?.sshAuthType ?? SshAuthType.password;
    _connectionMethod = p?.connectionMethod ??
        ((_tunnelType == TunnelType.vayDnsSsh || _tunnelType == TunnelType.ssh)
            ? ConnectionMethod.ssh
            : ConnectionMethod.socks);
    _recordType = p?.recordType ?? DnsRecordType.txt;
    _compression = p?.compression ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serverCtrl.dispose();
    _portCtrl.dispose();
    _domainCtrl.dispose();
    _passwordCtrl.dispose();
    _resolverCtrl.dispose();
    _sshHostCtrl.dispose();
    _sshPortCtrl.dispose();
    _sshUserCtrl.dispose();
    _sshPassCtrl.dispose();
    _sshKeyCtrl.dispose();
    _socksUserCtrl.dispose();
    _socksPassCtrl.dispose();
    _mtuCtrl.dispose();
    _timeoutCtrl.dispose();
    _queryLengthCtrl.dispose();
    _queryRateLimitCtrl.dispose();
    _idleTimeoutCtrl.dispose();
    _udpTimeoutCtrl.dispose();
    _maxLabelsCtrl.dispose();
    _clientIdSizeCtrl.dispose();
    _unlockPasswordCtrl.dispose();
    super.dispose();
  }

  bool get _showSsh => _connectionMethod == ConnectionMethod.ssh;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.bgSecondary.withOpacity(0.9),
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
        middle: Text(_isEditing ? 'Edit Profile' : 'New Profile'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditing && _currentProfile != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showExportSheet(_currentProfile!),
                child: const Icon(
                  CupertinoIcons.share,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              if (_isLocked) _buildLockedBanner(),

              // ─── Name ───
              const SectionHeader(title: 'Profile Name'),
              const SizedBox(height: 8),
              FormFieldTile(
                label: 'Name',
                controller: _nameCtrl,
                placeholder: 'e.g. Work DNS',
                icon: CupertinoIcons.person_crop_circle,
                enabled: !_isLocked,
              ),

              const SizedBox(height: 24),

              // ─── Tunnel Type ───
              const SectionHeader(title: 'Tunnel Type'),
              const SizedBox(height: 10),
              TunnelPicker(
                selected: _tunnelType,
                onChanged:
                    _isLocked ? (_) {} : (t) => setState(() => _tunnelType = t),
              ),

              const SizedBox(height: 28),

              // ─── Basic ───
              const SectionHeader(title: 'Basic'),
              const SizedBox(height: 8),
              FormFieldTile(
                label: 'Server',
                controller: _serverCtrl,
                placeholder: 'example.com',
                icon: CupertinoIcons.globe,
                keyboardType: TextInputType.url,
                enabled: !_isLocked,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FormFieldTile(
                      label: 'Port',
                      controller: _portCtrl,
                      placeholder: AppDefaults.defaultDnsPort.toString(),
                      icon: CupertinoIcons.number,
                      keyboardType: TextInputType.number,
                      enabled: !_isLocked,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FormFieldTile(
                      label: 'Domain',
                      controller: _domainCtrl,
                      placeholder: 'domain.com',
                      icon: CupertinoIcons.textformat_abc,
                      enabled: !_isLocked,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FormFieldTile(
                label: 'Password (optional)',
                controller: _passwordCtrl,
                placeholder: 'Leave empty if not required',
                icon: CupertinoIcons.lock,
                obscureText: true,
                enabled: !_isLocked,
              ),

              const SizedBox(height: 28),

              // ─── DNS ───
              const SectionHeader(title: 'DNS Transport'),
              const SizedBox(height: 8),
              _buildDnsTransportPicker(),
              const SizedBox(height: 12),
              FormFieldTile(
                label: 'DNS Resolver',
                controller: _resolverCtrl,
                placeholder: '1.1.1.1',
                icon: CupertinoIcons.dot_radiowaves_left_right,
                keyboardType: TextInputType.number,
                enabled: true,
              ),
              const SizedBox(height: 12),
              RecordTypePicker(
                selected: _recordType,
                onChanged: _isLocked ? (_) {} : (v) => setState(() => _recordType = v),
              ),
              const SizedBox(height: 12),
              FormFieldTile(
                label: 'Query Length',
                controller: _queryLengthCtrl,
                placeholder: '101',
                icon: CupertinoIcons.arrow_left_right_circle,
                keyboardType: TextInputType.number,
                enabled: !_isLocked,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: AppColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _openResolverScanner,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.search, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Scan for Working Resolvers',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ─── Connection Method ───
              const SectionHeader(title: 'Connection Method'),
              const SizedBox(height: 8),
              _buildConnectionMethodPicker(),
              const SizedBox(height: 16),

              if (_showSsh) ...[
                // ─── SSH ───
                const SectionHeader(title: 'SSH Configuration'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FormFieldTile(
                        label: 'SSH Host',
                        controller: _sshHostCtrl,
                        placeholder: 'ssh.example.com',
                        icon: CupertinoIcons.arrow_2_squarepath,
                        enabled: !_isLocked,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FormFieldTile(
                        label: 'SSH Port',
                        controller: _sshPortCtrl,
                        placeholder: AppDefaults.defaultSshPort.toString(),
                        icon: CupertinoIcons.number,
                        keyboardType: TextInputType.number,
                        enabled: !_isLocked,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FormFieldTile(
                        label: 'SSH User',
                        controller: _sshUserCtrl,
                        placeholder: 'root',
                        icon: CupertinoIcons.person,
                        enabled: !_isLocked,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSshAuthTypePicker(),
                const SizedBox(height: 12),
                if (_sshAuthType == SshAuthType.password)
                  FormFieldTile(
                    label: 'SSH Password',
                    controller: _sshPassCtrl,
                    placeholder: 'Password',
                    icon: CupertinoIcons.lock,
                    obscureText: true,
                    enabled: !_isLocked,
                  )
                else
                  FormFieldTile(
                    label: 'Private Key',
                    controller: _sshKeyCtrl,
                    placeholder: 'Paste SSH private key...',
                    icon: CupertinoIcons.doc_text,
                    maxLines: 4,
                    enabled: !_isLocked,
                  ),
                const SizedBox(height: 12),
                _buildCipherPicker(),
                const SizedBox(height: 28),
              ] else ...[
                const SectionHeader(title: 'SOCKS5 Credentials (Optional)'),
                const SizedBox(height: 8),
                FormFieldTile(
                  label: 'Username',
                  controller: _socksUserCtrl,
                  placeholder: 'Username',
                  icon: CupertinoIcons.person,
                  enabled: !_isLocked,
                ),
                const SizedBox(height: 12),
                FormFieldTile(
                  label: 'Password',
                  controller: _socksPassCtrl,
                  placeholder: 'Password',
                  icon: CupertinoIcons.lock,
                  obscureText: true,
                  enabled: !_isLocked,
                ),
                const SizedBox(height: 28),
              ],

              // ─── Query Rate Limit ───
              const SizedBox(height: 4),
              FormFieldTile(
                label: 'Query Rate Limit (q/s)',
                controller: _queryRateLimitCtrl,
                placeholder: '0',
                icon: CupertinoIcons.gauge,
                keyboardType: TextInputType.number,
                enabled: !_isLocked,
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Max DNS queries per second. 0 = unlimited.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 24),

              // ─── Advanced (collapsible) ───
              _buildAdvancedHeader(),
              if (_advancedExpanded) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'Only change these if you know what you\'re doing. 0 = use default.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                FormFieldTile(
                  label: 'Idle Timeout (seconds)',
                  controller: _idleTimeoutCtrl,
                  placeholder: '0',
                  icon: CupertinoIcons.timer,
                  keyboardType: TextInputType.number,
                  enabled: !_isLocked,
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Session idle timeout.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                FormFieldTile(
                  label: 'Keepalive (seconds)',
                  controller: _timeoutCtrl,
                  placeholder: '0',
                  icon: CupertinoIcons.heart,
                  keyboardType: TextInputType.number,
                  enabled: !_isLocked,
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Keepalive interval.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                FormFieldTile(
                  label: 'UDP Timeout (ms)',
                  controller: _udpTimeoutCtrl,
                  placeholder: '0',
                  icon: CupertinoIcons.clock,
                  keyboardType: TextInputType.number,
                  enabled: !_isLocked,
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Per-query UDP response timeout. Default: ~500ms.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                FormFieldTile(
                  label: 'Max Labels',
                  controller: _maxLabelsCtrl,
                  placeholder: '0',
                  icon: CupertinoIcons.tag,
                  keyboardType: TextInputType.number,
                  enabled: !_isLocked,
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Max data labels in query name. 0 = unlimited.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                FormFieldTile(
                  label: 'Client ID Size (bytes)',
                  controller: _clientIdSizeCtrl,
                  placeholder: '2',
                  icon: CupertinoIcons.number_circle,
                  keyboardType: TextInputType.number,
                  enabled: !_isLocked,
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'ClientID length on the wire. Must match server. Ignored when DNSTT compat is on (fixed at 8).',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FormFieldTile(
                        label: 'MTU',
                        controller: _mtuCtrl,
                        placeholder: '1400',
                        icon: CupertinoIcons.resize,
                        keyboardType: TextInputType.number,
                        enabled: !_isLocked,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompressionToggle(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.lock_fill,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This profile is locked. Only DNS settings can be changed.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if ((_currentProfile?.encryptedUri ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _unlockPasswordCtrl,
              obscureText: true,
              placeholder: 'Password to unlock all fields',
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: AppColors.primary.withOpacity(0.15),
              onPressed: _unlockEncryptedProfile,
              child: const Text(
                'Unlock profile',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDnsTransportPicker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: DnsTransport.values.map((t) {
          final selected = t == _dnsTransport;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _dnsTransport = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withOpacity(0.15) : null,
                  borderRadius: BorderRadius.circular(9),
                  border: selected
                      ? Border.all(color: AppColors.primary.withOpacity(0.4))
                      : null,
                ),
                child: Text(
                  t.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConnectionMethodPicker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ConnectionMethod.values.map((m) {
          final selected = m == _connectionMethod;
          return Expanded(
            child: GestureDetector(
              onTap: _isLocked ? null : () => setState(() => _connectionMethod = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withOpacity(0.15) : null,
                  borderRadius: BorderRadius.circular(9),
                  border: selected
                      ? Border.all(color: AppColors.primary.withOpacity(0.4))
                      : null,
                ),
                child: Text(
                  m.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSshAuthTypePicker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: SshAuthType.values.map((m) {
          final selected = m == _sshAuthType;
          return Expanded(
            child: GestureDetector(
              onTap: _isLocked ? null : () => setState(() => _sshAuthType = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withOpacity(0.15) : null,
                  borderRadius: BorderRadius.circular(9),
                  border: selected
                      ? Border.all(color: AppColors.primary.withOpacity(0.4))
                      : null,
                ),
                child: Text(
                  m == SshAuthType.password ? 'Password' : 'Key',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCipherPicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.shield, size: 14, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text('Cipher',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _isLocked ? null : _showCipherSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sshCipher.label,
                      style:
                          const TextStyle(fontSize: 14, color: AppColors.text),
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_down,
                      size: 14, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCipherSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('SSH Cipher'),
        actions: SshCipher.values.map((c) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sshCipher = c);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(c.label),
                if (c == _sshCipher) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark,
                      size: 16, color: AppColors.primary),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildAdvancedHeader() {
    return GestureDetector(
      onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const Text(
              'Advanced',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const Spacer(),
            Icon(
              _advancedExpanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressionToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.archivebox,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compression',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('Compress DNS payloads (zlib)',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: _compression,
            activeColor: AppColors.primary,
            onChanged:
                _isLocked ? null : (v) => setState(() => _compression = v),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_isLocked && _nameCtrl.text.trim().isEmpty) {
      _showError('Profile name is required');
      return;
    }
    if (!_isLocked && _serverCtrl.text.trim().isEmpty) {
      _showError('Server address is required');
      return;
    }
    if (!_isLocked && _domainCtrl.text.trim().isEmpty) {
      _showError('Domain is required');
      return;
    }
    if (!_isLocked && _showSsh && _sshHostCtrl.text.trim().isEmpty) {
      _showError('SSH host is required');
      return;
    }

    final effectiveTunnelType = _applyMethodToTunnelType(_tunnelType, _connectionMethod);
    final profile = _isLocked && _currentProfile != null
        ? _currentProfile!.copyWith(
            dnsTransport: _dnsTransport,
            dnsResolver: _resolverCtrl.text.trim(),
            recordType: _recordType,
            queryLength: int.tryParse(_queryLengthCtrl.text) ?? 101,
            connectionMethod: _connectionMethod,
            queryRateLimit: int.tryParse(_queryRateLimitCtrl.text) ?? 0,
            idleTimeout: _idleTimeoutCtrl.text.isNotEmpty ? int.tryParse(_idleTimeoutCtrl.text) : null,
            udpTimeout: _udpTimeoutCtrl.text.isNotEmpty ? int.tryParse(_udpTimeoutCtrl.text) : null,
            maxLabels: _maxLabelsCtrl.text.isNotEmpty ? int.tryParse(_maxLabelsCtrl.text) : null,
            clientIdSize: int.tryParse(_clientIdSizeCtrl.text) ?? 2,
          )
        : Profile(
            id: widget.profile?.id ?? const Uuid().v4(),
            name: _nameCtrl.text.trim(),
            server: _serverCtrl.text.trim(),
            port: int.tryParse(_portCtrl.text) ?? 53,
            domain: _domainCtrl.text.trim(),
            password: _passwordCtrl.text,
            tunnelType: effectiveTunnelType,
            dnsTransport: _dnsTransport,
            dnsResolver: _resolverCtrl.text.trim(),
            recordType: _recordType,
            queryLength: int.tryParse(_queryLengthCtrl.text) ?? 101,
            connectionMethod: _connectionMethod,
            sshHost: _showSsh ? _sshHostCtrl.text.trim() : null,
            sshPort: _showSsh
                ? (int.tryParse(_sshPortCtrl.text) ??
                    AppDefaults.defaultSshPort)
                : null,
            sshUser: _showSsh ? _sshUserCtrl.text.trim() : null,
            sshPassword: _showSsh && _sshAuthType == SshAuthType.password
                ? _sshPassCtrl.text
                : null,
            sshKey: _showSsh && _sshAuthType == SshAuthType.key ? _sshKeyCtrl.text : null,
            sshCipher: _showSsh ? _sshCipher : null,
            sshAuthType: _sshAuthType,
            socksUser: !_showSsh ? _socksUserCtrl.text.trim() : null,
            socksPassword: !_showSsh ? _socksPassCtrl.text : null,
            compression: _compression,
            mtu: int.tryParse(_mtuCtrl.text),
            timeout: int.tryParse(_timeoutCtrl.text),
            queryRateLimit: int.tryParse(_queryRateLimitCtrl.text) ?? 0,
            idleTimeout: _idleTimeoutCtrl.text.isNotEmpty ? int.tryParse(_idleTimeoutCtrl.text) : null,
            udpTimeout: _udpTimeoutCtrl.text.isNotEmpty ? int.tryParse(_udpTimeoutCtrl.text) : null,
            maxLabels: _maxLabelsCtrl.text.isNotEmpty ? int.tryParse(_maxLabelsCtrl.text) : null,
            clientIdSize: int.tryParse(_clientIdSizeCtrl.text) ?? 2,
            isLocked: _isLocked,
            encryptedUri: _currentProfile?.encryptedUri,
          );

    final bloc = context.read<ProfileBloc>();
    if (_isEditing) {
      bloc.add(ProfileUpdated(profile));
    } else {
      bloc.add(ProfileAdded(profile));
    }

    Navigator.of(context).pop();
  }

  TunnelType _applyMethodToTunnelType(TunnelType base, ConnectionMethod method) {
    if (base == TunnelType.vayDns ||
        base == TunnelType.vayDnsSsh ||
        base == TunnelType.vayDnsSocks) {
      return method == ConnectionMethod.ssh
          ? TunnelType.vayDnsSsh
          : TunnelType.vayDnsSocks;
    }
    if (base == TunnelType.ssh || base == TunnelType.socks5) {
      return method == ConnectionMethod.ssh ? TunnelType.ssh : TunnelType.socks5;
    }
    return base;
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Validation Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _unlockEncryptedProfile() {
    final encrypted = _currentProfile?.encryptedUri;
    final password = _unlockPasswordCtrl.text.trim();
    if (encrypted == null || encrypted.isEmpty) {
      _showError('No encrypted payload found for this profile.');
      return;
    }
    if (password.isEmpty) {
      _showError('Password is required to unlock this profile.');
      return;
    }

    final decryptedData = SlipnetCodec.decodeEncrypted(encrypted, password);
    if (decryptedData == null) {
      _showError('Invalid encrypted profile or wrong password.');
      return;
    }
    setState(() {
      _isLocked = false;
      _currentProfile = _currentProfile?.copyWith(
        isLocked: false,
        name: decryptedData.name,
        tunnelType: decryptedData.tunnelType,
        server: decryptedData.server,
        port: decryptedData.port,
        domain: decryptedData.domain,
        password: decryptedData.password,
        dnsResolver: decryptedData.dnsResolver,
        dnsTransport: decryptedData.dnsTransport,
        recordType: decryptedData.recordType,
        queryLength: decryptedData.queryLength,
        connectionMethod: decryptedData.connectionMethod,
        sshHost: decryptedData.sshHost,
        sshPort: decryptedData.sshPort,
        sshUser: decryptedData.sshUser,
        sshPassword: decryptedData.sshPassword,
        sshKey: decryptedData.sshKey,
        sshCipher: decryptedData.sshCipher,
        sshAuthType: decryptedData.sshAuthType,
        socksUser: decryptedData.socksUser,
        socksPassword: decryptedData.socksPassword,
        compression: decryptedData.compression,
        mtu: decryptedData.mtu,
        timeout: decryptedData.timeout,
      );
      _nameCtrl.text = decryptedData.name;
      _serverCtrl.text = decryptedData.server;
      _portCtrl.text = decryptedData.port.toString();
      _domainCtrl.text = decryptedData.domain;
      _passwordCtrl.text = decryptedData.password ?? '';
      _resolverCtrl.text = decryptedData.dnsResolver;
      _queryLengthCtrl.text = '${decryptedData.queryLength}';
      _sshHostCtrl.text = decryptedData.sshHost ?? '';
      _sshPortCtrl.text =
          '${decryptedData.sshPort ?? AppDefaults.defaultSshPort}';
      _sshUserCtrl.text = decryptedData.sshUser ?? '';
      _sshPassCtrl.text = decryptedData.sshPassword ?? '';
      _sshKeyCtrl.text = decryptedData.sshKey ?? '';
      _socksUserCtrl.text = decryptedData.socksUser ?? '';
      _socksPassCtrl.text = decryptedData.socksPassword ?? '';
      _mtuCtrl.text = '${decryptedData.mtu ?? 1400}';
      _timeoutCtrl.text = '${decryptedData.timeout ?? 30}';
      _queryRateLimitCtrl.text = '${decryptedData.queryRateLimit}';
      _idleTimeoutCtrl.text = decryptedData.idleTimeout != null ? '${decryptedData.idleTimeout}' : '';
      _udpTimeoutCtrl.text = decryptedData.udpTimeout != null ? '${decryptedData.udpTimeout}' : '';
      _maxLabelsCtrl.text = decryptedData.maxLabels != null ? '${decryptedData.maxLabels}' : '';
      _clientIdSizeCtrl.text = '${decryptedData.clientIdSize}';
      _tunnelType = decryptedData.tunnelType;
      _dnsTransport = decryptedData.dnsTransport;
      _recordType = decryptedData.recordType;
      _connectionMethod = decryptedData.connectionMethod;
      _sshCipher = decryptedData.sshCipher ?? SshCipher.chacha20Poly1305;
      _sshAuthType = decryptedData.sshAuthType;
      _compression = decryptedData.compression;
    });
  }

  void _showExportSheet(Profile profile) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => ExportSheet(profile: profile),
    );
  }

  Future<void> _openResolverScanner() async {
    final selected = await Navigator.of(context).push<List<DnsScanResult>>(
      CupertinoPageRoute(
        builder: (_) => DnsScannerScreen(
          initialDomain: _domainCtrl.text.trim().isEmpty ? 'example.com' : _domainCtrl.text.trim(),
          initialResolvers: _resolverCtrl.text
              .split(RegExp(r'[\n,;\s]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          allowSelection: true,
        ),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      final currentResolvers = _resolverCtrl.text
          .split(RegExp(r'[\n,;\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      final selectedResolvers = selected.map((e) => e.resolver.trim()).where((e) => e.isNotEmpty);
      _resolverCtrl.text = {...currentResolvers, ...selectedResolvers}.join(',');
      final first = selected.first.protocol.toUpperCase();
      if (first == 'DOH') {
        _dnsTransport = DnsTransport.doh;
      } else if (first == 'DOT') {
        _dnsTransport = DnsTransport.dot;
      } else if (first == 'TCP') {
        _dnsTransport = DnsTransport.tcp;
      } else {
        _dnsTransport = DnsTransport.classic;
      }
    });
  }
}
