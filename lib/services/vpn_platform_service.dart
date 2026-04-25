import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/profile.dart';

class VPNPlatformService {
  static const MethodChannel _channel = MethodChannel('dnsly/vpn');
  static const EventChannel _statusChannel = EventChannel('dnsly/vpn_status');

  Future<bool> installProfile(Profile profile) async {
    if (!_isIOS) return true;

    final providerBundle = '${_bundleId()}.DNSly';
    final result = await _channel.invokeMethod<bool>('installProfile', {
      'name': profile.name,
      'serverAddress': profile.server,
      'username': profile.sshUser ?? profile.socksUser ?? 'user',
      'password': profile.sshPassword ?? profile.socksPassword ?? profile.password ?? '',
      'providerBundleIdentifier': providerBundle,
      'providerConfiguration': _providerConfig(profile),
    });
    return result ?? false;
  }

  Future<bool> start() async {
    if (!_isIOS) return true;
    final result = await _channel.invokeMethod<bool>('start');
    return result ?? false;
  }

  Future<bool> stop() async {
    if (!_isIOS) return true;
    final result = await _channel.invokeMethod<bool>('stop');
    return result ?? false;
  }

  Future<String> status() async {
    if (!_isIOS) return 'connected';
    final result = await _channel.invokeMethod<String>('status');
    return result ?? 'unknown';
  }

  Future<Map<String, int>?> stats() async {
    if (!_isIOS) return null;
    final result = await _channel.invokeMapMethod<String, dynamic>('stats');
    if (result == null) return null;
    return {
      'bytesIn': (result['bytesIn'] as num?)?.toInt() ?? 0,
      'bytesOut': (result['bytesOut'] as num?)?.toInt() ?? 0,
      'packetsIn': (result['packetsIn'] as num?)?.toInt() ?? 0,
      'packetsOut': (result['packetsOut'] as num?)?.toInt() ?? 0,
      'uptimeSec': (result['uptimeSec'] as num?)?.toInt() ?? 0,
    };
  }

  Stream<Map<String, String>> statusStream() {
    if (!_isIOS) {
      return const Stream<Map<String, String>>.empty();
    }
    return _statusChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) {
          final map = Map<String, dynamic>.from(event as Map);
          return {
            'status': (map['status'] ?? '').toString(),
            'lastError': (map['lastError'] ?? '').toString(),
          };
        });
  }

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  static String _bundleId() => 'com.example.dnslyApp';

  static Map<String, String> _providerConfig(Profile p) {
    return {
      'profileId': p.id,
      // tunnelType drives the Go library transport selection.
      'tunnelType': p.tunnelType.name,
      'connectionMethod': p.connectionMethod.name,
      'server': p.server,
      'port': p.port.toString(),
      'domain': p.domain,
      'dnsResolver': p.dnsResolver,
      'dnsTransport': p.dnsTransport.name,
      'recordType': p.recordType.label,
      'queryLength': p.queryLength.toString(),
      'sshHost': p.sshHost ?? p.server,
      'sshPort': (p.sshPort ?? 22).toString(),
      'sshUser': p.sshUser ?? '',
      'sshPassword': p.sshPassword ?? p.password ?? '',
      'sshKey': p.sshKey ?? '',
      'sshAuthType': p.sshAuthType.name,
      'socksHost': p.server,
      'socksPort': p.port.toString(),
      'socksUser': p.socksUser ?? '',
      'socksPassword': p.socksPassword ?? p.password ?? '',
      'compression': p.compression ? '1' : '0',
      'mtu': (p.mtu ?? 1400).toString(),
      'timeout': (p.timeout ?? 60).toString(),
    };
  }
}
