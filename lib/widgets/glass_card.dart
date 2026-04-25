import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.85),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}
