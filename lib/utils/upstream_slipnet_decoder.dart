import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'upstream_slipnet_profile.dart';

class UpstreamSlipNetDecoder {
  static const String scheme = 'slipnet://';
  static const String encScheme = 'slipnet-enc://';

  static const int _encFormatVersion = 0x01;
  static const int _gcmIvLength = 12;
  static const int _gcmTagLength = 16;

  static Future<UpstreamSlipNetProfile> decodeUri(
    String uri, {
    Uint8List? encKey32,
  }) async {
    final normalized = uri.trim();
    final bool encrypted;
    final String b64;

    if (normalized.startsWith(encScheme)) {
      encrypted = true;
      b64 = _stripWhitespace(normalized.substring(encScheme.length));
    } else if (normalized.startsWith(scheme)) {
      encrypted = false;
      b64 = _stripWhitespace(normalized.substring(scheme.length));
    } else {
      throw const FormatException(
        'Invalid URI scheme. Expected slipnet:// or slipnet-enc://',
      );
    }

    final rawBytes = _decodeBase64Flexible(b64);

    final Uint8List decodedBytes;
    if (encrypted) {
      final key = encKey32;
      if (key == null || key.length != 32) {
        throw const FormatException(
          'slipnet-enc:// requires a 32-byte AES key (encKey32).',
        );
      }
      decodedBytes = await _decryptEncBlob(rawBytes, key);
    } else {
      decodedBytes = rawBytes;
    }

    final decodedStr = utf8.decode(decodedBytes, allowMalformed: false);
    final fields = decodedStr.split('|');
    if (fields.length < 12) {
      throw FormatException(
        'Not enough fields in profile (got ${fields.length}, need at least 12).',
      );
    }

    final version = fields[0];
    final tunnelType = fields[1];
    final name = fields[2];
    final domain = fields[3];
    final resolversRaw = fields[4];
    final publicKeyHex = fields.length > 11 && fields[11].isNotEmpty
        ? fields[11]
        : null;

    String? dohUrl;
    if (fields.length > 21 && fields[21].trim().isNotEmpty) {
      dohUrl = fields[21].trim();
    }
    String? dnsTransport;
    if (fields.length > 22 && fields[22].trim().isNotEmpty) {
      dnsTransport = fields[22].trim();
    }

    return UpstreamSlipNetProfile(
      version: version,
      tunnelType: tunnelType,
      name: name,
      domain: domain,
      resolversRaw: resolversRaw,
      publicKeyHex: publicKeyHex,
      dnsTransport: dnsTransport,
      dohUrl: dohUrl,
      fields: fields,
      decodedBytes: decodedBytes,
    );
  }

  static Future<Uint8List> _decryptEncBlob(
    Uint8List data,
    Uint8List key32,
  ) async {
    if (data.isEmpty || data[0] != _encFormatVersion) {
      throw const FormatException('Unsupported encrypted format version.');
    }
    final minLength = 1 + _gcmIvLength + _gcmTagLength;
    if (data.length < minLength) {
      throw const FormatException('Encrypted data too short.');
    }

    final iv = data.sublist(1, 1 + _gcmIvLength);
    final ciphertextAndTag = data.sublist(1 + _gcmIvLength);

    final tag = ciphertextAndTag.sublist(ciphertextAndTag.length - _gcmTagLength);
    final ciphertext =
        ciphertextAndTag.sublist(0, ciphertextAndTag.length - _gcmTagLength);

    final algo = AesGcm.with256bits();
    final secretKey = SecretKey(key32);
    try {
      final clear = await algo.decrypt(
        SecretBox(
          ciphertext,
          nonce: iv,
          mac: Mac(tag),
        ),
        secretKey: secretKey,
      );
      return Uint8List.fromList(clear);
    } catch (_) {
      throw const FormatException('Decryption failed (wrong key or corrupted data).');
    }
  }

  static String _stripWhitespace(String input) =>
      input.replaceAll(RegExp(r'\s+'), '');

  static Uint8List _decodeBase64Flexible(String input) {
    final normalized = input.trim().replaceAll('\n', '').replaceAll('\r', '');
    final padded = _padBase64(normalized);
    try {
      return Uint8List.fromList(base64.decode(padded));
    } catch (_) {
      return Uint8List.fromList(base64Url.decode(padded));
    }
  }

  static String _padBase64(String value) {
    var v = value;
    while (v.length % 4 != 0) {
      v += '=';
    }
    return v;
  }
}

