enum DnsRecordType {
  txt('TXT', 'Standard text records'),
  cname('CNAME', 'Canonical name aliases'),
  a('A', 'IPv4 address records'),
  aaaa('AAAA', 'IPv6 address records'),
  mx('MX', 'Mail exchange records'),
  ns('NS', 'Name server records'),
  srv('SRV', 'Service locator records'),
  nullRecord('NULL', 'Null/experimental records'),
  caa('CAA', 'Certificate authority records');

  final String label;
  final String description;
  const DnsRecordType(this.label, this.description);

  static DnsRecordType fromString(String s) {
    return DnsRecordType.values.firstWhere(
          (e) => e.label.toLowerCase() == s.toLowerCase(),
      orElse: () => DnsRecordType.txt,
    );
  }
}
