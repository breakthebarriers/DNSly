class AdvancedDnsResult {
  final String resolver;
  final String domain;
  final String recordType;
  final Duration latency;
  final bool reachable;
  final bool supportsEDNS;
  final bool nxdomainHijacked;
  final bool tunnelOK;
  final bool dnsResolutionOK;
  final double? throughputBps;
  final double? packetLoss;
  final bool prismVerified;
  final double score;
  final String? error;
  final DateTime timestamp;
  final String? country;

  const AdvancedDnsResult({
    required this.resolver,
    required this.domain,
    required this.recordType,
    required this.latency,
    required this.reachable,
    this.supportsEDNS = false,
    this.nxdomainHijacked = false,
    this.tunnelOK = false,
    this.dnsResolutionOK = false,
    this.throughputBps,
    this.packetLoss,
    this.prismVerified = false,
    this.score = 0.0,
    this.error,
    DateTime? timestamp,
    this.country,
  }) : timestamp = timestamp ?? DateTime.now();

  // Calculate composite score based on all factors
  double calculateScore() {
    double score = 0;

    // Latency points (0-20): lower is better
    if (latency.inMilliseconds < 10) {
      score += 20;
    } else if (latency.inMilliseconds < 50) {
      score += 15;
    } else if (latency.inMilliseconds < 100) {
      score += 10;
    } else if (latency.inMilliseconds < 200) {
      score += 5;
    }

    // Reachability (0-15)
    if (reachable) {
      score += 15;
    }

    // EDNS support (0-15)
    if (supportsEDNS) {
      score += 15;
    }

    // No hijacking (0-20)
    if (!nxdomainHijacked) {
      score += 20;
    }

    // Tunnel works (0-15)
    if (tunnelOK && dnsResolutionOK) {
      score += 15;
    }

    // Good throughput (0-10)
    if (throughputBps != null && throughputBps! > 1000000) {
      score += 10; // > 1 Mbps
    } else if (throughputBps != null && throughputBps! > 100000) {
      score += 5;  // > 100 Kbps
    }

    // Low packet loss (0-10)
    if (packetLoss != null) {
      if (packetLoss! < 0.01) {
        score += 10; // < 1%
      } else if (packetLoss! < 0.05) {
        score += 5;  // < 5%
      }
    }

    // Prism verified (0-10)
    if (prismVerified) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  // Summary for UI display
  String get summary {
    if (!reachable) return 'Unreachable';
    if (nxdomainHijacked) return 'NXDOMAIN Hijacked';
    if (!dnsResolutionOK) return 'No Resolution';
    if (!supportsEDNS) return 'No EDNS Support';
    if (!tunnelOK) return 'Tunnel Failed';
    return 'OK';
  }

  // Status icon indicator
  String get statusIcon {
    if (!reachable) return '❌';
    if (nxdomainHijacked) return '⚠️';
    if (!dnsResolutionOK) return '❌';
    if (score >= 80) return '✅';
    if (score >= 60) return '⚠️';
    return '❓';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedDnsResult &&
          runtimeType == other.runtimeType &&
          resolver == other.resolver &&
          domain == other.domain &&
          recordType == other.recordType;

  @override
  int get hashCode =>
      resolver.hashCode ^ domain.hashCode ^ recordType.hashCode;
}
