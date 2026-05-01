// Embedded AES-256-GCM key for decrypting slipnet-enc:// URIs produced by the
// official SlipNet app. This 32-byte key must match the one baked into the
// SlipNet Android/iOS builds (CONFIG_ENCRYPTION_KEY in their CI secrets).
//
// HOW TO SET:
//   Replace the 64 hex characters below with the actual key hex string.
//   Example: 'a1b2c3d4e5f6....' (64 hex chars = 32 bytes)
//
// If the key is left as all-zeros, slipnet-enc:// decryption will fail and
// the app falls back to showing a locked stub (existing behaviour).

const String kSlipnetEncKeyHex =
    '0000000000000000000000000000000000000000000000000000000000000000';

/// Returns the 32-byte key, or null if the key is the placeholder (all zeros).
List<int>? slipnetEncKey() {
  if (kSlipnetEncKeyHex == '0' * 64) return null;
  final hex = kSlipnetEncKeyHex.trim();
  if (hex.length != 64) return null;
  final bytes = <int>[];
  for (var i = 0; i < 32; i++) {
    bytes.add(int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
  }
  return bytes;
}
