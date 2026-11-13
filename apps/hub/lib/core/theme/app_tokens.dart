import 'package:flutter/material.dart';

/// Design tokens following the "Developer Trust & Precision" dark-first palette.
abstract final class AppColors {
  static const bgPrimary = Color(0xFF0B0F17);
  static const surface = Color(0xFF111827);
  static const surfaceElevated = Color(0xFF1E293B);
  static const border = Color(0xFF263244);

  static const primary = Color(0xFF6366F1);
  static const primaryContainer = Color(0xFF1E1B4B);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const featuredGold = Color(0xFFFBBF24);

  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}
