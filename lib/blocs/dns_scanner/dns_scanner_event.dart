import 'package:equatable/equatable.dart';

abstract class DnsScannerEvent extends Equatable {
  const DnsScannerEvent();
  @override
  List<Object?> get props => [];
}

class DnsScanStarted extends DnsScannerEvent {
  final List<String> resolvers;
  const DnsScanStarted(this.resolvers);
  @override
  List<Object?> get props => [resolvers];
}

class DnsScanReset extends DnsScannerEvent {}
