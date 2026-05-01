import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../models/profile.dart';
import '../../theme/app_colors.dart';

class ProfilesReachabilityScreen extends StatefulWidget {
  final List<Profile> profiles;

  const ProfilesReachabilityScreen({super.key, required this.profiles});

  @override
  State<ProfilesReachabilityScreen> createState() => _ProfilesReachabilityScreenState();
}

class _ProfilesReachabilityScreenState extends State<ProfilesReachabilityScreen> {
  bool _isTesting = true;
  final List<_ReachabilityResult> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _results.clear();
      _error = null;
    });

    for (final profile in widget.profiles) {
      if (!mounted) return;
      final result = await _testProfile(profile);
      if (!mounted) return;
      setState(() {
        _results.add(result);
      });
    }

    if (!mounted) return;
    setState(() => _isTesting = false);
  }

  Future<_ReachabilityResult> _testProfile(Profile profile) async {
    if (profile.server.trim().isEmpty) {
      return _ReachabilityResult(
        profile: profile,
        reachable: false,
        latencyMs: 0,
        message: 'Missing server host',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        profile.server,
        profile.port,
        timeout: const Duration(seconds: 4),
      );
      stopwatch.stop();
      socket.destroy();
      return _ReachabilityResult(
        profile: profile,
        reachable: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Reachable',
      );
    } on TimeoutException {
      stopwatch.stop();
      return _ReachabilityResult(
        profile: profile,
        reachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Timeout',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return _ReachabilityResult(
        profile: profile,
        reachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: e.message.isNotEmpty ? e.message : 'Unreachable',
      );
    } catch (e) {
      stopwatch.stop();
      return _ReachabilityResult(
        profile: profile,
        reachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shownCount = _results.length;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffold,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        middle: const Text('Profile Ping Results'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isTesting
                        ? 'Pinging ${widget.profiles.length} profile(s)…'
                        : 'Ping complete: ${shownCount}/${widget.profiles.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ping is performed by opening a TCP connection to each profile server.',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: AppColors.primary,
                        onPressed: _isTesting ? null : _runTests,
                        child: const Text('Retest All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            ],
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _isTesting
                            ? 'Gathering results…'
                            : 'No profiles were tested.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return _buildResultCard(result);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(_ReachabilityResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.profile.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.profile.server}:${result.profile.port}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  result.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: result.reachable ? CupertinoColors.activeGreen : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                result.reachable ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.xmark_circle_fill,
                color: result.reachable ? CupertinoColors.activeGreen : AppColors.danger,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                result.reachable ? '${result.latencyMs} ms' : '--',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReachabilityResult {
  final Profile profile;
  final bool reachable;
  final int latencyMs;
  final String message;

  _ReachabilityResult({
    required this.profile,
    required this.reachable,
    required this.latencyMs,
    required this.message,
  });
}
