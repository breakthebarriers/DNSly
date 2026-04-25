import 'dart:typed_data';

class UpstreamSlipNetProfile {
  final String version;
  final String tunnelType;
  final String name;
  final String domain;
  final String resolversRaw;

  final String? dnsTransport;

  final String? dohUrl;

  final String? publicKeyHex;

  final List<String> fields;

  final Uint8List decodedBytes;

  const UpstreamSlipNetProfile({
    required this.version,
    required this.tunnelType,
    required this.name,
    required this.domain,
    required this.resolversRaw,
    required this.fields,
    required this.decodedBytes,
    this.dnsTransport,
    this.dohUrl,
    this.publicKeyHex,
  });

  List<UpstreamResolver> get resolvers {
    if (resolversRaw.trim().isEmpty) return const [];
    return resolversRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(UpstreamResolver.parse)
        .toList(growable: false);
  }
}

class UpstreamResolver {
  final String host;
  final int port;

  final String? extra;

  const UpstreamResolver({required this.host, required this.port, this.extra});

  static UpstreamResolver parse(String input) {
    final parts = input.split(':');
    final host = parts.isNotEmpty ? parts[0] : '';
    final port = parts.length >= 2 ? int.tryParse(parts[1]) ?? 53 : 53;
    final extra = parts.length >= 3 ? parts[2] : null;
    return UpstreamResolver(host: host, port: port, extra: extra);
  }

  @override
  String toString() => '$host:$port';
}

