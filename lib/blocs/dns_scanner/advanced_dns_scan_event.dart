abstract class AdvancedDnsScanEvent {}

class AdvancedDnsScanStarted extends AdvancedDnsScanEvent {
  final List<String> resolvers;
  final String testDomain;
  final bool testEDNS;
  final bool testNXDOMAIN;
  final bool testE2E;
  final bool testPrism;
  final String? prismSecret;
  final int concurrency;
  final String? filterCountry;

  AdvancedDnsScanStarted({
    required this.resolvers,
    required this.testDomain,
    this.testEDNS = true,
    this.testNXDOMAIN = true,
    this.testE2E = false,
    this.testPrism = false,
    this.prismSecret,
    this.concurrency = 5,
    this.filterCountry,
  });
}

class AdvancedDnsScanReset extends AdvancedDnsScanEvent {}
