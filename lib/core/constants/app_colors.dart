import 'package:flutter/material.dart';

/// ألوان التطبيق — مصدر الحقيقة الوحيد لكل ألوان Zentrip.
/// استخدم هذه الثوابت مباشرةً في الـ Widgets بدل أي ألوان hardcoded.
abstract class AppColors {
  // ── Primary ──────────────────────────────────────────────
  static const Color primary = Color(0xFF0055C8);
  static const Color primaryDark = Color(0xFF0047A8);
  static const Color primaryLight = Color(0xFF3D80E0);
  static const Color primarySurface = Color(0xFFE8F0FC);

  // ── Accent ───────────────────────────────────────────────
  static const Color accentTeal = Color(0xFF00B8D9);
  static const Color accentGreen = Color(0xFF00C896);
  static const Color accentOrange = Color(0xFFFF7043);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentYellow = Color(0xFFFFBF00);
  static const Color accentPurple = Color(0xFF7C3AED);

  // ── Neutral ──────────────────────────────────────────────
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF0F4FA);
  static const Color border = Color(0xFFE4EAF2);
  static const Color divider = Color(0xFFEDF0F5);

  // ── Text (Light) ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F1E36);
  static const Color textSecondary = Color(0xFF6B7A99);
  static const Color textHint = Color(0xFFADB8CC);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Dark Mode ────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF131D30);
  static const Color darkSurfaceSecondary = Color(0xFF1A2640);
  static const Color darkBorder = Color(0xFF253450);
  static const Color darkTextPrimary = Color(0xFFEFF2F9);
  static const Color darkTextSecondary = Color(0xFF8093B0);

  // ── Gradients ────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0055C8), Color(0xFF003A8C)],
  );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0055C8), Color(0xFF00B8D9)],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7043), Color(0xFFFFBF00)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C896), Color(0xFF00B8D9)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF0055C8)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2640), Color(0xFF0B1120)],
  );

  // قائمة تدرجات الوجهات — تُستخدم عشوائياً على بطاقات الحزم السياحية
  static const List<LinearGradient> destinationGradients = [
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0055C8), Color(0xFF00B8D9)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C3AED), Color(0xFFEC4899)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF00C896), Color(0xFF0055C8)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF7043), Color(0xFFFFBF00)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A2640), Color(0xFF0055C8)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF00B8D9), Color(0xFF00C896)]),
  ];
}
