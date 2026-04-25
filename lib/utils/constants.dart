class AppConstants {
  AppConstants._();

  static const String appName = 'DNSly';
  static const String appVersion = '1.0.0';
  static const String tunnelChannel = 'com.dnsly/tunnel';
  static const String tunnelEventsChannel = 'com.dnsly/tunnel_events';
  static const String dnsScannerChannel = 'com.dnsly/dns_scanner';

  static const List<String> defaultResolvers = [
    '8.8.8.8',
    '8.8.4.4',
    '1.1.1.1',
    '1.0.0.1',
    '9.9.9.9',
    '208.67.222.222',
    '185.228.168.9',
    '76.76.19.19',
    '94.140.14.14',
    '10.202.10.202',
    '10.202.10.102',
    '178.22.122.100',
    '185.51.200.2',
  ];

  static const int defaultSshPort = 22;
  static const int defaultSocksPort = 1080;
  static const int defaultKeepAlive = 30;
}
