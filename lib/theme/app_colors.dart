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
  static const Color background = Color(0xFF121212); // Dark background
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50 (para modo claro se necessário)
  static const Color surface = Color(0xFF1E1E1E); // Dark surface
  static const Color surfaceLight = Colors.white;
  static const Color surfaceVariant = Color(0xFF2D2D2D); // Dark variant
  
  // Text - Ajustado para fundo escuro
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB0B0B0); // Light gray
  static const Color textLight = Color(0xFF808080); // Gray
  
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
