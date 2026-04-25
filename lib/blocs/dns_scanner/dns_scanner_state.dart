import 'package:equatable/equatable.dart';

abstract class DnsScannerState extends Equatable {
  const DnsScannerState();
  @override
  List<Object?> get props => [];
}

class DnsScannerInitial extends DnsScannerState {}

class DnsScannerLoading extends DnsScannerState {}

class DnsScannerSuccess extends DnsScannerState {
  final String fastestResolver;
  final int latencyMs;

  const DnsScannerSuccess({
    required this.fastestResolver,
    required this.latencyMs,
  });

  @override
  List<Object?> get props => [fastestResolver, latencyMs];
}

class DnsScannerFailure extends DnsScannerState {
  final String message;
  const DnsScannerFailure(this.message);
  @override
  List<Object?> get props => [message];
}
