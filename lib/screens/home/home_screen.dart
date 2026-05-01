import 'dart:math' as math;
import 'package:dnsly_app/models/profile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/connection/connection_bloc.dart';
import '../../blocs/connection/connection_event.dart';
import '../../blocs/connection/connection_state.dart' as conn;
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/profile/profile_state.dart';
import '../../models/connection_status.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_defaults.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffold,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
        middle:
        const Text('DNSly', style: TextStyle(inherit: false, color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      child: SafeArea(
        child: BlocBuilder<ConnectionBloc, conn.ConnectionState>(
          builder: (context, connState) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildConnectButton(connState),
                const SizedBox(height: 24),
                _buildStatusCard(connState),
                const SizedBox(height: 16),
                if (connState.isConnected) ...[
                  _buildStatsRow(connState),
                  const SizedBox(height: 16),
                ],
                _buildActiveProfileCard(context, connState),
                if (connState.logs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildLogsCard(connState),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Connect / Disconnect Button ──
  Widget _buildConnectButton(conn.ConnectionState state) {
    final isConnected = state.isConnected;
    final isConnecting = state.isConnecting;
    final isDisconnecting = state.status == ConnectionStatus.stopping;
    final isBusy = isConnecting || isDisconnecting;

    return Center(
      child: GestureDetector(
        onTap: isBusy ? null : () => _toggleConnection(state),
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final scale = isConnecting
                ? 1.0 + (_pulseCtrl.value * 0.05)
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isConnected
                      ? const LinearGradient(
                    colors: [AppColors.connected, Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : state.status == ConnectionStatus.error
                      ? const LinearGradient(
                    colors: [AppColors.error, Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected
                          ? AppColors.connected
                          : AppColors.primary)
                          .withOpacity(isConnecting ? 0.4 : 0.25),
                      blurRadius: isConnecting ? 40 : 25,
                      spreadRadius: isConnecting ? 5 : 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isBusy)
                      const CupertinoActivityIndicator(color: Colors.white)
                    else
                      Icon(
                        isConnected
                            ? CupertinoIcons.power
                            : CupertinoIcons.bolt_fill,
                        color: Colors.white,
                        size: 44,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      isConnecting
                          ? 'Connecting...'
                          : isDisconnecting
                          ? 'Stopping...'
                          : isConnected
                          ? 'Connected'
                          : 'Connect',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleConnection(conn.ConnectionState state) {
    if (state.isConnected || state.status == ConnectionStatus.error) {
      context.read<ConnectionBloc>().add(const ConnectionStopped());
    } else {
      final profileState = context.read<ProfileBloc>().state;
      final active = profileState.activeProfile;
      if (active != null) {
        context.read<ConnectionBloc>().add(ConnectionStarted(active));
      } else {
        _showNoProfileAlert();
      }
    }
  }

  void _showNoProfileAlert() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('No Active Profile'),
        content: const Text(
            'Please select a profile from the Profiles tab first.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── Status Card ──
  Widget _buildStatusCard(conn.ConnectionState state) {
    final color = _statusColor(state.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            state.status.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const Spacer(),
          if (state.isConnected)
            Text(
              state.formattedUptime,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Mono',
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  // ── Stats Row ──
  Widget _buildStatsRow(conn.ConnectionState state) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: CupertinoIcons.arrow_down_circle,
            label: 'Download',
            value: state.formattedBytesIn,
            color: AppColors.connected,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: CupertinoIcons.arrow_up_circle,
            label: 'Upload',
            value: state.formattedBytesOut,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: CupertinoIcons.gauge,
            label: 'Latency',
            value: '${state.latencyMs} ms',
            color: state.latencyMs < 50
                ? AppColors.connected
                : state.latencyMs < 100
                ? AppColors.warning
                : AppColors.error,
          ),
        ),
      ],
    );
  }

  // ── Active Profile Card ──
  Widget _buildActiveProfileCard(
      BuildContext context, conn.ConnectionState connState) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, profileState) {
        final profile = profileState.activeProfile;
        if (profile == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
              border: Border.all(
                  color: AppColors.warning.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle,
                    color: AppColors.warning, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No profile selected. Go to Profiles tab to create or activate one.',
                    style:
                    TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.person_crop_circle,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _infoBadge(profile.tunnelType.name, AppColors.primary),
                  _infoBadge(profile.dnsTransport.name, AppColors.accent),
                  _infoBadge(
                      '${profile.server}:${profile.port}', AppColors.textMuted),
                  if (profile.sshCipher != null)
                    _infoBadge(profile.sshCipher!.label, AppColors.warning),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Logs Card ──
  Widget _buildLogsCard(conn.ConnectionState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.doc_text, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Connection Log',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(
              reverse: true,
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: state.logs.length,
              itemBuilder: (_, i) {
                final idx = state.logs.length - 1 - i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    state.logs[idx],
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'SF Mono',
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return AppColors.connected;
      case ConnectionStatus.connecting:
        return AppColors.connecting;
      case ConnectionStatus.disconnected:
        return AppColors.warning;
      case ConnectionStatus.error:
        return AppColors.error;
      case ConnectionStatus.reconnecting:
        return AppColors.reconnecting;
      case ConnectionStatus.stopping:
        return AppColors.warning;
    }
  }

  Widget _infoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Stat Tile Widget ──
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'SF Mono',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
