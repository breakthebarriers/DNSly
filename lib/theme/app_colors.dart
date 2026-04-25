import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Background / Surface ──
  static const Color scaffold = Color(0xFF0E1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF1C2129);
  static const Color card = Color(0xFF1A1F27);
  static const Color cardBorder = Color(0xFF2D333B);

  // ── Accent ──
  static const Color primary = Color(0xFF58A6FF);
  static const Color primaryDim = Color(0xFF1F6FEB);
  static const Color accent = Color(0xFF79C0FF);

  // ── Status ──
  static const Color connected = Color(0xFF3FB950);
  static const Color connecting = Color(0xFFD29922);
  static const Color reconnecting = Color(0xFFD29922);
  static const Color disconnected = Color(0xFF8B949E);
  static const Color error = Color(0xFFF85149);
  static const Color warning = Color(0xFFF89B49);

  // ── Text ──
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);
  static const Color muted = Color(0xFF484F58);

  // ── Misc ──
  static const Color divider = Color(0xFF21262D);
  static const Color shimmer = Color(0xFF2D333B);
  static const Color glassBg = Color(0x1AFFFFFF); // 10% white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white

  // Legacy aliases kept for older UI files.
  static const Color bg = scaffold;
  static const Color bgSecondary = surface;
  static const Color text = textPrimary;
  static const Color dim = surfaceLight;
  static const Color danger = error;

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDim, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF161B22), Color(0xFF1A1F27)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient connectGradient = primaryGradient;
}
