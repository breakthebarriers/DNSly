import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/dns_record_type.dart';

enum ScanProtocol { udp, tcp, doh, dot }

extension ScanProtocolX on ScanProtocol {
  String get label {
    switch (this) {
      case ScanProtocol.udp:
        return 'UDP';
      case ScanProtocol.tcp:
        return 'TCP';
      case ScanProtocol.doh:
        return 'DoH';
      case ScanProtocol.dot:
        return 'DoT';
    }
  }
}

// ── Events ──
abstract class DnsScannerEvent {}

class DnsScanStarted extends DnsScannerEvent {
  final String domain;
  final List<String> resolvers;
  final bool shuffleResolvers;
  final bool verifyHttp;
  final bool verifySsh;
  final Set<ScanProtocol> protocols;
  final DnsRecordType recordType;
  final int queryLength;

  DnsScanStarted({
    required this.domain,
    required this.resolvers,
    this.shuffleResolvers = false,
    this.verifyHttp = false,
    this.verifySsh = false,
    this.protocols = const {ScanProtocol.udp},
    this.recordType = DnsRecordType.txt,
    this.queryLength = 101,
  });
}

class DnsScanStopped extends DnsScannerEvent {}

// ── Result Model ──
class DnsScanResult {
  final String resolver;
  final int latencyMs;
  final bool success;
  final String? error;
  final String protocol; // UDP / DoH / DoT
  final bool httpOk;
  final bool sshOk;

  const DnsScanResult({
    required this.resolver,
    required this.latencyMs,
    required this.success,
    this.error,
    this.protocol = 'UDP',
    this.httpOk = false,
    this.sshOk = false,
  });
}

// ── State ──
class DnsScannerState {
  final bool isScanning;
  final List<DnsScanResult> results;
  final double progress; // 0.0 – 1.0
  final String? currentResolver;
  final bool showOnlyWorking;
  final Set<String> selectedResolvers;

  const DnsScannerState({
    this.isScanning = false,
    this.results = const [],
    this.progress = 0.0,
    this.currentResolver,
    this.showOnlyWorking = false,
    this.selectedResolvers = const {},
  });

  DnsScannerState copyWith({
    bool? isScanning,
    List<DnsScanResult>? results,
    double? progress,
    String? currentResolver,
    bool? showOnlyWorking,
    Set<String>? selectedResolvers,
  }) {
    return DnsScannerState(
      isScanning: isScanning ?? this.isScanning,
      results: results ?? this.results,
      progress: progress ?? this.progress,
      currentResolver: currentResolver,
      showOnlyWorking: showOnlyWorking ?? this.showOnlyWorking,
      selectedResolvers: selectedResolvers ?? this.selectedResolvers,
    );
  }

  DnsScanResult? get bestResult {
    final ok = results.where((r) => r.success).toList();
    if (ok.isEmpty) return null;
    ok.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    return ok.first;
  }
}

// ── Bloc ──
class DnsScannerBloc extends Bloc<DnsScannerEvent, DnsScannerState> {
  DnsScannerBloc() : super(const DnsScannerState()) {
    on<DnsScanStarted>(_onStarted);
    on<DnsScanStopped>(_onStopped);
  }

  bool _cancelled = false;

  Future<void> _onStarted(
      DnsScanStarted event,
      Emitter<DnsScannerState> emit,
      ) async {
    _cancelled = false;
    emit(state.copyWith(
      isScanning: true,
      results: [],
      progress: 0.0,
    ));

    final resolvers = _normalizeResolvers(event.resolvers);
    if (event.shuffleResolvers) {
      resolvers.shuffle(Random());
    }
    final results = <DnsScanResult>[];

    for (var i = 0; i < resolvers.length; i++) {
      if (_cancelled) break;

      final resolver = resolvers[i];
      emit(state.copyWith(
        currentResolver: resolver,
        progress: i / resolvers.length,
      ));

      final result = await _scanResolver(
        resolver: resolver,
        domain: event.domain,
        verifyHttp: event.verifyHttp,
        verifySsh: event.verifySsh,
        protocols: event.protocols,
        recordType: event.recordType,
        queryLength: event.queryLength,
      );
      if (_cancelled) break;
      results.add(result);

      emit(state.copyWith(
        results: List.of(results),
        progress: (i + 1) / resolvers.length,
      ));
    }

    emit(state.copyWith(isScanning: false, progress: 1.0));
  }

  void _onStopped(DnsScanStopped event, Emitter<DnsScannerState> emit) {
    _cancelled = true;
    emit(state.copyWith(isScanning: false));
  }

  List<String> _normalizeResolvers(List<String> resolvers) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final raw in resolvers) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) normalized.add(value);
    }
    return normalized;
  }

  Future<DnsScanResult> _scanResolver({
    required String resolver,
    required String domain,
    required bool verifyHttp,
    required bool verifySsh,
    required Set<ScanProtocol> protocols,
    required DnsRecordType recordType,
    required int queryLength,
  }) async {
    final sw = Stopwatch()..start();
    final endpoint = _parseResolverEndpoint(resolver);
    try {
      final selected = protocols.isEmpty ? {ScanProtocol.udp} : protocols;
      bool ok = false;
      String protocolLabel = selected.first.label;
      for (final protocol in selected) {
        final pass = await _scanWithProtocol(
          endpoint: endpoint,
          domain: domain,
          protocol: protocol,
          recordType: recordType,
          queryLength: queryLength,
        );
        if (pass) {
          ok = true;
          protocolLabel = protocol.label;
          break;
        }
      }
      sw.stop();
      if (!ok) {
        return DnsScanResult(
          resolver: resolver,
          latencyMs: 0,
          success: false,
          error: 'No answer',
          protocol: protocolLabel,
        );
      }

      final httpOk = verifyHttp ? await _verifyPort(endpoint.host, endpoint.httpPort) : false;
      final sshOk = verifySsh ? await _verifyPort(endpoint.host, 22) : false;

      return DnsScanResult(
        resolver: resolver,
        latencyMs: sw.elapsedMilliseconds,
        success: true,
        protocol: protocolLabel,
        httpOk: httpOk,
        sshOk: sshOk,
      );
    } on TimeoutException {
      sw.stop();
      return DnsScanResult(
        resolver: resolver,
        latencyMs: 0,
        success: false,
        error: 'Timeout',
        protocol: selectedProtocolLabel(protocols),
      );
    } catch (e) {
      sw.stop();
      return DnsScanResult(
        resolver: resolver,
        latencyMs: 0,
        success: false,
        error: e.toString(),
        protocol: selectedProtocolLabel(protocols),
      );
    }
  }

  String selectedProtocolLabel(Set<ScanProtocol> protocols) {
    if (protocols.isEmpty) return 'UDP';
    return protocols.first.label;
  }

  Future<bool> _scanWithProtocol({
    required _ResolverEndpoint endpoint,
    required String domain,
    required ScanProtocol protocol,
    required DnsRecordType recordType,
    required int queryLength,
  }) async {
    switch (protocol) {
      case ScanProtocol.udp:
        return _queryUdpDns(endpoint.host, domain, recordType, queryLength);
      case ScanProtocol.tcp:
        return _queryTcpDns(endpoint.host, domain, recordType, queryLength);
      case ScanProtocol.doh:
        return _queryDohDns(endpoint, domain, recordType, queryLength);
      case ScanProtocol.dot:
        return _queryDotDns(endpoint.host, domain, recordType, queryLength);
    }
  }

  Future<bool> _verifyPort(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _queryUdpDns(
    String resolver,
    String domain,
    DnsRecordType recordType,
    int queryLength,
  ) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.readEventsEnabled = true;
    socket.writeEventsEnabled = false;

    final id = Random().nextInt(0xFFFF);
    final packet = _buildDnsQuery(
      domain: domain,
      id: id,
      recordType: recordType,
      queryLength: queryLength,
    );
    final target = await _resolveAddress(resolver);
    socket.send(packet, target, 53);

    try {
      final completer = Completer<bool>();
      late StreamSubscription<RawSocketEvent> sub;
      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg == null) return;
        final data = dg.data;
        if (data.length < 12) return;
        final responseId = (data[0] << 8) | data[1];
        if (responseId != id) return;
        final rcode = data[3] & 0x0F;
        completer.complete(rcode == 0 || rcode == 3);
      });
      final result = await completer.future.timeout(const Duration(seconds: 3));
      await sub.cancel();
      socket.close();
      return result;
    } catch (_) {
      socket.close();
      rethrow;
    }
  }

  Future<bool> _queryTcpDns(
    String resolver,
    String domain,
    DnsRecordType recordType,
    int queryLength,
  ) async {
    final target = await _resolveAddress(resolver);
    final socket = await Socket.connect(target, 53, timeout: const Duration(seconds: 3));
    try {
      final id = Random().nextInt(0xFFFF);
      final packet = _buildDnsQuery(
        domain: domain,
        id: id,
        recordType: recordType,
        queryLength: queryLength,
      );
      final len = packet.length;
      final framed = Uint8List(len + 2)
        ..[0] = (len >> 8) & 0xFF
        ..[1] = len & 0xFF
        ..setRange(2, len + 2, packet);
      socket.add(framed);
      await socket.flush();

      final data = await socket.first.timeout(const Duration(seconds: 3));
      if (data.length < 14) return false;
      final bodyLen = (data[0] << 8) | data[1];
      if (bodyLen <= 0 || data.length < bodyLen + 2) return false;
      final responseId = (data[2] << 8) | data[3];
      if (responseId != id) return false;
      final rcode = data[5] & 0x0F;
      return rcode == 0 || rcode == 3;
    } finally {
      socket.destroy();
    }
  }

  Future<bool> _queryDotDns(
    String resolver,
    String domain,
    DnsRecordType recordType,
    int queryLength,
  ) async {
    final target = await _resolveAddress(resolver);
    final socket = await SecureSocket.connect(
      target,
      853,
      timeout: const Duration(seconds: 4),
      onBadCertificate: (_) => true,
    );
    try {
      final id = Random().nextInt(0xFFFF);
      final packet = _buildDnsQuery(
        domain: domain,
        id: id,
        recordType: recordType,
        queryLength: queryLength,
      );
      final len = packet.length;
      final framed = Uint8List(len + 2)
        ..[0] = (len >> 8) & 0xFF
        ..[1] = len & 0xFF
        ..setRange(2, len + 2, packet);
      socket.add(framed);
      await socket.flush();

      final data = await socket.first.timeout(const Duration(seconds: 4));
      if (data.length < 14) return false;
      final responseId = (data[2] << 8) | data[3];
      if (responseId != id) return false;
      final rcode = data[5] & 0x0F;
      return rcode == 0 || rcode == 3;
    } finally {
      socket.destroy();
    }
  }

  Future<bool> _queryDohDns(
    _ResolverEndpoint endpoint,
    String domain,
    DnsRecordType recordType,
    int queryLength,
  ) async {
    final id = Random().nextInt(0xFFFF);
    final packet = _buildDnsQuery(
      domain: domain,
      id: id,
      recordType: recordType,
      queryLength: queryLength,
    );
    final url = endpoint.dohUrl ?? 'https://${endpoint.host}/dns-query';
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 4));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/dns-message');
      req.headers.set(HttpHeaders.acceptHeader, 'application/dns-message');
      req.add(packet);
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final body = await res.fold<List<int>>(<int>[], (p, e) => p..addAll(e));
      if (body.length < 12) return false;
      final responseId = (body[0] << 8) | body[1];
      if (responseId != id) return false;
      final rcode = body[3] & 0x0F;
      return rcode == 0 || rcode == 3;
    } finally {
      client.close(force: true);
    }
  }

  Future<InternetAddress> _resolveAddress(String resolver) async {
    final parsed = InternetAddress.tryParse(resolver);
    if (parsed != null) return parsed;
    final looked = await InternetAddress.lookup(resolver);
    if (looked.isEmpty) {
      throw const SocketException('Could not resolve resolver host');
    }
    return looked.first;
  }

  _ResolverEndpoint _parseResolverEndpoint(String raw) {
    if (raw.startsWith('https://')) {
      final uri = Uri.tryParse(raw);
      return _ResolverEndpoint(
        host: uri?.host ?? raw,
        protocol: 'DoH',
        httpPort: uri?.port == 0 || uri?.port == null ? 443 : uri!.port,
        dohUrl: raw,
      );
    }
    if (raw.startsWith('tls://')) {
      final uri = Uri.tryParse(raw);
      return _ResolverEndpoint(
        host: uri?.host ?? raw,
        protocol: 'DoT',
        httpPort: 443,
        dohUrl: null,
      );
    }
    return _ResolverEndpoint(host: raw, protocol: 'UDP', httpPort: 80, dohUrl: null);
  }

  Uint8List _buildDnsQuery({
    required String domain,
    required int id,
    required DnsRecordType recordType,
    required int queryLength,
  }) {
    final qname = _buildQueryName(domain, queryLength.clamp(30, 253));
    final bytes = <int>[
      (id >> 8) & 0xFF,
      id & 0xFF,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ];
    for (final label in qname.split('.')) {
      final part = label.trim();
      if (part.isEmpty) continue;
      bytes.add(part.length);
      bytes.addAll(part.codeUnits);
    }
    bytes.add(0x00); // QNAME terminator
    bytes.addAll(_recordTypeToQType(recordType));
    bytes.addAll([0x00, 0x01]); // QCLASS IN
    return Uint8List.fromList(bytes);
  }

  String _buildQueryName(String domain, int queryLength) {
    final base = domain.trim().isEmpty ? 'example.com' : domain.trim();
    final baseWireLen = _wireLength(base);
    if (queryLength <= baseWireLen) return base;

    final rng = Random();
    final labels = <String>[];
    var current = baseWireLen;
    while (current < queryLength - 2) {
      final remaining = queryLength - current - 1;
      final labelLen = remaining.clamp(1, 10);
      final label = List.generate(
        labelLen,
        (_) => String.fromCharCode(97 + rng.nextInt(26)),
      ).join();
      labels.add(label);
      current += labelLen + 1;
    }
    if (labels.isEmpty) return base;
    return '${labels.join('.')}.$base';
  }

  int _wireLength(String domain) {
    var len = 1;
    for (final p in domain.split('.')) {
      if (p.isEmpty) continue;
      len += 1 + p.length;
    }
    return len;
  }

  List<int> _recordTypeToQType(DnsRecordType type) {
    switch (type) {
      case DnsRecordType.txt:
        return [0x00, 0x10];
      case DnsRecordType.cname:
        return [0x00, 0x05];
      case DnsRecordType.a:
        return [0x00, 0x01];
      case DnsRecordType.aaaa:
        return [0x00, 0x1C];
      case DnsRecordType.mx:
        return [0x00, 0x0F];
      case DnsRecordType.ns:
        return [0x00, 0x02];
      case DnsRecordType.srv:
        return [0x00, 0x21];
      case DnsRecordType.nullRecord:
        return [0x00, 0x0A];
      case DnsRecordType.caa:
        return [0x01, 0x01];
    }
  }
}

class _ResolverEndpoint {
  final String host;
  final String protocol;
  final int httpPort;
  final String? dohUrl;

  const _ResolverEndpoint({
    required this.host,
    required this.protocol,
    required this.httpPort,
    required this.dohUrl,
  });
}
