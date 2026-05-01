# اپلیکیشن DNSly

<div align="left">

[🇬🇧 English](README.md)

</div>

![بازدیدکنندگان](https://visitor-badge.laobi.icu/badge?page_id=breakthebarriers.DNSly)

<div dir="rtl">

**DNSly** یک کلاینت موبایل ضد سانسور است که با Flutter ساخته شده و روی مدیریت پروفایل‌های DNS/تانل تمرکز دارد. هسته‌ی تانل به Go نوشته شده، با ابزار gomobile به iOS متصل می‌شود و پروتکل‌های متعددی را پشتیبانی می‌کند.

---

## تصاویر

</div>

<div align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.25.56.png" width="200" alt="صفحه اصلی">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.05.png" width="200" alt="لیست پروفایل‌ها">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.27.png" width="200" alt="ویرایش پروفایل">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.37.png" width="200" alt="اکسپورت QR">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.27.41.png" width="200" alt="اسکنر DNS">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.28.14.png" width="200" alt="اسکنر DNS">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.28.45.png" width="200" alt="اسکنر DNS">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.29.41.png" width="200" alt="اسکنر DNS">
</div>

---

<div dir="rtl">

## معماری

ترافیک دستگاه از طریق **Tun2Socks** به یک SOCKS5 محلی هدایت می‌شود. هسته‌ی Go این ترافیک را گرفته و بسته به پروفایل انتخاب‌شده از یکی از تانل‌های زیر عبور می‌دهد:

</div>

```
iOS PacketTunnel Extension
        ↓
   Tun2Socks (userspace)
        ↓
Local SOCKS5 (127.0.0.1:PORT)  ← Go tunnel engine
        ↓
   ┌────┴────────────────────┐
   │  TunnelType selector    │
   └────┬──────┬──────┬──────┘
        │      │      │
   VayDNS   SSH    SOCKS5
  Tunnel   Proxy   Relay
```

<div dir="rtl">

**مدهای تانل:**
- **VayDNS** — ترافیک TCP را در قالب DNS TXT query رمزنگاری و ارسال می‌کند.
- **SSH Proxy** — پورت-فورواردینگ دینامیک SSH (معادل `ssh -D`).
- **SOCKS5 Relay** — پاس‌دادن مستقیم ترافیک به یک پروکسی upstream.
- **Hybrid** — ترکیب VayDNS با SSH یا SOCKS5 به عنوان fallback.

---

## پروتکل VayDNS

هر اتصال TCP به یک session چهار بایتی تصادفی تبدیل می‌شود. داده‌ها به قطعه‌های حداکثر ۱۲۰ بایتی تقسیم شده، با Base32 کدگذاری می‌شوند و به عنوان QNAME در DNS ارسال می‌شوند:

</div>

```
Upload query QNAME:
  {base32(sid[4] ‖ seq[4] ‖ [isSyn:1] ‖ payload)}.d.{domain}.

Download poll QNAME:
  {base32(sid[4] ‖ recvSeq[4])}.r.{domain}.

Example:
  AEBAGBAF3DFQQ.d.tunnel.example.com.   → TXT query (upload chunk)
  AEBAGBAF.r.tunnel.example.com.        → TXT query (poll for reply)
```

<div dir="rtl">

| فیلد | اندازه | توضیح |
|---|---|---|
| `sid` | ۴ بایت | شناسه تصادفی session برای هر اتصال TCP |
| `seq` | ۴ بایت | uint32 big-endian، به ازای هر chunk افزایش می‌یابد |
| `isSyn` | ۱ بایت | `0x01` فقط در اولین chunk (حاوی آدرس مقصد) |
| `payload` | حداکثر ۱۲۰ بایت | قطعه داده اپلیکیشن |

**فاصله polling دانلود:** ۸۰ میلی‌ثانیه

**حمل‌ونقل DNS:**

| حالت | پورت | پروتکل |
|---|---|---|
| `classic` | 53 | UDP ساده |
| `tcp` | 53 | DNS over TCP |
| `dot` | 853 | DNS-over-TLS (RFC 7858) |
| `doh` | 443 | DNS-over-HTTPS POST (RFC 8484) |

---

## پروفایل و کدک SlipNet

پروفایل‌ها به دو فرمت اکسپورت می‌شوند:

</div>

**Plain:**
```
slipnet://tunnelType@host:port?name=...&domain=...&dnsTransport=...&...
```

**Encrypted (AES-256-CBC):**
```
slipnet-enc://base64(envelope)

envelope = {
  "v": 2,
  "iv": "<base64 16-byte random IV>",
  "ct": "<base64 AES-256-CBC ciphertext>",
  "meta": { name, server, domain, ... }
}

Key derivation: SHA256(password) → 32-byte AES key
```

<div dir="rtl">

فیلد `meta` به کاربر اجازه می‌دهد بدون وارد کردن رمز، اطلاعات کلی پروفایل را ببیند. پس از وارد کردن رمز، کل پروفایل رمزگشایی می‌شود.

**فرمت قدیمی v1:**

</div>

```
0x01 | 12-byte GCM IV | AES-256-GCM(profile) | 16-byte tag
Key: raw 64-char hex string (no derivation)
```

---

<div dir="rtl">

## مدل داده

ساختار اصلی `Profile` شامل تمام پارامترهای لازم برای هر نوع تانل است:

</div>

```dart
class Profile {
  String id                  // UUID v4
  String name
  TunnelType tunnelType      // vayDns | vayDnsSsh | vayDnsSocks | ssh | socks5
  String server
  int port
  String domain

  // DNS
  String dnsResolver
  DnsTransport dnsTransport  // classic | tcp | doh | dot
  DnsRecordType recordType   // TXT (default) | A
  int queryLength

  // SSH
  String? sshHost
  int? sshPort
  String? sshUser
  String? sshPassword
  String? sshKey
  SshCipher? sshCipher
  SshAuthType sshAuthType

  // SOCKS5
  String? socksUser
  String? socksPassword

  // Network
  bool compression
  int? mtu
  int? timeout

  bool isLocked
  String? encryptedUri
}
```

---

<div dir="rtl">

## مدیریت State (BLoC)

اپلیکیشن از سه BLoC اصلی برای مدیریت state استفاده می‌کند:

### ConnectionBloc

</div>

```dart
Events:
  ConnectionStarted(Profile)
  ConnectionStopped()
  ConnectionStatsUpdated(bytesIn, bytesOut, uptime, latencyMs)
  ConnectionErrorOccurred(String message)
  ConnectionNativeStatusChanged(String status, String? error)

State:
  ConnectionStatus   // disconnected | connecting | connected | stopping | error
  Profile? activeProfile
  int bytesIn / bytesOut
  Duration uptime
  int latencyMs
  List<String> logs
```

### ProfileBloc

```dart
Events:
  ProfilesLoaded()
  ProfileAdded(Profile)
  ProfileUpdated(Profile)
  ProfileDeleted(String id)
  ProfileActivated(Profile)
  ProfileImported(String uris)
  ProfileImportedEncrypted(uri, password)
  EncryptedProfileUnlockRequested(uri, password)

State:
  ProfileStatus
  List<Profile> profiles
  Profile? activeProfile
  String? pendingEncryptedPayload
  String? importError
```

### DnsScannerBloc

```dart
Events:
  DnsScanStarted(List<String> resolvers)
  DnsScanReset()

States:
  DnsScannerInitial | DnsScannerLoading
  DnsScannerSuccess(fastestResolver, latencyMs)
  DnsScannerFailure(message)
```

<div dir="rtl">

اسکنر DNS به صورت موازی به پورت ۵۳ همه‌ی resolverها وصل می‌شود و سریع‌ترین را انتخاب می‌کند.

---

## Go Tunnel API

API عمومی هسته‌ی Go (قابل bind با gomobile):

</div>

```go
Start(configJSON string) int   // returns local SOCKS5 port, -1 on error
Stop()
IsRunning() bool
LastError() string
```

---

<div dir="rtl">

## سرور پروفایل

یک سرور HTTP ساده برای توزیع و مدیریت پروفایل‌ها، بدون وابستگی خارجی:

</div>

```
GET  /health                           → { "ok": true, "time": "..." }
GET  /v1/profiles                      → { "profiles": [...] }
POST /v1/profiles                      → { "profile": {...}, "iosVpn": {...} }
GET  /v1/profiles/{id}/ios-config      → { "profileId": "...", "iosVpn": {...} }
```

<div dir="rtl">

تمام مسیرهای `/v1/` نیاز به `Authorization: Bearer {apiKey}` دارند.

**ذخیره‌سازی:** فایل JSON در `server/data/profiles.json`، محافظت‌شده با mutex.

---

## فناوری

**هسته (Go)**
- `golang.org/x/crypto` — SSH، TLS، AEAD
- `golang.org/x/net` — پردازش بسته‌های DNS
- `golang.org/x/mobile` — gomobile bind برای iOS
- حمل‌ونقل: UDP 53 · TCP 53 · DoT 853 · DoH 443

**کلاینت موبایل (Flutter / Dart 3)**
- `flutter_bloc ^9.1.1` — مدیریت state
- `hive_flutter ^1.1.0` + `shared_preferences ^2.2.2` — ذخیره‌سازی محلی
- `mobile_scanner ^7.2.0` + `qr_flutter ^4.1.0` — ورودی/خروجی QR
- `encrypt ^5.0.3` — رمزنگاری AES-256-CBC
- `uuid ^4.2.1` — تولید شناسه پروفایل

**سرور پروفایل (Go)**
- فقط کتابخانه استاندارد
- REST + احراز هویت Bearer token

---

## حمایت از پروژه

اگر DNSly برایتان مفید بوده، می‌توانید از توسعه آن حمایت کنید:

<div align="center">

| بیت‌کوین (BTC) | تتر (USDT — TRC20) |
|:---:|:---:|
| <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=bitcoin:bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx" width="150" alt="BTC QR Code"> | <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW" width="150" alt="USDT TRC20 QR Code"> |
| `bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx` | `TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW` |

</div>

---

## ساختار پروژه

</div>

```
go/
  tunnel/
    tunnel.go          # انتخاب‌کننده transport، API عمومی gomobile
    dns_tunnel.go      # VayDNS: UDP/TCP/DoH/DoT
    ssh_proxy.go       # پورت-فورواردینگ SSH
    socks_relay.go     # relay شفاف SOCKS5
  go.mod

server/
  main.go              # REST API، ذخیره پروفایل، تولید config iOS VPN
  go.mod

lib/
  app.dart
  models/
    profile.dart
  blocs/
    connection/
    profile/
    dns_scanner/
  screens/
    home/
    profiles/
    dns_scanner/
    settings/
  services/
    profile_repository.dart
    vpn_platform_service.dart
  utils/
    slipnet_codec.dart

test/
  slipnet_enc_upstream_test.dart
  upstream_slipnet_decoder_test.dart
```
