import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dnsly_app/utils/slipnet_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SlipnetCodec.decodeEncrypted supports upstream AES-GCM', () async {
    final keyHex =
        '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
    final keyBytes = Uint8List.fromList(List.generate(32, (i) {
      final s = keyHex.substring(i * 2, i * 2 + 2);
      return int.parse(s, radix: 16);
    }));

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
      'deadbeef',
      'user1',
      'pass1',
      '1',
      'user1',
      'pass1',
      '22',
      '0',
      '91.107.164.62',
      '0',
      '',
      'udp',
    ].join('|');

    final nonce = Uint8List.fromList(List.generate(12, (i) => 12 - i));
    final algo = AesGcm.with256bits();
    final secretKey = SecretKey(keyBytes);
    final box = await algo.encrypt(
      utf8.encode(pipe),
      secretKey: secretKey,
      nonce: nonce,
    );

    final blob = <int>[
      0x01,
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ];

    final uri = 'slipnet-enc://${base64.encode(blob)}';
    final p = SlipnetCodec.decodeEncrypted(uri, keyHex);

    expect(p, isNotNull);
    expect(p!.name, 'vaydns');
    expect(p.domain, 'ds.tirexnet.eu.cc');
    expect(p.server, '91.107.164.62');
  });
}

