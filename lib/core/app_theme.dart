
import 'package:flutter/material.dart';

const purple = Color(0xFF3E007D);
const orange = Color(0xFFFFA015);
const pink = Color(0xFFFF27C3);

class SilsilaTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Kufam',
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        primary: purple,
        secondary: orange,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF8FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Kufam',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'Kufam'),
        bodyMedium: TextStyle(fontFamily: 'Kufam'),
        bodySmall: TextStyle(fontFamily: 'Kufam'),
        titleLarge: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(fontFamily: 'Kufam'),
        labelLarge: TextStyle(fontFamily: 'Kufam'),
        labelMedium: TextStyle(fontFamily: 'Kufam'),
        labelSmall: TextStyle(fontFamily: 'Kufam'),
        headlineLarge: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: purple,
            width: 2,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'Kufam'),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'Kufam'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'Kufam'),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: 'Kufam'),
        ),
      ),
    );
  }
}
