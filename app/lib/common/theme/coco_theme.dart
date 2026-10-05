import 'package:coco_rider/constants/coco_colors.dart';
import 'package:flutter/material.dart';

/// Material theme built from the Figma design: Urbanist, blue primary, grey pill fields,
/// rounded buttons and flat cards.
class CocoTheme {
  static const fontFamily = 'Urbanist';

  /// Corner radius of fields, buttons and cards.
  static const double radius = 14;

  static ThemeData lightTheme = _build(const ColorScheme(
    brightness: Brightness.light,
    primary: CocoColors.keyPrimary,
    onPrimary: CocoColors.keyWhite,
    primaryContainer: CocoColors.keyPrimaryTint,
    onPrimaryContainer: CocoColors.keyInk,
    secondary: CocoColors.keyInk,
    onSecondary: CocoColors.keyWhite,
    tertiary: CocoColors.keyWarning,
    onTertiary: CocoColors.keyWhite,
    error: CocoColors.keyError,
    onError: CocoColors.keyWhite,
    surface: CocoColors.keyWhite,
    onSurface: CocoColors.keyInk,
    onSurfaceVariant: Color(0xFF616161),
    surfaceContainerLowest: CocoColors.keyWhite,
    surfaceContainerLow: CocoColors.keySurfaceAlt,
    surfaceContainer: CocoColors.keySurfaceAlt,
    surfaceContainerHigh: CocoColors.keyFieldFill,
    surfaceContainerHighest: CocoColors.keyFieldFill,
    outline: Color(0xFFBDBDBD),
    outlineVariant: CocoColors.keyStroke,
  ));

  static ThemeData darkTheme = _build(const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF3D9BFF),
    onPrimary: CocoColors.keyWhite,
    primaryContainer: Color(0xFF0D2A4D),
    onPrimaryContainer: CocoColors.keyWhite,
    secondary: CocoColors.keyWhite,
    onSecondary: CocoColors.keyInk,
    tertiary: CocoColors.keyWarning,
    onTertiary: CocoColors.keyInk,
    error: Color(0xFFFF6B6B),
    onError: CocoColors.keyInk,
    surface: Color(0xFF121212),
    onSurface: Color(0xFFF2F2F2),
    onSurfaceVariant: Color(0xFFB0B0B0),
    surfaceContainerLowest: Color(0xFF0C0C0C),
    surfaceContainerLow: Color(0xFF1B1B1D),
    surfaceContainer: Color(0xFF1B1B1D),
    surfaceContainerHigh: Color(0xFF26262A),
    surfaceContainerHighest: Color(0xFF26262A),
    outline: Color(0xFF5C5C5C),
    outlineVariant: Color(0xFF2E2E30),
  ));

  static ThemeData _build(ColorScheme scheme) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    const buttonText = TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700);
    const buttonSize = Size.fromHeight(52);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2),
        headlineMedium: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
        headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface, fontFamily: fontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: scheme.primary),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, shape: shape, textStyle: buttonText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: buttonSize, shape: shape, textStyle: buttonText, elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: shape,
          textStyle: buttonText.copyWith(fontSize: 15),
          side: BorderSide(color: scheme.outlineVariant, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonText.copyWith(fontSize: 15)),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.secondary,
        labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSecondary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.secondary,
          selectedForegroundColor: scheme.onSecondary,
          textStyle: buttonText.copyWith(fontSize: 14),
          side: BorderSide(color: scheme.outlineVariant),
          shape: shape,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, color: scheme.primary),
        unselectedLabelTextStyle: TextStyle(fontFamily: fontFamily, color: scheme.onSurfaceVariant),
        labelType: NavigationRailLabelType.all,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 24),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withAlpha(70),
        selectionHandleColor: scheme.primary,
      ),
    );
  }
}
