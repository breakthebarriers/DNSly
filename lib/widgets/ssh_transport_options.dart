import 'package:flutter/cupertino.dart';
import '../../models/profile.dart';

class SshTransportOptionsWidget extends StatefulWidget {
  final Profile profile;
  final Function(Profile) onProfileChanged;

  const SshTransportOptionsWidget({
    Key? key,
    required this.profile,
    required this.onProfileChanged,
  }) : super(key: key);

  @override
  State<SshTransportOptionsWidget> createState() =>
      _SshTransportOptionsWidgetState();
}

class _SshTransportOptionsWidgetState
    extends State<SshTransportOptionsWidget> {
  late TextEditingController _sniController;
  late TextEditingController _wsPathController;
  late TextEditingController _wsHostController;
  late TextEditingController _proxyHostController;
  late TextEditingController _proxyPortController;
  late TextEditingController _proxyHostHdrController;
  late TextEditingController _payloadController;

  @override
  void initState() {
    super.initState();
    _sniController =
        TextEditingController(text: widget.profile.sshTlsSni ?? '');
    _wsPathController =
        TextEditingController(text: widget.profile.sshWsPath ?? '/ssh');
    _wsHostController =
        TextEditingController(text: widget.profile.sshWsHost ?? '');
    _proxyHostController =
        TextEditingController(text: widget.profile.sshHttpProxyHost ?? '');
    _proxyPortController = TextEditingController(
        text: widget.profile.sshHttpProxyPort?.toString() ?? '');
    _proxyHostHdrController =
        TextEditingController(text: widget.profile.sshHttpProxyHostHdr ?? '');
    _payloadController =
        TextEditingController(text: widget.profile.sshPayload ?? '');
  }

  @override
  void dispose() {
    _sniController.dispose();
    _wsPathController.dispose();
    _wsHostController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    _proxyHostHdrController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  void _update(Profile updated) => widget.onProfileChanged(updated);

  @override
  Widget build(BuildContext context) {
    return CupertinoScrollbar(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _sectionLabel('SSH DPI Bypass'),
          _tlsSection(context),
          const SizedBox(height: 20),
          _wsSection(context),
          const SizedBox(height: 20),
          _httpConnectSection(context),
          const SizedBox(height: 20),
          _payloadSection(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _tlsSection(BuildContext context) {
    final enabled = widget.profile.sshTlsEnabled;
    return CupertinoListSection.insetGrouped(
      header: const Text('TLS (Domain Fronting)'),
      children: [
        CupertinoListTile(
          title: const Text('SSH over TLS'),
          trailing: CupertinoSwitch(
            value: enabled,
            onChanged: (v) =>
                _update(widget.profile.copyWith(sshTlsEnabled: v)),
          ),
        ),
        if (enabled)
          CupertinoListTile(
            title: const Text('Custom SNI'),
            subtitle: CupertinoTextField(
              controller: _sniController,
              placeholder: 'example.com',
              padding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              decoration: null,
              onChanged: (_) => _update(widget.profile.copyWith(
                sshTlsSni: _sniController.text.isNotEmpty
                    ? _sniController.text
                    : null,
              )),
            ),
          ),
      ],
    );
  }

  Widget _wsSection(BuildContext context) {
    final enabled = widget.profile.sshWsEnabled;
    return CupertinoListSection.insetGrouped(
      header: const Text('WebSocket'),
      children: [
        CupertinoListTile(
          title: const Text('SSH over WebSocket'),
          trailing: CupertinoSwitch(
            value: enabled,
            onChanged: (v) =>
                _update(widget.profile.copyWith(sshWsEnabled: v)),
          ),
        ),
        if (enabled) ...[
          CupertinoListTile(
            title: const Text('Use WSS (TLS)'),
            trailing: CupertinoSwitch(
              value: widget.profile.sshWsUseTls,
              onChanged: (v) =>
                  _update(widget.profile.copyWith(sshWsUseTls: v)),
            ),
          ),
          CupertinoListTile(
            title: const Text('Path'),
            subtitle: CupertinoTextField(
              controller: _wsPathController,
              placeholder: '/ssh',
              padding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              decoration: null,
              onChanged: (_) => _update(widget.profile.copyWith(
                sshWsPath: _wsPathController.text.isNotEmpty
                    ? _wsPathController.text
                    : '/ssh',
              )),
            ),
          ),
          CupertinoListTile(
            title: const Text('Host Header'),
            subtitle: CupertinoTextField(
              controller: _wsHostController,
              placeholder: 'example.com',
              padding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              decoration: null,
              onChanged: (_) => _update(widget.profile.copyWith(
                sshWsHost: _wsHostController.text.isNotEmpty
                    ? _wsHostController.text
                    : null,
              )),
            ),
          ),
        ],
      ],
    );
  }

  Widget _httpConnectSection(BuildContext context) {
    final hasProxy = widget.profile.sshHttpProxyHost != null &&
        widget.profile.sshHttpProxyHost!.isNotEmpty;
    return CupertinoListSection.insetGrouped(
      header: const Text('HTTP CONNECT Proxy'),
      children: [
        CupertinoListTile(
          title: const Text('Use HTTP CONNECT Proxy'),
          trailing: CupertinoSwitch(
            value: hasProxy,
            onChanged: (v) {
              if (!v) {
                _update(widget.profile.copyWith(
                  sshHttpProxyHost: null,
                  sshHttpProxyPort: null,
                  sshHttpProxyHostHdr: null,
                ));
              }
            },
          ),
        ),
        if (hasProxy) ...[
          CupertinoListTile(
            title: const Text('Proxy Host'),
            subtitle: CupertinoTextField(
              controller: _proxyHostController,
              placeholder: 'proxy.example.com',
              padding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              decoration: null,
              onChanged: (_) => _update(widget.profile.copyWith(
                sshHttpProxyHost: _proxyHostController.text.isNotEmpty
                    ? _proxyHostController.text
                    : null,
              )),
            ),
          ),
          CupertinoListTile(
            title: const Text('Proxy Port'),
            subtitle: CupertinoTextField(
              controller: _proxyPortController,
              placeholder: '8080',
              keyboardType: TextInputType.number,
              padding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              decoration: null,
              onChanged: (_) => _update(widget.profile.copyWith(
                sshHttpProxyPort: int.tryParse(_proxyPortController.text),
              )),
            ),
          ),
          CupertinoListTile(
            title: const Text('Host Header'),
            subtitle: CupertinoTextField(
              controller: _proxyHostHdrController,
              placeholder: 'example.com:22',
              padding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              decoration: null,
              onChanged: (_) => _update(widget.profile.copyWith(
                sshHttpProxyHostHdr:
                    _proxyHostHdrController.text.isNotEmpty
                        ? _proxyHostHdrController.text
                        : null,
              )),
            ),
          ),
        ],
      ],
    );
  }

  Widget _payloadSection(BuildContext context) {
    final hasPayload = widget.profile.sshPayload != null &&
        widget.profile.sshPayload!.isNotEmpty;
    return CupertinoListSection.insetGrouped(
      header: const Text('Payload Injection'),
      children: [
        CupertinoListTile(
          title: const Text('SSH Payload Injection'),
          trailing: CupertinoSwitch(
            value: hasPayload,
            onChanged: (v) {
              if (!v) _update(widget.profile.copyWith(sshPayload: null));
            },
          ),
        ),
        if (hasPayload)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CupertinoTextField(
                  controller: _payloadController,
                  placeholder:
                      'GET / HTTP/1.1[crlf]Host: [host][crlf][crlf]',
                  maxLines: 4,
                  onChanged: (_) => _update(widget.profile.copyWith(
                    sshPayload: _payloadController.text.isNotEmpty
                        ? _payloadController.text
                        : null,
                  )),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Placeholders: [host] [port] [crlf] [lf] [cr] [space]',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
