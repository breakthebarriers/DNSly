import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/connection_status.dart';
import '../theme/app_theme.dart';

class ConnectButton extends StatefulWidget {
  final ConnectionStatus status;
  final VoidCallback onPressed;

  const ConnectButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ConnectButton old) {
    super.didUpdateWidget(old);
    if (widget.status == ConnectionStatus.connecting ||
        widget.status == ConnectionStatus.disconnected) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status == ConnectionStatus.connected;
    final isTransitioning =
        widget.status == ConnectionStatus.connecting ||
            widget.status == ConnectionStatus.disconnected;

    final gradient = isConnected
        ? AppColors.dangerGradient
        : AppColors.connectGradient;
    final label = _label;
    final icon = _icon;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: isTransitioning ? _pulseAnim.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: isTransitioning ? null : widget.onPressed,
        child: Container(
          width: 200,
          height: 56,
          decoration: AppDecorations.gradientButton(gradient).copyWith(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isTransitioning)
                const CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 10,
                )
              else
                Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _label {
    switch (widget.status) {
      case ConnectionStatus.reconnecting:
        return 'Connect';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.connected:
        return 'Disconnect';
      case ConnectionStatus.disconnected:
        return 'Stop';
      case ConnectionStatus.error:
        return 'Retry';
      case ConnectionStatus.stopping:
        return 'Stopping...';
    }
  }

  IconData get _icon {
    switch (widget.status) {
      case ConnectionStatus.disconnected:
        return CupertinoIcons.power;
      case ConnectionStatus.connecting:
        return CupertinoIcons.arrow_2_circlepath;
      case ConnectionStatus.connected:
        return CupertinoIcons.stop_circle;
      case ConnectionStatus.reconnecting:
        return CupertinoIcons.arrow_2_circlepath;
      case ConnectionStatus.error:
        return CupertinoIcons.refresh;
      case ConnectionStatus.stopping:
        return CupertinoIcons.stop;
    }
  }
}

// Helper: AnimatedBuilder that works with Animation
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
