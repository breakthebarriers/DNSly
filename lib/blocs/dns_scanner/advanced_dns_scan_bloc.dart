import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'advanced_dns_scan_event.dart';
import 'advanced_dns_scan_state.dart';
import '../../models/advanced_dns_result.dart';
import '../../services/vpn_platform_service.dart';

class AdvancedDnsScanBloc
    extends Bloc<AdvancedDnsScanEvent, AdvancedDnsScanState> {
  final VPNPlatformService _platform;

  AdvancedDnsScanBloc({VPNPlatformService? platform})
      : _platform = platform ?? VPNPlatformService(),
        super(AdvancedDnsScanInitial()) {
    on<AdvancedDnsScanStarted>(_onScanStarted);
    on<AdvancedDnsScanReset>(_onReset);
  }

  Future<void> _onScanStarted(
    AdvancedDnsScanStarted event,
    Emitter<AdvancedDnsScanState> emit,
  ) async {
    emit(AdvancedDnsScanLoading(progress: 0, message: 'Initializing scan...'));

    try {
      // ── 1. Country filtering ──────────────────────────────────────────────
      List<String> resolvers = event.resolvers;
      if (event.filterCountry != null && event.filterCountry!.isNotEmpty) {
        emit(AdvancedDnsScanLoading(
          progress: 0,
          message: 'Filtering resolvers by country ${event.filterCountry}...',
        ));
        final filtered = await _platform.filterResolversByCountry(
          resolvers,
          event.filterCountry!,
        );
        // Fall back to full list if the country filter returned nothing
        // (e.g. on simulator or unknown country code).
        if (filtered.isNotEmpty) resolvers = filtered;
      }

      if (resolvers.isEmpty) {
        emit(AdvancedDnsScanFailure('No resolvers to scan'));
        return;
      }

      // ── 2. Parallel scanning with concurrency control ─────────────────────
      final total = resolvers.length;
      final results = <AdvancedDnsResult>[];
      int completed = 0;
      final sem = _Semaphore(event.concurrency.clamp(1, 20));

      final futures = resolvers.map((resolver) async {
        await sem.acquire();
        try {
          final result = await _scanResolver(
            resolver: resolver,
            domain: event.testDomain,
            testEDNS: event.testEDNS,
            testNXDOMAIN: event.testNXDOMAIN,
            testE2E: event.testE2E,
            testPrism: event.testPrism,
            prismSecret: event.prismSecret,
          );
          results.add(result);
        } finally {
          sem.release();
          completed++;
        }
      }).toList();

      // Emit progress while futures run.
      final progressTimer =
          Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (!emit.isDone) {
          emit(AdvancedDnsScanLoading(
            progress: total > 0 ? (completed * 100) ~/ total : 0,
            message: 'Scanned $completed/$total resolvers...',
          ));
        }
      });

      await Future.wait(futures);
      progressTimer.cancel();

      if (results.isEmpty) {
        emit(AdvancedDnsScanFailure('No results from scan'));
        return;
      }

      // ── 3. Re-attach calculated scores and sort ───────────────────────────
      final scored = results.map((r) {
        final s = r.calculateScore();
        return AdvancedDnsResult(
          resolver: r.resolver,
          domain: r.domain,
          recordType: r.recordType,
          latency: r.latency,
          reachable: r.reachable,
          supportsEDNS: r.supportsEDNS,
          nxdomainHijacked: r.nxdomainHijacked,
          tunnelOK: r.tunnelOK,
          dnsResolutionOK: r.dnsResolutionOK,
          throughputBps: r.throughputBps,
          packetLoss: r.packetLoss,
          prismVerified: r.prismVerified,
          score: s,
          error: r.error,
          country: r.country,
        );
      }).toList();

      scored.sort((a, b) => b.score.compareTo(a.score));

      final avg =
          scored.map((r) => r.score).reduce((a, b) => a + b) / scored.length;

      emit(AdvancedDnsScanSuccess(
        results: scored,
        averageScore: avg,
        topResolverName: scored.first.resolver,
      ));
    } catch (e) {
      emit(AdvancedDnsScanFailure(e.toString()));
    }
  }

  void _onReset(
      AdvancedDnsScanReset event, Emitter<AdvancedDnsScanState> emit) {
    emit(AdvancedDnsScanInitial());
  }

  // ── Per-resolver scan ────────────────────────────────────────────────────

  Future<AdvancedDnsResult> _scanResolver({
    required String resolver,
    required String domain,
    required bool testEDNS,
    required bool testNXDOMAIN,
    required bool testE2E,
    required bool testPrism,
    String? prismSecret,
  }) async {
    const timeout = Duration(seconds: 4);

    // TCP reachability + latency
    final sw = Stopwatch()..start();
    bool reachable = false;
    try {
      final sock = await Socket.connect(resolver, 53, timeout: timeout);
      sock.destroy();
      reachable = true;
    } catch (_) {}
    sw.stop();
    final latency = sw.elapsed;

    if (!reachable) {
      return AdvancedDnsResult(
        resolver: resolver,
        domain: domain,
        recordType: 'A',
        latency: latency,
        reachable: false,
        error: 'Unreachable',
      );
    }

    // DNS resolution test (UDP A query)
    bool dnsOK = false;
    try {
      dnsOK = await _udpDnsQuery(
        resolver: resolver,
        domain: domain,
        withEdns: false,
        timeout: timeout,
        expectAnswer: true,
      );
    } catch (_) {}

    // EDNS probe
    bool supportsEDNS = false;
    if (testEDNS) {
      try {
        supportsEDNS = await _probeEdns(resolver, domain, timeout);
      } catch (_) {}
    }

    // NXDOMAIN hijacking check
    bool nxdomainHijacked = false;
    if (testNXDOMAIN) {
      try {
        nxdomainHijacked = await _checkNxdomain(resolver, domain, timeout);
      } catch (_) {}
    }

    // ── E2E tunnel test (via Go engine through platform channel) ─────────────
    bool tunnelOK = false;
    double? throughputBps;
    double? packetLoss;
    if (testE2E) {
      try {
        final r = await _platform.scanResolver(
          resolver,
          domain,
          timeoutSec: 6,
        );
        if (r != null) {
          tunnelOK = (r['tunnelOK'] as bool?) ?? false;
          throughputBps = (r['throughputBps'] as num?)?.toDouble();
          packetLoss = (r['packetLoss'] as num?)?.toDouble();
          // Prefer Go's latency if available and more precise.
          // (We already have a Dart latency; keep whichever is more informative.)
        } else {
          // Non-iOS / simulator fallback: treat DNS resolution as E2E proxy.
          tunnelOK = dnsOK;
        }
      } catch (_) {
        tunnelOK = dnsOK;
      }
    }

    // ── Prism mode verification (via Go engine) ───────────────────────────────
    bool prismVerified = false;
    if (testPrism && prismSecret != null && prismSecret.isNotEmpty) {
      try {
        prismVerified = await _platform.verifyPrismServer(
          resolver,
          domain,
          prismSecret,
          resolver, // use resolver IP as serverID
          timeoutSec: 5,
        );
      } catch (_) {}
    }

    return AdvancedDnsResult(
      resolver: resolver,
      domain: domain,
      recordType: 'A',
      latency: latency,
      reachable: true,
      supportsEDNS: supportsEDNS,
      nxdomainHijacked: nxdomainHijacked,
      tunnelOK: tunnelOK,
      dnsResolutionOK: dnsOK,
      throughputBps: throughputBps,
      packetLoss: packetLoss,
      prismVerified: prismVerified,
    );
  }

  // ── DNS packet helpers (pure Dart, no platform channel needed) ───────────

  Future<bool> _udpDnsQuery({
    required String resolver,
    required String domain,
    required bool withEdns,
    required Duration timeout,
    required bool expectAnswer,
  }) async {
    final packet = _buildAQuery(domain, withEdns: withEdns);
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.send(packet, InternetAddress(resolver), 53);
    final completer = Completer<bool>();
    late StreamSubscription sub;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    sub = sock.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = sock.receive();
        if (dg != null && dg.data.length >= 12) {
          final ancount = (dg.data[6] << 8) | dg.data[7];
          if (!completer.isCompleted) {
            completer.complete(expectAnswer ? ancount > 0 : true);
          }
        }
      }
    });
    final result = await completer.future;
    timer.cancel();
    sub.cancel();
    sock.close();
    return result;
  }

  Future<bool> _probeEdns(
      String resolver, String domain, Duration timeout) async {
    final packet = _buildAQuery(domain, withEdns: true);
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.send(packet, InternetAddress(resolver), 53);
    final completer = Completer<bool>();
    late StreamSubscription sub;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    sub = sock.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = sock.receive();
        if (dg != null) {
          if (!completer.isCompleted) {
            completer.complete(_responseHasOpt(dg.data));
          }
        }
      }
    });
    final result = await completer.future;
    timer.cancel();
    sub.cancel();
    sock.close();
    return result;
  }

  Future<bool> _checkNxdomain(
      String resolver, String domain, Duration timeout) async {
    final nxDomain = 'nxcheck-dnsly-probe-xz9q.$domain';
    final packet = _buildAQuery(nxDomain, withEdns: false);
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.send(packet, InternetAddress(resolver), 53);
    final completer = Completer<bool>();
    late StreamSubscription sub;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    sub = sock.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = sock.receive();
        if (dg != null && dg.data.length >= 12) {
          final rcode = dg.data[3] & 0x0f;
          final ancount = (dg.data[6] << 8) | dg.data[7];
          if (!completer.isCompleted) {
            completer.complete(rcode == 0 && ancount > 0);
          }
        }
      }
    });
    final result = await completer.future;
    timer.cancel();
    sub.cancel();
    sock.close();
    return result;
  }

  bool _responseHasOpt(Uint8List data) {
    if (data.length < 12) return false;
    final qdcount = (data[4] << 8) | data[5];
    final ancount = (data[6] << 8) | data[7];
    final nscount = (data[8] << 8) | data[9];
    final arcount = (data[10] << 8) | data[11];
    int offset = 12;
    final total = qdcount + ancount + nscount + arcount;
    for (int i = 0; i < total; i++) {
      if (offset >= data.length) return false;
      offset = _skipName(data, offset);
      if (offset + 4 > data.length) return false;
      final rtype = (data[offset] << 8) | data[offset + 1];
      offset += 2;
      offset += 2; // class
      if (i >= qdcount) {
        if (offset + 6 > data.length) return false;
        offset += 4; // TTL
        final rdlen = (data[offset] << 8) | data[offset + 1];
        offset += 2 + rdlen;
        if (rtype == 41) return true;
      }
    }
    return false;
  }

  int _skipName(Uint8List data, int offset) {
    while (offset < data.length) {
      final len = data[offset];
      if (len == 0) return offset + 1;
      if ((len & 0xc0) == 0xc0) return offset + 2;
      offset += 1 + len;
    }
    return offset;
  }

  Uint8List _buildAQuery(String domain, {required bool withEdns}) {
    final labels = domain.split('.');
    final nameBytes = <int>[];
    for (final label in labels) {
      nameBytes.add(label.length);
      nameBytes.addAll(label.codeUnits);
    }
    nameBytes.add(0);

    final qSection = nameBytes + [0, 1, 0, 1];

    final optRecord = withEdns
        ? [0, 0, 41, 16, 0, 0, 0, 0, 0, 0, 0]
        : <int>[];

    final header = [
      0x12, 0x34,
      0x01, 0x00,
      0x00, 0x01,
      0x00, 0x00,
      0x00, 0x00,
      0x00, withEdns ? 1 : 0,
    ];

    return Uint8List.fromList(header + qSection + optRecord);
  }
}

// ── Semaphore for concurrency control ────────────────────────────────────────

class _Semaphore {
  final int _max;
  int _count = 0;
  final Queue<Completer<void>> _waiters = Queue();

  _Semaphore(this._max);

  Future<void> acquire() {
    if (_count < _max) {
      _count++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _count--;
    }
  }
}
