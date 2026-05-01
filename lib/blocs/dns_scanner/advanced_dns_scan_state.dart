import '../../models/advanced_dns_result.dart';

abstract class AdvancedDnsScanState {}

class AdvancedDnsScanInitial extends AdvancedDnsScanState {}

class AdvancedDnsScanLoading extends AdvancedDnsScanState {
  final int progress; // 0-100
  final String message;

  AdvancedDnsScanLoading({
    this.progress = 0,
    this.message = 'Scanning...',
  });
}

class AdvancedDnsScanSuccess extends AdvancedDnsScanState {
  final List<AdvancedDnsResult> results;
  final double averageScore;
  final String topResolverName;

  AdvancedDnsScanSuccess({
    required this.results,
    required this.averageScore,
    required this.topResolverName,
  });
}

class AdvancedDnsScanFailure extends AdvancedDnsScanState {
  final String message;

  AdvancedDnsScanFailure(this.message);
}
