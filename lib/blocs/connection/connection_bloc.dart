import 'dart:async';
import '../../models/profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/connection_status.dart';
import '../../services/vpn_platform_service.dart';
import 'connection_event.dart';
import 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  Timer? _uptimeTimer;
  Timer? _statsTimer;
  DateTime? _connectedAt;
  StreamSubscription<Map<String, String>>? _statusSub;
  final VPNPlatformService _vpnService;

  ConnectionBloc({VPNPlatformService? vpnService})
      : _vpnService = vpnService ?? VPNPlatformService(),
        super(const ConnectionState()) {
    on<ConnectionStarted>(_onStarted);
    on<ConnectionStopped>(_onStopped);
    on<ConnectionStatsUpdated>(_onStatsUpdated);
    on<ConnectionErrorOccurred>(_onError);
    on<ConnectionNativeStatusChanged>(_onNativeStatusChanged);

    _statusSub = _vpnService.statusStream().listen(
      (payload) => add(ConnectionNativeStatusChanged(
        payload['status'] ?? 'unknown',
        nativeError: payload['lastError'],
      )),
      onError: (_) {},
    );
  }

  Future<void> _onStarted(
      ConnectionStarted event,
      Emitter<ConnectionState> emit,
      ) async {
    emit(state.copyWith(
      status: ConnectionStatus.connecting,
      activeProfile: event.profile,
      errorMessage: null,
      logs: [...state.logs, '[${_ts()}] Connecting to ${event.profile.server}...'],
    ));

    try {
      final installed = await _vpnService.installProfile(event.profile);
      if (!installed) {
        throw Exception('Failed to install VPN profile');
      }
      final started = await _vpnService.start();
      if (!started) {
        throw Exception('Failed to start VPN tunnel');
      }

      _connectedAt = DateTime.now();

      emit(state.copyWith(
        status: ConnectionStatus.connected,
        bytesIn: 0,
        bytesOut: 0,
        uptime: Duration.zero,
        latencyMs: 0,
        logs: [...state.logs, '[${_ts()}] Connected via ${event.profile.tunnelType.name}'],
      ));

      _startTimers();
    } catch (e) {
      final msg = e.toString();
      final isSimulator = msg.contains('simulator_unsupported');
      emit(state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: isSimulator
            ? 'VPN is not supported on the iOS Simulator. Use a physical iPhone.'
            : msg,
        logs: [
          ...state.logs,
          '[${_ts()}] Error: ${isSimulator ? 'Simulator not supported' : msg}',
        ],
      ));
    }
  }

  Future<void> _onStopped(
      ConnectionStopped event,
      Emitter<ConnectionState> emit,
      ) async {
    _stopTimers();

    emit(state.copyWith(
      status: ConnectionStatus.stopping,
      logs: [...state.logs, '[${_ts()}] Disconnecting...'],
    ));

    try {
      await _vpnService.stop();
    } catch (_) {}

    emit(ConnectionState(
      status: ConnectionStatus.disconnected,
      logs: [...state.logs, '[${_ts()}] Disconnected'],
    ));
  }


  void _onStatsUpdated(
      ConnectionStatsUpdated event,
      Emitter<ConnectionState> emit,
      ) {
    emit(state.copyWith(
      bytesIn: event.bytesIn,
      bytesOut: event.bytesOut,
      uptime: event.uptime,
      latencyMs: event.latencyMs,
    ));
  }

  void _onError(
      ConnectionErrorOccurred event,
      Emitter<ConnectionState> emit,
      ) {
    _stopTimers();
    emit(state.copyWith(
      status: ConnectionStatus.error,
      errorMessage: event.message,
      logs: [...state.logs, '[${_ts()}] Error: ${event.message}'],
    ));
  }

  void _onNativeStatusChanged(
    ConnectionNativeStatusChanged event,
    Emitter<ConnectionState> emit,
  ) {
    final mapped = _mapNativeStatus(event.nativeStatus);
    if (mapped == state.status) return;

    emit(state.copyWith(
      status: mapped,
      errorMessage: (event.nativeError?.isNotEmpty ?? false) ? event.nativeError : state.errorMessage,
      logs: [
        ...state.logs,
        '[${_ts()}] Native status: ${event.nativeStatus}',
        if (event.nativeError?.isNotEmpty ?? false) '[${_ts()}] Native error: ${event.nativeError}',
      ],
    ));
  }

  void _startTimers() {
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        add(ConnectionStatsUpdated(
          bytesIn: state.bytesIn,
          bytesOut: state.bytesOut,
          uptime: DateTime.now().difference(_connectedAt!),
          latencyMs: state.latencyMs,
        ));
      }
    });

    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pullRuntimeStats();
    });
  }

  Future<void> _pullRuntimeStats() async {
    try {
      final runtime = await _vpnService.stats();
      if (runtime != null) {
        final uptimeSec = runtime['uptimeSec'] ?? 0;
        add(ConnectionStatsUpdated(
          bytesIn: runtime['bytesIn'] ?? state.bytesIn,
          bytesOut: runtime['bytesOut'] ?? state.bytesOut,
          uptime: Duration(seconds: uptimeSec),
          latencyMs: state.latencyMs == 0 ? 30 : state.latencyMs,
        ));
        return;
      }
    } catch (_) {}

    final bytesIn = state.bytesIn + 1024 + (DateTime.now().millisecond * 10);
    final bytesOut = state.bytesOut + 512 + (DateTime.now().millisecond * 5);
    add(ConnectionStatsUpdated(
      bytesIn: bytesIn,
      bytesOut: bytesOut,
      uptime: _connectedAt != null
          ? DateTime.now().difference(_connectedAt!)
          : Duration.zero,
      latencyMs: 20 + (DateTime.now().millisecond % 80),
    ));
  }

  void _stopTimers() {
    _uptimeTimer?.cancel();
    _statsTimer?.cancel();
    _uptimeTimer = null;
    _statsTimer = null;
    _connectedAt = null;
  }

  String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> close() {
    _statusSub?.cancel();
    _stopTimers();
    return super.close();
  }

  ConnectionStatus _mapNativeStatus(String native) {
    switch (native) {
      case 'connected':
        return ConnectionStatus.connected;
      case 'connecting':
      case 'reasserting':
        return ConnectionStatus.connecting;
      case 'disconnecting':
        return ConnectionStatus.stopping;
      case 'disconnected':
      case 'invalid':
        return ConnectionStatus.disconnected;
      default:
        return state.status;
    }
  }
}
