import 'package:flutter/material.dart';

import '../../constants/coco_colors.dart';

class CocoTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CocoColors.keyGrey.withOpacity(0.3),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(20.0)),
        borderSide: BorderSide(width: 3, color: CocoColors.keyPrimary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
        borderSide:
            BorderSide(width: 3, color: CocoColors.keyPrimary.withAlpha(50)),
      ),
      prefixStyle: const TextStyle(
        fontSize: 24,
        color: CocoColors.keyBlack,
      ),
      hintStyle: TextStyle(
        fontSize: 24,
        wordSpacing: 3,
        letterSpacing: 2,
        color: CocoColors.keyBlack.withAlpha(80),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: CocoColors.keyPrimary,
      selectionColor: CocoColors.keyPrimary.withAlpha(75),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: CocoColors.keyBlack,
        fontSize: 20,
      ),
      bodyLarge: TextStyle(
        fontSize: 24,
        color: CocoColors.keyBlack,
      ),
    ),
    colorScheme: const ColorScheme.light(
      background: CocoColors.keyWhite,
      primary: CocoColors.keyPrimary,
      secondary: CocoColors.keyWhite,
      inversePrimary: CocoColors.keyBlack,
      outline: CocoColors.keyPrimary,
    ),
    scaffoldBackgroundColor: CocoColors.keyWhite,
  );

  static ThemeData darkTheme = ThemeData(
    visualDensity: VisualDensity.adaptivePlatformDensity,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CocoColors.keyGrey.withOpacity(0.3),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(20.0)),
        borderSide: BorderSide(width: 3, color: CocoColors.keyPrimary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
        borderSide:
            BorderSide(width: 3, color: CocoColors.keyPrimary.withAlpha(50)),
      ),
      prefixStyle: const TextStyle(
        fontSize: 24,
        color: CocoColors.keyWhite,
      ),
      hintStyle: TextStyle(
        fontSize: 24,
        wordSpacing: 3,
        letterSpacing: 2,
        color: CocoColors.keyWhite.withAlpha(150),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: CocoColors.keyPrimary,
      selectionColor: CocoColors.keyPrimary.withAlpha(75),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: CocoColors.keyWhite,
        fontSize: 20,
      ),
      bodyLarge: TextStyle(
        fontSize: 24,
        color: CocoColors.keyWhite,
      ),
    ),
    colorScheme: const ColorScheme.light(
      brightness: Brightness.dark,
      background: CocoColors.keyBlack,
      primary: CocoColors.keyPrimary,
      secondary: CocoColors.keyBlack,
      inversePrimary: CocoColors.keyWhite,
      outline: CocoColors.keyPrimary,
    ),
    scaffoldBackgroundColor: CocoColors.keyBlack,
  );
}
