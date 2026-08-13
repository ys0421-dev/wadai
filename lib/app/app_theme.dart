import 'package:flutter/material.dart';

const appBackground = Color(0xFFF8F6F2);
const appCardColor = Color(0xFFFFFFFF);
const appNavigationColor = Color(0xFFFFFEFC);
const appSubtleColor = Color(0xFFF1ECE6);
const appSelectedColor = Color(0xFFF9E4DC);
const appOutlineColor = Color(0xFFE4DED8);
const appOutlineVariantColor = Color(0xFFEEE9E4);
const appTextColor = Color(0xFF2E2A27);
const appSecondaryTextColor = Color(0xFF6D6560);
const brandColor = Color(0xFFB9533B);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: brandColor,
    onPrimary: Colors.white,
    primaryContainer: appSelectedColor,
    onPrimaryContainer: appTextColor,
    secondary: brandColor,
    onSecondary: Colors.white,
    secondaryContainer: appSubtleColor,
    onSecondaryContainer: appTextColor,
    tertiary: brandColor,
    onTertiary: Colors.white,
    tertiaryContainer: appSubtleColor,
    onTertiaryContainer: appTextColor,
    surface: appCardColor,
    onSurface: appTextColor,
    surfaceDim: appBackground,
    surfaceBright: appCardColor,
    surfaceContainerLowest: appCardColor,
    surfaceContainerLow: appCardColor,
    surfaceContainer: appSubtleColor,
    surfaceContainerHigh: appSubtleColor,
    surfaceContainerHighest: appSubtleColor,
    onSurfaceVariant: appSecondaryTextColor,
    outline: appOutlineColor,
    outlineVariant: appOutlineVariantColor,
    inverseSurface: appTextColor,
    onInverseSurface: appCardColor,
    inversePrimary: appSelectedColor,
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: appBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: appBackground,
    foregroundColor: appTextColor,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: appCardColor,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: appOutlineColor),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: appCardColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: appOutlineColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: appOutlineColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: brandColor, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: brandColor,
    foregroundColor: Colors.white,
    shape: StadiumBorder(),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: appNavigationColor,
    indicatorColor: appSelectedColor,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      side: const WidgetStatePropertyAll(BorderSide(color: appOutlineColor)),
      foregroundColor: const WidgetStatePropertyAll(appTextColor),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? appSelectedColor
            : appCardColor,
      ),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: appSubtleColor,
    selectedColor: appSelectedColor,
    side: const BorderSide(color: appOutlineColor),
    shape: const StadiumBorder(),
  ),
  textTheme: ThemeData.light().textTheme.copyWith(
    titleLarge: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: appTextColor,
    ),
    titleMedium: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: appTextColor,
    ),
    titleSmall: const TextStyle(
      fontWeight: FontWeight.w700,
      color: appTextColor,
    ),
    bodyMedium: const TextStyle(color: appTextColor),
    bodySmall: const TextStyle(color: appSecondaryTextColor),
    labelLarge: const TextStyle(
      fontWeight: FontWeight.w700,
      color: appSecondaryTextColor,
    ),
  ),
);
