import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../models/profile.dart';
import '../../../theme/app_colors.dart';

class TunnelPicker extends StatelessWidget {
  final TunnelType selected;
  final ValueChanged<TunnelType> onChanged;

  const TunnelPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  // فقط tunnel type های موجود:
  static const _types = [
    TunnelType.vayDns,
    TunnelType.vayDnsSsh,
    TunnelType.ssh,
    TunnelType.socks5,
    TunnelType.vayDnsSocks
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _types.map((t) {
        final isSelected = t == selected;
        return GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.primaryGradient : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.cardBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _tunnelIcon(t),
                  size: 24,
                  color: isSelected ? Colors.white : AppColors.muted,
                ),
                const SizedBox(height: 4),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _tunnelIcon(TunnelType t) {
    switch (t) {
      case TunnelType.vayDns:
        return CupertinoIcons.globe;
      case TunnelType.vayDnsSsh:
        return CupertinoIcons.lock_shield;
      case TunnelType.ssh:
        return CupertinoIcons.lock;
      case TunnelType.vayDnsSocks:
        return CupertinoIcons.antenna_radiowaves_left_right;
      case TunnelType.socks5:
        return CupertinoIcons.shield;
    }
  }
}
