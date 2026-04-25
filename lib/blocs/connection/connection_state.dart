import '../../models/connection_status.dart';
import '../../models/profile.dart';

class ConnectionState {
  final ConnectionStatus status;
  final Profile? activeProfile;
  final int bytesIn;
  final int bytesOut;
  final Duration uptime;
  final int latencyMs;
  final String? errorMessage;
  final List<String> logs;

  const ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.activeProfile,
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.uptime = Duration.zero,
    this.latencyMs = 0,
    this.errorMessage,
    this.logs = const [],
  });

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get isDisconnected => status == ConnectionStatus.disconnected;

  String get formattedUptime {
    final h = uptime.inHours.toString().padLeft(2, '0');
    final m = (uptime.inMinutes % 60).toString().padLeft(2, '0');
    final s = (uptime.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedBytesIn => _formatBytes(bytesIn);
  String get formattedBytesOut => _formatBytes(bytesOut);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  ConnectionState copyWith({
    ConnectionStatus? status,
    Profile? activeProfile,
    int? bytesIn,
    int? bytesOut,
    Duration? uptime,
    int? latencyMs,
    String? errorMessage,
    List<String>? logs,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      activeProfile: activeProfile ?? this.activeProfile,
      bytesIn: bytesIn ?? this.bytesIn,
      bytesOut: bytesOut ?? this.bytesOut,
      uptime: uptime ?? this.uptime,
      latencyMs: latencyMs ?? this.latencyMs,
      errorMessage: errorMessage,
      logs: logs ?? this.logs,
    );
  }
}
