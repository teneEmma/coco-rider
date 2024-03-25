import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/constants/coco_constants.dart';
import 'package:flutter/material.dart';

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
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: CocoColors.keyWhite.withAlpha(150),
      indicatorColor: CocoColors.keyPrimary.withAlpha(150),
      useIndicator: true,
      labelType: NavigationRailLabelType.all,
      unselectedLabelTextStyle: const TextStyle(
        color: CocoColors.keyGrey,
        fontSize: 14,
      ),
      selectedIconTheme: const IconThemeData(
        color: CocoColors.keyBlack,
      ),
      selectedLabelTextStyle: const TextStyle(color: CocoColors.keyBlack),
    ),
    appBarTheme: const AppBarTheme(
      color: CocoColors.keyWhite,
      toolbarHeight: CocoConstants.defaultSmallScreenAppBarHeight,
      elevation: 0,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: CocoColors.keyPrimary,
      selectionColor: CocoColors.keyPrimary.withAlpha(75),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: CocoColors.keyBlack,
        fontSize: 30,
      ),
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
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: CocoColors.keyBlack,
      indicatorColor: CocoColors.keyPrimary.withAlpha(150),
      useIndicator: true,
      labelType: NavigationRailLabelType.all,
      unselectedLabelTextStyle: const TextStyle(
        color: CocoColors.keyGrey,
        fontSize: 14,
      ),
      selectedIconTheme: const IconThemeData(
        color: CocoColors.keyWhite,
      ),
      selectedLabelTextStyle: const TextStyle(color: CocoColors.keyBlack),
    ),
    appBarTheme: const AppBarTheme(
      color: CocoColors.keyWhite,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: CocoColors.keyPrimary,
      selectionColor: CocoColors.keyPrimary.withAlpha(75),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: CocoColors.keyBlack,
        fontSize: 30,
      ),
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
