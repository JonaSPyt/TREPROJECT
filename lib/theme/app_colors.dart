import 'package:flutter/material.dart';

/// Centralized color palette for the app.
/// Adjust these to quickly reskin the application.
class AppColors {
  // Brand - Cores mais vibrantes e modernas
  static const Color primary = Color(0xFF2563EB); // Blue 600
  static const Color primaryDark = Color(0xFF1D4ED8); // Blue 700
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color secondary = Color(0xFF10B981); // Emerald 500
  static const Color tertiary = Color(0xFFF59E0B); // Amber 500

  // Functional
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF06B6D4); // Cyan 500

  // Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  
  // Text
  static const Color textPrimary = Color(0xFF1E293B); // Slate 800
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textLight = Color(0xFF94A3B8); // Slate 400
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)], // Blue to Violet
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)], // Emerald to Cyan
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
