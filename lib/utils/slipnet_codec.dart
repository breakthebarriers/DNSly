import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';
import '../models/profile.dart';

class SlipnetCodec {
  static const _plainScheme = 'slipnet';
  static const _encScheme = 'slipnet-enc';
  static const int _encFormatVersion = 0x01;
  static const int _gcmIvLength = 12;
  static const int _gcmTagLength = 16;

  static Map<String, dynamic>? _decodeEncryptedEnvelope(String uri) {
    try {
      if (!uri.startsWith('$_encScheme://')) return null;
      final payload = uri.substring('$_encScheme://'.length);
      final envelopeStr = utf8.decode(_decodeBase64Flexible(payload));
      final envelope = jsonDecode(envelopeStr);
      if (envelope is! Map<String, dynamic>) return null;
      return envelope;
    } catch (_) {
      return null;
    }
  }

  /// True when the encrypted link carries plaintext metadata.
  static bool hasEncryptedMeta(String uri) {
    final envelope = _decodeEncryptedEnvelope(uri);
    return envelope != null && envelope['meta'] is Map<String, dynamic>;
  }

  /// For `slipnet-enc://` we keep the full profile JSON encrypted, but include
  /// a plaintext "meta" section so imports can show populated fields without
  /// requiring a password. (Editing/unlocking still requires the password.)
  static Map<String, dynamic> _profileToMeta(Profile profile) => {
        'name': profile.name,
        'tunnelType': profile.tunnelType.name,
        'server': profile.server,
        'port': profile.port,
        'domain': profile.domain,
        'password': profile.password,
        'dnsResolver': profile.dnsResolver,
        'dnsTransport': profile.dnsTransport.name,
        'recordType': profile.recordType.label,
        'queryLength': profile.queryLength,
        'connectionMethod': profile.connectionMethod.name,
        'sshHost': profile.sshHost,
        'sshPort': profile.sshPort,
        'sshUser': profile.sshUser,
        'sshPassword': profile.sshPassword,
        'sshKey': profile.sshKey,
        'sshCipher': profile.sshCipher?.name,
        'sshAuthType': profile.sshAuthType.name,
        'socksUser': profile.socksUser,
        'socksPassword': profile.socksPassword,
        'compression': profile.compression,
        'mtu': profile.mtu,
        'timeout': profile.timeout,
      };

  /// Profile → slipnet://BASE64
  static String encode(Profile profile) {
    final json = profile.toJson();
    final jsonStr = jsonEncode(json);
    final b64 = base64Url.encode(utf8.encode(jsonStr));
    return '$_plainScheme://$b64';
  }

  /// Profile + password -> slipnet-enc://BASE64
  static String encodeEncrypted(Profile profile, String password) {
    final normalizedPassword = password.trim();
    if (normalizedPassword.isEmpty) {
      throw const FormatException('Password is required for encrypted export');
    }

    final jsonStr = jsonEncode(profile.toJson());
    final key = _deriveKey(normalizedPassword);
    final iv = enc.IV.fromSecureRandom(16);
    final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = cipher.encrypt(jsonStr, iv: iv);

    final envelope = jsonEncode({
      'v': 2,
      'iv': iv.base64,
      'ct': encrypted.base64,
      'meta': _profileToMeta(profile),
    });
    // URL-safe output (still accepts non-url-safe input during decode).
    final payload = base64Url.encode(utf8.encode(envelope));
    return '$_encScheme://$payload';
  }

  /// slipnet://BASE64 → Profile
  static Profile? decode(String uri) {
    try {
      if (!uri.startsWith('$_plainScheme://')) return null;
      final b64 = uri.substring('$_plainScheme://'.length);
      final jsonStr = utf8.decode(_decodeBase64Flexible(b64));
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Profile.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// slipnet-enc://BASE64 + password → Profile
  static Profile? decodeEncrypted(String uri, String password) {
    try {
      if (!uri.startsWith('$_encScheme://')) return null;
      final normalizedPassword = password.trim();
      if (normalizedPassword.isEmpty) return null;

      final envelope = _decodeEncryptedEnvelope(uri);
      if (envelope != null) {
        final ivB64 = envelope['iv'] as String?;
        final ctB64 = envelope['ct'] as String?;
        if (ivB64 == null || ctB64 == null) return null;
        final key = _deriveKey(normalizedPassword);
        final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final decrypted = cipher.decrypt64(ctB64, iv: enc.IV.fromBase64(ivB64));
        final json = jsonDecode(decrypted) as Map<String, dynamic>;
        return Profile.fromJson(json);
      }

      final upstream = _decodeUpstreamEncrypted(uri, normalizedPassword);
      return upstream;
    } catch (_) {
      return null;
    }
  }

  static Profile? _decodeUpstreamEncrypted(String uri, String password) {
    try {
      final key32 = _parseHexKey32(password);
      if (key32 == null) return null;
      final payload = uri.substring('$_encScheme://'.length);
      final data = _decodeBase64Flexible(payload);
      if (data.isEmpty || data[0] != _encFormatVersion) return null;
      final minLen = 1 + _gcmIvLength + _gcmTagLength;
      if (data.length < minLen) return null;

      final iv = data.sublist(1, 1 + _gcmIvLength);
      final cipherAndTag = data.sublist(1 + _gcmIvLength);

      final gcm = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(key32),
            _gcmTagLength * 8,
            iv,
            Uint8List(0),
          ),
        );

      final out = Uint8List(gcm.getOutputSize(cipherAndTag.length));
      final len = gcm.processBytes(
        cipherAndTag,
        0,
        cipherAndTag.length,
        out,
        0,
      );
      gcm.doFinal(out, len);

      final pipe = utf8.decode(out);
      final uri2 = '$_plainScheme://${base64.encode(utf8.encode(pipe))}';
      return Profile.fromSlipnetUri(uri2);
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _parseHexKey32(String input) {
    final s = input.trim();
    final hexRe = RegExp(r'^[0-9a-fA-F]{64}$');
    if (!hexRe.hasMatch(s)) return null;
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      final byteStr = s.substring(i * 2, i * 2 + 2);
      out[i] = int.parse(byteStr, radix: 16);
    }
    return out;
  }

  /// slipnet-enc://BASE64 → Profile metadata (no password).
  ///
  /// Returns null if the payload is invalid or has no metadata.
  static Profile? decodeEncryptedMeta(String uri) {
    try {
      if (!uri.startsWith('$_encScheme://')) return null;
      final envelope = _decodeEncryptedEnvelope(uri);
      if (envelope == null) return null;
      final meta = envelope['meta'];
      if (meta is! Map<String, dynamic>) return null;

      final normalized = <String, dynamic>{
        'id': null,
        'isLocked': true,
        ...meta,
      };
      return Profile.fromJson(normalized);
    } catch (_) {
      return null;
    }
  }

  /// Validate URI format
  static bool isValid(String uri) {
    if (!(uri.startsWith('$_plainScheme://') ||
        uri.startsWith('$_encScheme://'))) {
      return false;
    }
    try {
      final b64 = uri.substring(uri.indexOf('://') + 3);
      _decodeBase64Flexible(b64);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool isEncrypted(String uri) => uri.startsWith('$_encScheme://');

  static enc.Key _deriveKey(String password) {
    final digest = sha256.convert(utf8.encode(password));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  static Uint8List _decodeBase64Flexible(String input) {
    final normalized = input.trim().replaceAll('\n', '').replaceAll('\r', '');
    final padded = _padBase64(normalized);
    try {
      return base64Url.decode(padded);
    } catch (_) {
      return base64.decode(padded);
    }
  }

  static String _padBase64(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return '$value${'=' * (4 - remainder)}';
  }
}
