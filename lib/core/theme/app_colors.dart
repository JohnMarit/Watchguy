import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0B0608);
  static const surface = Color(0xFF180B0F);
  static const surfaceHigh = Color(0xFF241116);
  static const line = Color(0xFF3C1C23);

  /// Deep red is the product colour. Brighter reds are for emphasis only.
  static const red = Color(0xFF9B1120);
  static const redDeep = Color(0xFF5E0A13);
  static const redBright = Color(0xFFE2303F);

  static const text = Color(0xFFF8F1F2);
  static const muted = Color(0xFFB9969C);
  static const online = Color(0xFF3DDC97);
  static const warning = Color(0xFFF5A524);
  static const critical = Color(0xFFFF4D5E);
  static const quiet = Color(0xFF9A8086);
}

class AppGradients {
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.redBright, AppColors.redDeep],
  );

  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C0C11), Color(0xFF130809)],
  );

  static const alert = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7A1018), Color(0xFF2A0A0E)],
  );

  static const header = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A0D13), AppColors.background],
  );

  static const overlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xCC0B0608), Color(0x000B0608)],
  );

  static const panel = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xF21A0A0E), Color(0x000B0608)],
  );
}

Color riskColor(String level) {
  return switch (level) {
    'critical' => AppColors.critical,
    'high' => AppColors.redBright,
    'medium' => AppColors.warning,
    'low' => AppColors.online,
    _ => AppColors.quiet,
  };
}

LinearGradient riskGradient(String level) {
  final color = riskColor(level);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [color, Color.lerp(color, AppColors.redDeep, 0.65)!],
  );
}
