import 'package:flutter/material.dart';

class VColors {
  static const ink = Color(0xFF0F4038);
  static const muted = Color(0xFF627873);
  static const background = Color(0xFFF7FAF9);
  static const surface = Colors.white;
  static const softMint = Color(0xFFE6F5EF);
  static const mint = Color(0xFFBDE8D8);
  static const blueSoft = Color(0xFFE9F2FF);
  static const orange = Color(0xFFF2A27B);
  static const orangeSoft = Color(0xFFFFF0E7);
  static const line = Color(0xFFE2EAE6);
}

ThemeData visceraTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: VColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: VColors.ink, primary: VColors.ink, secondary: VColors.mint, surface: VColors.surface),
    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing:-1.1, color: VColors.ink),
      headlineMedium: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing:-0.8, color: VColors.ink),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing:-0.35, color: VColors.ink),
      titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: VColors.ink),
      bodyMedium: const TextStyle(fontSize: 14, color: VColors.ink, height:1.45),
      bodyLarge: const TextStyle(fontSize: 16, color: VColors.ink, height:1.35),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal:16, vertical:15),
      labelStyle: const TextStyle(color: VColors.muted, fontSize:13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VColors.ink, width:1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: VColors.ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal:18,vertical:17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), elevation:0)),
  );
}
