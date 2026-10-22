import 'package:flutter/material.dart';

const purple = Color(0xFF3E007D);
const orange = Color(0xFFFFA015);
const pink = Color(0xFFFF27C3);

const silsilaCanvas = Color(0xFFFAF8FC);
const silsilaInk = Color(0xFF282333);
const silsilaMuted = Color(0xFF777180);
const silsilaBorder = Color(0xFFE8E1EF);

class SilsilaTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.light,
      primary: purple,
      secondary: orange,
      surface: Colors.white,
      error: const Color(0xFFB3261E),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: silsilaCanvas,
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: const BorderSide(color: purple, width: 1.6),
        checkColor: WidgetStateProperty.all(Colors.white),
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return purple;
          if (states.contains(WidgetState.disabled)) return const Color(0xFFE8E1EF);
          return Colors.white;
        }),
        splashRadius: 20,
        visualDensity: VisualDensity.standard,
      ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Kufam',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Kufam',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Kufam',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Kufam',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Kufam',
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Kufam',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: silsilaInk,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: silsilaInk,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          color: silsilaInk,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: silsilaInk,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          color: silsilaMuted,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
        ),
      ),

      // Text fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        constraints: const BoxConstraints(minHeight: 52),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Tajawal',
          color: silsilaMuted,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          color: silsilaMuted,
        ),
        prefixIconColor: purple,
        suffixIconColor: silsilaMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: silsilaBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: silsilaBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: purple,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFB3261E),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFB3261E),
            width: 1.8,
          ),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: 6,
        ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF0EBF4),
          ),
        ),
      ),

      // Primary buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE3DCEB),
          disabledForegroundColor: silsilaMuted,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE3DCEB),
          disabledForegroundColor: silsilaMuted,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: purple,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          side: const BorderSide(
            color: purple,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: purple,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Kufam',
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: silsilaInk,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 15,
          color: silsilaInk,
        ),
      ),

      // Bottom sheets
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBackgroundColor: Colors.white,
      ),

      // Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: purple.withValues(alpha: 0.12),
        elevation: 2,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(
              WidgetState.selected,
            );

            return TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? purple : silsilaMuted,
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(
              WidgetState.selected,
            );

            return IconThemeData(
              color: selected ? purple : silsilaMuted,
              size: 23,
            );
          },
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: purple.withValues(alpha: 0.12),
        disabledColor: const Color(0xFFF0EDF3),
        secondarySelectedColor: orange.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: silsilaBorder,
          ),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          color: silsilaInk,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          color: purple,
        ),
      ),

      // Selection controls use the circular checkbox theme defined above.

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? purple
              : silsilaMuted,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : silsilaMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? purple
              : const Color(0xFFE6E0EA),
        ),
      ),

      // Dividers and icons
      dividerTheme: const DividerThemeData(
        color: silsilaBorder,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(
        color: purple,
        size: 22,
      ),

      // Feedback
      snackBarTheme: SnackBarThemeData(
        backgroundColor: silsilaInk,
        contentTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: purple,
        linearTrackColor: Color(0xFFE9E1F0),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: silsilaInk,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          color: Colors.white,
          fontSize: 12,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: purple,
        textColor: silsilaInk,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 3,
        ),
      ),
    );
  }
}
