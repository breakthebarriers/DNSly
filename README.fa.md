# DNSly

<div align="left">

[🇬🇧 English](README.md)

</div>

![بازدیدکنندگان](https://visitor-badge.laobi.icu/badge?page_id=breakthebarriers.DNSly)

<p align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.25.56.png" alt="DNSly Logo" width="200">
</p>

<div dir="rtl">

یک کلاینت VPN ضدسانسور سریع و مدرن برای iOS با پشتیبانی از DNS tunneling و پروتکل‌های متعدد. با Flutter ساخته شده و هسته‌ی تانل آن به Go نوشته شده که از طریق gomobile به iOS متصل است.

> **DNSly یک ابزار ضدسانسور مشروع است** که برای کمک به کاربران کشورهایی با سانسور اینترنت ساخته شده تا به اینترنت آزاد دسترسی داشته باشند. این پروژه مشابه [Tor](https://www.torproject.org/)، [Psiphon](https://psiphon.ca/) و [dnstt](https://www.bamsoftware.com/software/dnstt/) است. این پروژه هیچ سیستمی را هدف قرار نمی‌دهد یا به آن حمله نمی‌کند — این ابزاری است که کاربران داوطلبانه برای حفظ حریم خصوصی استفاده می‌کنند.

## جامعه

برای دریافت آپدیت، پشتیبانی و بحث به ما بپیوندید:

</div>

[![Telegram](https://img.shields.io/badge/Telegram-Break__The__Barriers-blue?logo=telegram)](https://t.me/Break_The_Barriers)
[![X (Twitter)](https://img.shields.io/badge/X-breakthebariers-black?logo=x)](https://x.com/breakthebariers)

<div dir="rtl">

## حمایت مالی

اگر DNSly برایتان مفید بوده، می‌توانید از توسعه آن حمایت کنید:

</div>

<div align="center">

| بیت‌کوین (BTC) | تتر (USDT — TRC20) |
|:---:|:---:|
| <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=bitcoin:bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx" width="150" alt="BTC QR Code"> | <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW" width="150" alt="USDT TRC20 QR Code"> |
| `bc1qq7hxnfvr0gn7cfd5h8dskgk0mhrmuleqnmgylx` | `TQTpqyqXsaTM57xoHV3mTsFU3vntZGtxFW` |

</div>

<div dir="rtl">

## انواع تانل

DNSly از چندین نوع تانل با امکان ترکیب پشتیبانی می‌کند:

| نوع تانل | پروتکل | توضیح |
|----------|---------|-------|
| **VayDNS** | DNS/TXT | DNS tunneling بهینه — ترافیک TCP را به DNS query تبدیل می‌کند |
| **VayDNS + SSH** | DNS + SSH | VayDNS با زنجیر SSH برای رمزنگاری بیشتر |
| **VayDNS + SOCKS5** | DNS + SOCKS5 | VayDNS با relay به upstream SOCKS5 |
| **SSH** | SSH | پورت-فورواردینگ دینامیک SSH مستقل |
| **SOCKS5 Relay** | SOCKS5 | ارسال شفاف ترافیک به پروکسی upstream |

**حمل‌ونقل DNS:**

| حالت | پورت | پروتکل |
|------|------|--------|
| Classic UDP | 53 | UDP ساده |
| TCP | 53 | DNS over TCP |
| DoT | 853 | DNS-over-TLS (RFC 7858) |
| DoH | 443 | DNS-over-HTTPS POST (RFC 8484) |

## قابلیت‌ها

- **یکپارچگی VPN در iOS**: دریافت ترافیک در سطح سیستم از طریق iOS NetworkExtension (PacketTunnel)
- **انواع تانل**: VayDNS، SSH، SOCKS5 و ترکیب‌های hybrid
- **انتخاب حمل‌ونقل DNS**: UDP، TCP، DoT یا DoH
- **SSH Tunneling**: زنجیر SSH از طریق VayDNS یا پورت-فورواردینگ مستقل
- **احراز هویت SSH با کلید**: رمز عبور یا کلید خصوصی PEM
- **انتخاب cipher SSH**: AES-256-GCM، AES-128-GCM، ChaCha20-Poly1305
- **پروفایل‌های متعدد**: ایجاد و مدیریت چندین پروفایل سرور
- **ورودی/خروجی QR**: اشتراک‌گذاری پروفایل به صورت QR — مفید هنگام محدودیت اینترنت
- **پروفایل رمزنگاری‌شده**: محافظت از اکسپورت پروفایل با رمزنگاری AES-256-CBC؛ همچنین سازگار با فرمت upstream `slipnet-enc://` با AES-256-GCM
- **اسکنر DNS**: تست موازی تأخیر resolver برای یافتن سریع‌ترین سرور DNS
- **آمار لحظه‌ای**: مانیتورینگ زنده bytes دریافت/ارسال، uptime و latency
- **سرور پروفایل**: سرور HTTP داخلی Go برای توزیع پروفایل به دستگاه‌ها
- **کدک SlipNet**: سازگار با فرمت‌های URI `slipnet://` و `slipnet-enc://`
- **حالت تاریک**: پشتیبانی کامل از تم تاریک سیستم
- **چندپلتفرمی**: کد Flutter برای iOS (اصلی)، Android، macOS، Linux و Windows

## تصاویر

</div>

<p align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.25.56.png" alt="صفحه اصلی" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.05.png" alt="پروفایل‌ها" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.27.png" alt="ویرایش پروفایل" width="200">
</p>

<p align="center">
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.26.37.png" alt="اکسپورت QR" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.27.41.png" alt="اسکنر DNS" width="200">
  &nbsp;&nbsp;
  <img src="assets/screenshots/Simulator Screenshot - DNSly - 2026-04-24 at 11.28.14.png" alt="نتایج اسکنر" width="200">
</p>

<div dir="rtl">

## معماری

ترافیک دستگاه از طریق **Tun2Socks** در PacketTunnel Extension گرفته شده و به یک SOCKS5 محلی هدایت می‌شود. هسته‌ی Go تانل را مدیریت می‌کند:

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

## پروتکل VayDNS

هر اتصال TCP یک session ID چهار بایتی تصادفی دریافت می‌کند. داده‌ها به قطعه‌های حداکثر ۱۲۰ بایتی تقسیم شده، با Base32 کدگذاری و در DNS QNAME جاسازی می‌شوند:

</div>

```
Upload query QNAME:
  {base32(sid[4] ‖ seq[4] ‖ [isSyn:1] ‖ payload)}.d.{domain}.

Download poll QNAME:
  {base32(sid[4] ‖ recvSeq[4])}.r.{domain}.
```

<div dir="rtl">

| فیلد | اندازه | توضیح |
|------|--------|-------|
| `sid` | ۴ بایت | شناسه تصادفی session برای هر اتصال TCP |
| `seq` | ۴ بایت | uint32 big-endian، به ازای هر chunk افزایش می‌یابد |
| `isSyn` | ۱ بایت | `0x01` فقط در اولین chunk (حاوی آدرس مقصد) |
| `payload` | حداکثر ۱۲۰ بایت | قطعه داده اپلیکیشن |

**فاصله polling دانلود:** ۸۰ میلی‌ثانیه

## فرمت پروفایل (SlipNet)

پروفایل‌ها در دو فرمت اکسپورت می‌شوند:

</div>

**Plain:**
```
slipnet://tunnelType@host:port?name=...&domain=...&dnsTransport=...&...
```

**Encrypted (فرمت رسمی SlipNet AES-256-GCM):**
```
slipnet-enc://BASE64
```
پس از decode کردن `BASE64`، بایت‌ها به شکل زیر هستند:
- байт نسخه: `0x01`
- IV: ۱۲ بایت nonce AES-GCM
- ciphertext + tag: باقی‌مانده بایت‌ها شامل ciphertext و برچسب احراز هویت ۱۶ بایتی است

رمزگشایی با AES-256-GCM و کلید ۳۲ بایتی داخلی برنامه SlipNet انجام می‌شود. در این فرمت رسمی، رمز عبور برای مشتق‌سازی کلید AES استفاده نمی‌شود؛ فقط برای کنترل دسترسی در خود اپ کاربرد دارد.

**فرمت رمزنگاری‌شده قدیمی برنامه:**
```
slipnet-enc://base64(envelope)

envelope = {
  "v": 2,
  "iv": "<base64 16-byte random IV>",
  "ct": "<base64 AES-256-CBC ciphertext>",
  "meta": { name, server, domain, ... }   ← فیلدهای پیش‌نمایش متن ساده
}
```
Key derivation: `SHA256(password)` → 32-byte AES key

این مخزن هر دو فرمت رسمی upstream `slipnet-enc://` با AES-256-GCM و فرمت قدیمی رمزنگاری‌شده با پاکت JSON را پشتیبانی می‌کند.

## پیش‌نیازها

### اپلیکیشن iOS

- iOS 15.0 یا بالاتر
- Xcode 15 یا جدیدتر
- Flutter SDK (stable channel)
- Go 1.21+ با gomobile (`go install golang.org/x/mobile/cmd/gomobile@latest`)

## ساخت پروژه

### ۱. ساخت فریم‌ورک Go

</div>

```bash
cd go
gomobile init
gomobile bind -target=ios -o ../ios/Frameworks/Tunnel.xcframework ./tunnel
```

<div dir="rtl">

### ۲. نصب وابستگی‌های Flutter

</div>

```bash
flutter pub get
```

<div dir="rtl">

### ۳. اجرا روی شبیه‌ساز یا دستگاه

</div>

```bash
flutter run --release
```

<div dir="rtl">

> **توجه:** PacketTunnel Extension برای کارکرد VPN واقعی نیاز به دستگاه واقعی و حساب Apple Developer دارد. شبیه‌ساز فقط رابط کاربری را نشان می‌دهد.

### ساخت سرور پروفایل

</div>

```bash
cd server
go build -o dnsly-server .
./dnsly-server
```

<div dir="rtl">

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

ios/
  Runner/
  DNSly/
  Frameworks/

test/
  slipnet_enc_upstream_test.dart
  upstream_slipnet_decoder_test.dart
```

<div dir="rtl">

## فناوری

### هسته تانل (Go)

- `golang.org/x/crypto` — SSH، TLS، AEAD
- `golang.org/x/net` — پردازش بسته‌های DNS
- `golang.org/x/mobile` — gomobile bind برای iOS
- حمل‌ونقل: UDP 53 · TCP 53 · DoT 853 · DoH 443

### کلاینت موبایل (Flutter / Dart 3)

- `flutter_bloc ^9.1.1` — مدیریت state با BLoC
- `hive_flutter ^1.1.0` + `shared_preferences ^2.2.2` — ذخیره‌سازی محلی
- `mobile_scanner ^7.2.0` + `qr_flutter ^4.1.0` — ورودی/خروجی QR
- `encrypt ^5.0.3` — رمزنگاری AES-256-CBC
- `crypto ^3.0.6` — مشتق‌سازی کلید SHA-256
- `uuid ^4.2.1` — تولید شناسه پروفایل

### سرور پروفایل (Go)

- فقط کتابخانه استاندارد
- REST API + احراز هویت Bearer token
- تولید config `NEVPNProtocol` برای iOS

## مشارکت

مشارکت‌ها خوش‌آمد هستند! لطفاً Pull Request ارسال کنید.

۱. Fork کنید  
۲. برنچ ویژگی بسازید (`git checkout -b feature/amazing-feature`)  
۳. تغییرات را commit کنید (`git commit -m 'Add some amazing feature'`)  
۴. به برنچ push کنید (`git push origin feature/amazing-feature`)  
۵. Pull Request باز کنید

## مجوز

این پروژه تحت مجوز MIT منتشر شده است. برای جزئیات [LICENSE](./LICENSE) را ببینید.

</div>
