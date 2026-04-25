enum DnsRecordType { txt, cname, a, aaaa, mx, ns, srv, nul, caa }

extension DnsRecordTypeX on DnsRecordType {
  String get label => switch (this) {
    DnsRecordType.txt => 'TXT',
    DnsRecordType.cname => 'CNAME',
    DnsRecordType.a => 'A',
    DnsRecordType.aaaa => 'AAAA',
    DnsRecordType.mx => 'MX',
    DnsRecordType.ns => 'NS',
    DnsRecordType.srv => 'SRV',
    DnsRecordType.nul => 'NULL',
    DnsRecordType.caa => 'CAA',
  };
}

class DnsResult {
  final String resolver;
  final String domain;
  final DnsRecordType recordType;
  final String? result;
  final Duration latency;
  final bool success;
  final double score;

  const DnsResult({
    required this.resolver,
    required this.domain,
    required this.recordType,
    this.result,
    required this.latency,
    required this.success,
    this.score = 0.0,
  });
}
