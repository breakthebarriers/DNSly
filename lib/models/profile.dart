import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'dns_record_type.dart';

enum TunnelType {
  vayDns,
  vayDnsSsh,
  vayDnsSocks,
  ssh,
  socks5,
}

extension TunnelTypeX on TunnelType {
  String get label {
    switch (this) {
      case TunnelType.vayDns: return 'VayDNS';
      case TunnelType.vayDnsSsh: return 'VayDNS + SSH';
      case TunnelType.vayDnsSocks: return 'VayDNS + SOCKS5';
      case TunnelType.ssh: return 'SSH';
      case TunnelType.socks5: return 'SOCKS5';
    }
  }
}

enum DnsTransport {
  classic,
  tcp,
  doh,
  dot,
}

extension DnsTransportX on DnsTransport {
  String get label {
    switch (this) {
      case DnsTransport.classic: return 'DNS';
      case DnsTransport.tcp: return 'TCP';
      case DnsTransport.doh: return 'DoH';
      case DnsTransport.dot: return 'DoT';
    }
  }
}

enum SshCipher {
  aes256Gcm,
  aes128Gcm,
  chacha20Poly1305,
}

extension SshCipherX on SshCipher {
  String get label {
    switch (this) {
      case SshCipher.aes256Gcm: return 'AES-256-GCM';
      case SshCipher.aes128Gcm: return 'AES-128-GCM';
      case SshCipher.chacha20Poly1305: return 'ChaCha20-Poly1305';
    }
  }
}

enum ConnectionMethod {
  ssh,
  socks,
}

extension ConnectionMethodX on ConnectionMethod {
  String get label {
    switch (this) {
      case ConnectionMethod.ssh:
        return 'SSH';
      case ConnectionMethod.socks:
        return 'SOCKS';
    }
  }
}

enum SshAuthType {
  password,
  key,
}

class Profile {
  final String id;
  final String name;
  final TunnelType tunnelType;

  final String server;
  final int port;
  final String domain;
  final String? password;

  final String dnsResolver;
  final DnsTransport dnsTransport;
  final DnsRecordType recordType;
  final int queryLength;
  final ConnectionMethod connectionMethod;

  final String? sshHost;
  final int? sshPort;
  final String? sshUser;
  final String? sshPassword;
  final String? sshKey;
  final SshCipher? sshCipher;
  final SshAuthType sshAuthType;

  final String? socksUser;
  final String? socksPassword;

  final bool compression;
  final int? mtu;
  final int? timeout;

  final int queryRateLimit;
  final int? idleTimeout;
  final int? udpTimeout;
  final int? maxLabels;
  final int clientIdSize;

  final bool isLocked;
  final String? encryptedUri;

  const Profile({
    required this.id,
    required this.name,
    required this.tunnelType,
    required this.server,
    required this.port,
    required this.domain,
    this.password,
    required this.dnsResolver,
    required this.dnsTransport,
    this.recordType = DnsRecordType.txt,
    this.queryLength = 101,
    this.connectionMethod = ConnectionMethod.socks,
    this.sshHost,
    this.sshPort,
    this.sshUser,
    this.sshPassword,
    this.sshKey,
    this.sshCipher,
    this.sshAuthType = SshAuthType.password,
    this.socksUser,
    this.socksPassword,
    this.compression = false,
    this.mtu,
    this.timeout,
    this.queryRateLimit = 0,
    this.idleTimeout,
    this.udpTimeout,
    this.maxLabels,
    this.clientIdSize = 2,
    this.isLocked = false,
    this.encryptedUri,
  });

  Profile copyWith({
    String? id,
    String? name,
    TunnelType? tunnelType,
    String? server,
    int? port,
    String? domain,
    String? password,
    String? dnsResolver,
    DnsTransport? dnsTransport,
    DnsRecordType? recordType,
    int? queryLength,
    ConnectionMethod? connectionMethod,
    String? sshHost,
    int? sshPort,
    String? sshUser,
    String? sshPassword,
    String? sshKey,
    SshCipher? sshCipher,
    SshAuthType? sshAuthType,
    String? socksUser,
    String? socksPassword,
    bool? compression,
    int? mtu,
    int? timeout,
    int? queryRateLimit,
    int? idleTimeout,
    int? udpTimeout,
    int? maxLabels,
    int? clientIdSize,
    bool? isLocked,
    String? encryptedUri,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      tunnelType: tunnelType ?? this.tunnelType,
      server: server ?? this.server,
      port: port ?? this.port,
      domain: domain ?? this.domain,
      password: password ?? this.password,
      dnsResolver: dnsResolver ?? this.dnsResolver,
      dnsTransport: dnsTransport ?? this.dnsTransport,
      recordType: recordType ?? this.recordType,
      queryLength: queryLength ?? this.queryLength,
      connectionMethod: connectionMethod ?? this.connectionMethod,
      sshHost: sshHost ?? this.sshHost,
      sshPort: sshPort ?? this.sshPort,
      sshUser: sshUser ?? this.sshUser,
      sshPassword: sshPassword ?? this.sshPassword,
      sshKey: sshKey ?? this.sshKey,
      sshCipher: sshCipher ?? this.sshCipher,
      sshAuthType: sshAuthType ?? this.sshAuthType,
      socksUser: socksUser ?? this.socksUser,
      socksPassword: socksPassword ?? this.socksPassword,
      compression: compression ?? this.compression,
      mtu: mtu ?? this.mtu,
      timeout: timeout ?? this.timeout,
      queryRateLimit: queryRateLimit ?? this.queryRateLimit,
      idleTimeout: idleTimeout ?? this.idleTimeout,
      udpTimeout: udpTimeout ?? this.udpTimeout,
      maxLabels: maxLabels ?? this.maxLabels,
      clientIdSize: clientIdSize ?? this.clientIdSize,
      isLocked: isLocked ?? this.isLocked,
      encryptedUri: encryptedUri ?? this.encryptedUri,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tunnelType': tunnelType.name,
    'server': server,
    'port': port,
    'domain': domain,
    'password': password,
    'dnsResolver': dnsResolver,
    'dnsTransport': dnsTransport.name,
    'recordType': recordType.label,
    'queryLength': queryLength,
    'connectionMethod': connectionMethod.name,
    'sshHost': sshHost,
    'sshPort': sshPort,
    'sshUser': sshUser,
    'sshPassword': sshPassword,
    'sshKey': sshKey,
    'sshCipher': sshCipher?.name,
    'sshAuthType': sshAuthType.name,
    'socksUser': socksUser,
    'socksPassword': socksPassword,
    'compression': compression,
    'mtu': mtu,
    'timeout': timeout,
    'queryRateLimit': queryRateLimit,
    'idleTimeout': idleTimeout,
    'udpTimeout': udpTimeout,
    'maxLabels': maxLabels,
    'clientIdSize': clientIdSize,
    'isLocked': isLocked,
    'encryptedUri': encryptedUri,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] as String,
      tunnelType: TunnelType.values.firstWhere(
            (t) => t.name == json['tunnelType'],
        orElse: () => TunnelType.vayDns,
      ),
      server: json['server'] as String,
      port: json['port'] as int,
      domain: json['domain'] as String,
      password: json['password'] as String?,
      dnsResolver: json['dnsResolver'] as String,
      dnsTransport: DnsTransport.values.firstWhere(
            (d) => d.name == json['dnsTransport'],
        orElse: () => DnsTransport.classic,
      ),
      recordType: DnsRecordType.fromString((json['recordType'] as String?) ?? 'TXT'),
      queryLength: json['queryLength'] as int? ?? 101,
      connectionMethod: ConnectionMethod.values.firstWhere(
        (m) => m.name == json['connectionMethod'],
        orElse: () => TunnelType.values.firstWhere(
          (t) => t.name == json['tunnelType'],
          orElse: () => TunnelType.vayDns,
        ) == TunnelType.vayDnsSsh || (json['tunnelType'] == TunnelType.ssh.name)
            ? ConnectionMethod.ssh
            : ConnectionMethod.socks,
      ),
      sshHost: json['sshHost'] as String?,
      sshPort: json['sshPort'] as int?,
      sshUser: json['sshUser'] as String?,
      sshPassword: json['sshPassword'] as String?,
      sshKey: json['sshKey'] as String?,
      sshCipher: (json['sshCipher'] as String?) != null
          ? SshCipher.values.firstWhere(
            (c) => c.name == json['sshCipher'],
        orElse: () => SshCipher.chacha20Poly1305,
      )
          : null,
      sshAuthType: SshAuthType.values.firstWhere(
        (a) => a.name == json['sshAuthType'],
        orElse: () => SshAuthType.password,
      ),
      socksUser: json['socksUser'] as String?,
      socksPassword: json['socksPassword'] as String?,
      compression: json['compression'] as bool? ?? false,
      mtu: json['mtu'] as int?,
      timeout: json['timeout'] as int?,
      queryRateLimit: json['queryRateLimit'] as int? ?? 0,
      idleTimeout: json['idleTimeout'] as int?,
      udpTimeout: json['udpTimeout'] as int?,
      maxLabels: json['maxLabels'] as int?,
      clientIdSize: json['clientIdSize'] as int? ?? 2,
      isLocked: json['isLocked'] as bool? ?? false,
      encryptedUri: json['encryptedUri'] as String?,
    );
  }

  // ─── Slipnet URI export ───
  String toSlipnetUri() {
    final params = {
      'name': name,
      'domain': domain,
      'dnsResolver': dnsResolver,
      'dnsTransport': dnsTransport.name,
      'recordType': recordType.label,
      'queryLength': queryLength.toString(),
      'connectionMethod': connectionMethod.name,
      'sshHost': sshHost,
      'sshPort': sshPort?.toString(),
      'sshUser': sshUser,
      'sshCipher': sshCipher?.name,
      'sshAuthType': sshAuthType.name,
      'socksUser': socksUser,
      'compression': compression ? '1' : '0',
      'mtu': mtu?.toString(),
      'timeout': timeout?.toString(),
      'queryRateLimit': queryRateLimit != 0 ? queryRateLimit.toString() : null,
      'idleTimeout': idleTimeout?.toString(),
      'udpTimeout': udpTimeout?.toString(),
      'maxLabels': maxLabels?.toString(),
      'clientIdSize': clientIdSize != 2 ? clientIdSize.toString() : null,
    }..removeWhere((_, v) => v == null);

    final query = params.entries
        .map((e) =>
    '${Uri.encodeQueryComponent(e.key)}='
        '${Uri.encodeQueryComponent(e.value!)}')
        .join('&');

    return 'slipnet://${tunnelType.name}@$server:$port?$query';
  }

  factory Profile.fromSlipnetUri(String uri) {
    if (!uri.startsWith('slipnet://')) {
      throw FormatException('Invalid slipnet URI: $uri');
    }

    final payload = uri.substring(10);

    try {
      final decodedBytes = _decodeBase64Flexible(payload);
      final decoded = utf8.decode(decodedBytes);
      if (decoded.contains('|')) {
        final upstream = _tryFromUpstreamPipeFormat(decoded);
        if (upstream != null) return upstream;
        return _fromPipeFormat(decoded);
      }
    } catch (_) {
    }

    return _fromQueryFormat(uri);
  }

  static List<Profile> fromSlipnetUris(String input) {
    final uris = input
        .split(RegExp(r'[\n,]+'))
        .map((s) => s.trim())
        .where((s) => s.startsWith('slipnet://'))
        .toList();

    return uris.map((u) => Profile.fromSlipnetUri(u)).toList();
  }

  static Profile _fromPipeFormat(String decoded) {
    final p = decoded.split('|');

    TunnelType tunnelType;
    final tt = (p.length > 1 ? p[1] : '').toLowerCase();
    switch (tt) {
      case 'dnstt':
        tunnelType = TunnelType.vayDns;
        break;
      case 'sayedns':
      case 'vaydns':
        tunnelType = TunnelType.vayDns;
        break;
      default:
        tunnelType = TunnelType.vayDns;
    }

    final server = p.length > 2 ? p[2] : '';
    final domain = p.length > 3 ? p[3] : server;

    String dnsResolver = '1.1.1.1';
    if (p.length > 4 && p[4].isNotEmpty) {
      dnsResolver = p[4].split(':').first;
    }

    final password = (p.length > 11 && p[11].isNotEmpty) ? p[11] : null;
    final sshPort = (p.length > 15) ? int.tryParse(p[15]) : null;
    final mtu = (p.length > 8) ? int.tryParse(p[8]) : null;

    DnsTransport dnsTransport = DnsTransport.classic;
    if (p.length > 25) {
      switch (p[25].toLowerCase()) {
        case 'doh':
          dnsTransport = DnsTransport.doh;
          break;
        case 'dot':
          dnsTransport = DnsTransport.dot;
          break;
        case 'tcp':
          dnsTransport = DnsTransport.tcp;
          break;
        default:
          dnsTransport = DnsTransport.classic;
      }
    }

    return Profile(
      id: const Uuid().v4(),
      name: server.isNotEmpty ? server : 'Imported',
      tunnelType: tunnelType,
      server: server,
      port: 53,
      domain: domain,
      password: password,
      dnsResolver: dnsResolver,
      dnsTransport: dnsTransport,
      recordType: DnsRecordType.txt,
      queryLength: 101,
      connectionMethod: (tunnelType == TunnelType.vayDnsSsh || tunnelType == TunnelType.ssh)
          ? ConnectionMethod.ssh
          : ConnectionMethod.socks,
      sshPort: sshPort,
      mtu: mtu,
      isLocked: false,
    );
  }

  static Profile? _tryFromUpstreamPipeFormat(String decoded) {
    final f = decoded.split('|');
    if (f.length < 12) return null;

    final version = f[0].trim();
    final int? vNum = version.startsWith('v')
        ? int.tryParse(version.substring(1))
        : int.tryParse(version);
    if (vNum == null || vNum < 16) return null;

    final tunnelTypeRaw = f[1].toLowerCase();
    final name = f[2];
    final domain = f[3];
    final resolversRaw = f[4];
    final authMode = f.length > 5 ? (f[5] == '1') : false;
    final keepAlive = f.length > 6 ? int.tryParse(f[6]) : null;
    final localSocksPort = f.length > 8 ? int.tryParse(f[8]) : null;
    final socksPass = f.length > 13 && f[13].trim().isNotEmpty ? f[13].trim() : null;

    final sshEnabled = f.length > 14 ? (f[14] == '1') : false;
    final sshUser = f.length > 15 && f[15].trim().isNotEmpty ? f[15].trim() : null;
    final sshPassword = f.length > 16 && f[16].trim().isNotEmpty ? f[16].trim() : null;
    final sshPort = f.length > 17 ? int.tryParse(f[17]) : null;
    final sshHost = f.length > 19 && f[19].trim().isNotEmpty ? f[19].trim() : null;

    final dohUrl = f.length > 21 && f[21].trim().isNotEmpty ? f[21].trim() : null;
    final dnsTransportRaw = f.length > 22 ? f[22].trim().toLowerCase() : '';

    final firstResolverHost = resolversRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.split(':').first)
        .firstWhere((_) => true, orElse: () => '1.1.1.1');

    DnsTransport dnsTransport = DnsTransport.classic;
    switch (dnsTransportRaw) {
      case 'https':
      case 'doh':
        dnsTransport = DnsTransport.doh;
        break;
      case 'tls':
      case 'dot':
        dnsTransport = DnsTransport.dot;
        break;
      case 'tcp':
        dnsTransport = DnsTransport.tcp;
        break;
      default:
        dnsTransport = DnsTransport.classic;
    }

    TunnelType tunnelType = TunnelType.vayDns;
    if (tunnelTypeRaw == 'ssh') {
      tunnelType = TunnelType.ssh;
    } else if (tunnelTypeRaw == 'socks5') {
      tunnelType = TunnelType.socks5;
    } else if (tunnelTypeRaw.endsWith('_ssh') || sshEnabled) {
      tunnelType = TunnelType.vayDnsSsh;
    } else if (tunnelTypeRaw.endsWith('_socks') || tunnelTypeRaw.contains('socks')) {
      tunnelType = TunnelType.vayDnsSocks;
    } else {
      tunnelType = TunnelType.vayDns;
    }

    final dnsResolverValue =
        (dnsTransport == DnsTransport.doh && dohUrl != null && dohUrl.isNotEmpty)
            ? dohUrl
            : firstResolverHost;

    final bool needsSsh =
        tunnelType == TunnelType.vayDnsSsh || tunnelType == TunnelType.ssh;
    final serverValue = needsSsh ? (sshHost ?? domain) : domain;

    return Profile(
      id: const Uuid().v4(),
      name: name.isNotEmpty ? name : 'Imported',
      tunnelType: tunnelType,
      server: serverValue,
      port: 53,
      domain: domain,
      password: socksPass ?? (authMode ? 'auth' : null),
      dnsResolver: dnsResolverValue,
      dnsTransport: dnsTransport,
      recordType: DnsRecordType.txt,
      queryLength: 101,
      connectionMethod: needsSsh ? ConnectionMethod.ssh : ConnectionMethod.socks,
      sshHost: needsSsh ? (sshHost ?? domain) : null,
      sshPort: needsSsh ? (sshPort ?? 22) : null,
      sshUser: needsSsh ? sshUser : null,
      sshPassword: needsSsh ? sshPassword : null,
      mtu: localSocksPort,
      timeout: keepAlive,
      isLocked: false,
    );
  }

  static List<int> _decodeBase64Flexible(String input) {
    final normalized = input.trim().replaceAll('\n', '').replaceAll('\r', '');
    var padded = normalized;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    try {
      return base64.decode(padded);
    } catch (_) {
      return base64Url.decode(padded);
    }
  }

  // ─── Private: query-param format ───
  static Profile _fromQueryFormat(String uri) {
    final parsed = Uri.parse(uri);
    final tunnelType = TunnelType.values.firstWhere(
          (t) => t.name == parsed.userInfo,
      orElse: () => TunnelType.vayDns,
    );

    final qp = parsed.queryParameters;

    return Profile(
      id: const Uuid().v4(),
      name: qp['name'] ?? 'Imported',
      tunnelType: tunnelType,
      server: parsed.host,
      port: parsed.port == 0 ? 53 : parsed.port,
      domain: qp['domain'] ?? '',
      password: null,
      dnsResolver: qp['dnsResolver'] ?? '1.1.1.1',
      dnsTransport: DnsTransport.values.firstWhere(
            (d) => d.name == qp['dnsTransport'],
        orElse: () => DnsTransport.classic,
      ),
      recordType: DnsRecordType.fromString(qp['recordType'] ?? 'TXT'),
      queryLength: qp['queryLength'] != null ? int.tryParse(qp['queryLength']!) ?? 101 : 101,
      connectionMethod: ConnectionMethod.values.firstWhere(
        (m) => m.name == qp['connectionMethod'],
        orElse: () => (tunnelType == TunnelType.vayDnsSsh || tunnelType == TunnelType.ssh)
            ? ConnectionMethod.ssh
            : ConnectionMethod.socks,
      ),
      sshHost: qp['sshHost'],
      sshPort: qp['sshPort'] != null ? int.tryParse(qp['sshPort']!) : null,
      sshUser: qp['sshUser'],
      sshPassword: null,
      sshKey: null,
      sshCipher: qp['sshCipher'] != null
          ? SshCipher.values.firstWhere(
            (c) => c.name == qp['sshCipher'],
        orElse: () => SshCipher.chacha20Poly1305,
      )
          : null,
      sshAuthType: SshAuthType.values.firstWhere(
        (a) => a.name == qp['sshAuthType'],
        orElse: () => SshAuthType.password,
      ),
      socksUser: qp['socksUser'],
      socksPassword: null,
      compression: qp['compression'] == '1',
      mtu: qp['mtu'] != null ? int.tryParse(qp['mtu']!) : null,
      timeout: qp['timeout'] != null ? int.tryParse(qp['timeout']!) : null,
      queryRateLimit: qp['queryRateLimit'] != null ? int.tryParse(qp['queryRateLimit']!) ?? 0 : 0,
      idleTimeout: qp['idleTimeout'] != null ? int.tryParse(qp['idleTimeout']!) : null,
      udpTimeout: qp['udpTimeout'] != null ? int.tryParse(qp['udpTimeout']!) : null,
      maxLabels: qp['maxLabels'] != null ? int.tryParse(qp['maxLabels']!) : null,
      clientIdSize: qp['clientIdSize'] != null ? int.tryParse(qp['clientIdSize']!) ?? 2 : 2,
      isLocked: false,
    );
  }

  static List<Profile> listFromJson(String jsonStr) {
    final list = json.decode(jsonStr) as List<dynamic>;
    return list.map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Profile> profiles) {
    final list = profiles.map((p) => p.toJson()).toList();
    return json.encode(list);
  }
}
