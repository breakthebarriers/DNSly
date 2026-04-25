abstract final class AppDefaults {
  // ── Connection ──
  static const int defaultSshPort = 22;
  static const int defaultDnsPort = 53;
  static const int defaultKeepAlive = 30;
  static const int connectionTimeout = 15;
  static const int maxReconnectAttempts = 5;

  // ── DNS ──
  static const List<String> defaultResolvers = [
    '1.1.1.1',
    '8.8.8.8',
    '9.9.9.9',
  ];
  static const String defaultDohEndpoint = 'https://cloudflare-dns.com/dns-query';
  static const String defaultDotServer = '1.1.1.1';

  // ── UI ──
  static const double cardRadius = 16.0;
  static const double inputRadius = 12.0;
  static const double buttonRadius = 12.0;
  static const double pagePadding = 16.0;
  static const double sectionSpacing = 24.0;
  static const double fieldSpacing = 12.0;

  // ── Animation ──
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);

  // ── Profile ──
  static const int maxProfiles = 20;
  static const int maxResolvers = 5;
  static const int maxDomainRules = 50;
  static const String profileStorageKey = 'slipnet_profiles';
  static const String defaultProfileName = 'New Profile';

  // ── Validation ──
  static const int minPort = 1;
  static const int maxPort = 65535;
  static const int minKeepAlive = 5;
  static const int maxKeepAlive = 300;
}
