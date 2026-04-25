// enum TunnelType {
//   vayDns('VayDNS', 'DNS-only tunnel'),
//   vayDnsSsh('VayDNS + SSH', 'DNS tunnel over SSH'),
//   ssh('SSH', 'Direct SSH tunnel'),
//   dnstt('DNSTT', 'DNS transport tunnel'),
//   dnsttSsh('DNSTT + SSH', 'DNSTT over SSH');
//
//   final String label;
//   final String description;
//   const TunnelType(this.label, this.description);
// }
//
// enum DnsTransport {
//   udp('UDP', 'Plain DNS (port 53)'),
//   dot('DoT', 'DNS over TLS (port 853)'),
//   doh('DoH', 'DNS over HTTPS');
//
//   final String label;
//   final String description;
//   const DnsTransport(this.label, this.description);
// }
//
// enum SshCipher {
//   aes128Ctr('aes128-ctr', 'AES-128-CTR'),
//   aes256Ctr('aes256-ctr', 'AES-256-CTR'),
//   chacha20Poly1305('chacha20-poly1305@openssh.com', 'ChaCha20-Poly1305'),
//   aes128Gcm('aes128-gcm@openssh.com', 'AES-128-GCM'),
//   aes256Gcm('aes256-gcm@openssh.com', 'AES-256-GCM');
//
//   final String algorithmName;
//   final String label;
//   const SshCipher(this.algorithmName, this.label);
// }

enum ConnectionStatus {
  disconnected('Disconnected'),
  connecting('Connecting…'),
  connected('Connected'),
  reconnecting('Reconnecting…'),
  error('Error'),
  stopping('Stopping');

  final String label;
  const ConnectionStatus(this.label);
}
