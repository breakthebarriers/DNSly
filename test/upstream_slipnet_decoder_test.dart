import 'dart:convert';

import 'package:dnsly_app/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Profile.fromSlipnetUri parses upstream v18 pipe format', () {
    final pipe = [
      'v18',
      'sayedns_ssh',
      'My Profile',
      't.example.com',
      '8.8.8.8:53:0,1.1.1.1:53:0',
      '1',
      '25',
      'bbr',
      '10880',
      '127.0.0.1',
      '0',
      'deadbeef',
      '',
      'socksPass',

      '1',
      'sshUser',
      'sshPass',
      '2222',
      '',
      'ssh.example.com',

      '',
      'https://cloudflare-dns.com/dns-query',
      'https',
    ].join('|');

    final uri = 'slipnet://${base64.encode(utf8.encode(pipe))}';
    final p = Profile.fromSlipnetUri(uri);

    expect(p.name, 'My Profile');
    expect(p.domain, 't.example.com');
    expect(p.server, 'ssh.example.com');
    expect(p.dnsResolver, 'https://cloudflare-dns.com/dns-query');
    expect(p.dnsTransport, DnsTransport.doh);
    expect(p.tunnelType, TunnelType.vayDnsSsh);
    expect(p.sshHost, 'ssh.example.com');
    expect(p.sshPort, 2222);
    expect(p.sshUser, 'sshUser');
    expect(p.sshPassword, 'sshPass');
    expect(p.password, 'socksPass');
    expect(p.timeout, 25);
    expect(p.mtu, 10880);
  });

  test('Profile.fromSlipnetUri parses numeric-version pipe format', () {
    final pipe = [
      '22',
      'vaydns_ssh',
      'vaydns',
      'ds.tirexnet.eu.cc',
      '8.8.8.8:53:0',
      '0',
      '5000',
      'bbr',
      '1080',
      '127.0.0.1',
      '0',
      '5cd3c8b72a50651c621be713e3230622e8c461619acf5fc12801fb93e63a891a',
      'user1',
      '1t3pG4BXohSUuf9z',
      '1',
      'user1',
      '1t3pG4BXohSUuf9z',
      '22',
      '0',
      '91.107.164.62',
      '0',
      '',
      'udp',
    ].join('|');

    final uri = 'slipnet://${base64.encode(utf8.encode(pipe))}';
    final p = Profile.fromSlipnetUri(uri);

    expect(p.name, 'vaydns');
    expect(p.domain, 'ds.tirexnet.eu.cc');
    expect(p.tunnelType, TunnelType.vayDnsSsh);
    expect(p.server, '91.107.164.62');
    expect(p.sshHost, '91.107.164.62');
    expect(p.sshPort, 22);
    expect(p.sshUser, 'user1');
    expect(p.sshPassword, '1t3pG4BXohSUuf9z');
    expect(p.dnsResolver, '8.8.8.8');
    expect(p.dnsTransport, DnsTransport.classic);
    expect(p.mtu, 1080);
    expect(p.timeout, 5000);
    expect(p.password, '1t3pG4BXohSUuf9z');
  });
}

