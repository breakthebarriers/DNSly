import '../../models/profile.dart';

abstract class ConnectionEvent {
  const ConnectionEvent();
}

class ConnectionStarted extends ConnectionEvent {
  final Profile profile;
  const ConnectionStarted(this.profile);
}

class ConnectionStopped extends ConnectionEvent {
  const ConnectionStopped();
}

class ConnectionStatsUpdated extends ConnectionEvent {
  final int bytesIn;
  final int bytesOut;
  final Duration uptime;
  final int latencyMs;
  const ConnectionStatsUpdated({
    required this.bytesIn,
    required this.bytesOut,
    required this.uptime,
    required this.latencyMs,
  });
}

class ConnectionErrorOccurred extends ConnectionEvent {
  final String message;
  const ConnectionErrorOccurred(this.message);
}

class ConnectionNativeStatusChanged extends ConnectionEvent {
  final String nativeStatus;
  final String? nativeError;
  const ConnectionNativeStatusChanged(this.nativeStatus, {this.nativeError});
}
