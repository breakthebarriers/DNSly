import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/connection_status.dart';
import '../theme/app_theme.dart';

class StatusIndicator extends StatefulWidget {
  final ConnectionStatus status;

  const StatusIndicator({super.key, required this.status});

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final label = _statusLabel;
    final isActive = widget.status == ConnectionStatus.connected;
    final isTransitioning =
        widget.status == ConnectionStatus.connecting ||
            widget.status == ConnectionStatus.disconnected;

    return Column(
        children: [
        // ─── Orb ───
        SizedBox(
        width: 160,
        height: 160,
        child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
      return Stack(
          alignment: Alignment.center,
          children: [
          // Outer glow ring
          if (isActive || isTransitioning)
      AnimatedBuilder(
        animation: _rotateController,
        builder: (context, _) {
          return Transform.rotate(
            angle: _rotateController.value * 2 * math.pi,
            child: Container(
              width: 150 + (_glowController.value * 10),
              height: 150 + (_glowController.value * 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    color.withOpacity(0.0),
                    color.withOpacity(0.3),
                    color.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),

    // Inner circle
    AnimatedContainer(
    duration: const Duration(milliseconds: 500),
    width: 120,
    height: 120,
    decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: color.withOpacity(0.1),
    border: Border.all(
    color: color.withOpacity(
    0.3 + _glowController.value * 0.3),
    width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: color.withOpacity(0.25),
        blurRadius: 30,
        spreadRadius: 5,
      ),
    ],
    ),
      child: Icon(
        _statusIcon,
        color: color,
        size: 40,
      ),
    ),
          ],
      );
        },
        ),
        ),

          const SizedBox(height: 16),

          // Status label
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
    );
  }

  Color get _statusColor {
    switch (widget.status) {
      case ConnectionStatus.disconnected:
        return AppColors.muted;
      case ConnectionStatus.connecting:
        return AppColors.warning;
      case ConnectionStatus.connected:
        return AppColors.success;
      case ConnectionStatus.reconnecting:
        return AppColors.warning;
      case ConnectionStatus.error:
        return AppColors.danger;
      case ConnectionStatus.stopping:
        return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case ConnectionStatus.error:
        return 'Connection Error';
      case ConnectionStatus.stopping:
        return "Stopping...";
    }
  }

  IconData get _statusIcon {
    switch (widget.status) {
      case ConnectionStatus.disconnected:
        return CupertinoIcons.power;
      case ConnectionStatus.connecting:
        return CupertinoIcons.arrow_2_circlepath;
      case ConnectionStatus.connected:
        return CupertinoIcons.checkmark_shield_fill;
      case ConnectionStatus.reconnecting:
        return CupertinoIcons.stop_circle;
      case ConnectionStatus.error:
        return CupertinoIcons.xmark_circle_fill;
      case ConnectionStatus.stopping:
        return CupertinoIcons.stop;
    }
  }
}
