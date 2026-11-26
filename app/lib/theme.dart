import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBg = Color(0xFF0E1116);
const kSurface = Color(0xFF161B22);
const kBorder = Color(0xFF2A313C);
const kAccent = Color(0xFFB6FF3B); // verde lima
const kTeam = Color(0xFF3DD9EB); // datos reales del Equipo 4
const kText =Color(0xFFE6EDF3);
const kMuted = Color(0xFF8B949E);

/// Breakpoint: por debajo, todo en una columna.
const kWide = 800.0;

TextStyle mono({double size = 14, Color color = kText, FontWeight? weight}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

ThemeData buildTheme() {
  // ponytail: fontFamily en vez de interTextTheme(); este google_fonts choca con el TextTheme de Flutter 3.47.
  final base = ThemeData(
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.inter().fontFamily,
  );
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      onPrimary: kBg,
      surface: kSurface,
      onSurface: kText,
      outline: kBorder,
    ),
    textTheme: base.textTheme.apply(bodyColor: kText, displayColor: kText),
    dividerColor: kBorder,
    tabBarTheme: TabBarThemeData(
      labelColor: kAccent,
      unselectedLabelColor: kMuted,
      indicatorColor: kAccent,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: kBorder,
      labelStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: kText,
        side: const BorderSide(color: kBorder),
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: kAccent,
      collapsedIconColor: kMuted,
      textColor: kText,
      collapsedTextColor: kText,
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
