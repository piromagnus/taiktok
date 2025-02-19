import 'package:flutter/material.dart';

enum AppTheme {
  cyberNeon('Cyber Neon'),
  matrixGreen('Matrix Green'),
  spaceBlue('Space Blue'),
  cyberGalaxy('Cyber Galaxy'),
  nebulaHorizon('Nebula Horizon');

  final String displayName;
  const AppTheme(this.displayName);
}

class AppThemes {
  static ThemeData cyberNeon = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00E5FF),
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1B26),
      primary: const Color(0xFF00E5FF),
      secondary: const Color(0xFF80DEEA),
      tertiary: const Color(0xFFB2EBF2),
    ).copyWith(
      surfaceTint: const Color(0xFF1A1B26),
      primaryContainer: const Color(0xFF006064),
      secondaryContainer: const Color(0xFF00838F),
      tertiaryContainer: const Color(0xFF0097A7),
      surfaceContainer: const Color(0xFF1A1B26),
      surfaceContainerLow: const Color(0xFF13141C),
      surfaceContainerHigh: const Color(0xFF2A2B36),
    ),
    cardTheme: CardTheme(
      elevation: 8,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(
          color: Color(0xFF00E5FF),
          width: 1,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF00E5FF)),
      foregroundColor: Color(0xFFFFFFFF),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFFE0E0E0),
        fontSize: 16,
        letterSpacing: 0.15,
      ),
      titleMedium: TextStyle(
        color: Color(0xFF00E5FF),
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF00E5FF),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF006064),
        foregroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF80DEEA), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
      floatingLabelStyle: const TextStyle(color: Color(0xFF80DEEA)),
    ),
  );

  static ThemeData matrixGreen = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00FF00),
      brightness: Brightness.dark,
      surface: const Color(0xFF0A1F0A),
      primary: const Color(0xFF00FF00),
      secondary: const Color(0xFF90EE90),
      tertiary: const Color(0xFFADFF2F),
    ).copyWith(
      surfaceTint: const Color(0xFF0A1F0A),
      primaryContainer: const Color(0xFF006400),
      secondaryContainer: const Color(0xFF228B22),
      tertiaryContainer: const Color(0xFF32CD32),
      surfaceContainer: const Color(0xFF0A1F0A),
      surfaceContainerLow: const Color(0xFF051505),
      surfaceContainerHigh: const Color(0xFF1A3F1A),
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(
          color: Color(0xFF00FF00),
          width: 1,
        ),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Color(0xFF00FF00),
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        fontFamily: 'Courier',
      ),
      bodyLarge: TextStyle(
        color: Color(0xFF90EE90),
        fontSize: 16,
        letterSpacing: 0.5,
        fontFamily: 'Courier',
      ),
      titleMedium: TextStyle(
        color: Color(0xFF00FF00),
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        fontFamily: 'Courier',
      ),
    ),
  );

  static ThemeData spaceBlue = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4169E1),
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1B2E),
      primary: const Color(0xFF4169E1),
      secondary: const Color(0xFF87CEEB),
      tertiary: const Color(0xFFA7C7E7),
    ).copyWith(
      surfaceTint: const Color(0xFF1A1B2E),
      primaryContainer: const Color(0xFF000080),
      secondaryContainer: const Color(0xFF4682B4),
      tertiaryContainer: const Color(0xFF6495ED),
      surfaceContainer: const Color(0xFF1A1B2E),
      surfaceContainerLow: const Color(0xFF0F1018),
      surfaceContainerHigh: const Color(0xFF2A2B3E),
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(
          color: Color(0xFF4169E1),
          width: 1,
        ),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFFB0C4DE),
        fontSize: 16,
        letterSpacing: 0.15,
      ),
      titleMedium: TextStyle(
        color: Color(0xFF87CEEB),
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
  );

  static final ThemeData cyberGalaxy = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueAccent,
      surface: const Color(0xFF1A1B26),
      brightness: Brightness.dark,
      background: const Color(0xFF1A1B26),
      onBackground: Colors.white,
      primary: Colors.cyanAccent,
      secondary: Colors.blueAccent,
    ).copyWith(
      surfaceTint: const Color(0xFF1A1B26),
      background: const Color(0xFF1A1B26),
      surface: const Color(0xFF1A1B26),
      surfaceContainer: const Color(0xFF1A1B26),
      surfaceContainerLow: const Color(0xFF1A1B26),
      surfaceContainerLowest: const Color(0xFF1A1B26),
      surfaceContainerHigh: const Color(0xFF1A1B26),
      surfaceContainerHighest: const Color(0xFF1A1B26),
    ),
    scaffoldBackgroundColor: const Color(0xFF1A1B26),
    canvasColor: const Color(0xFF1A1B26),
    cardColor: const Color(0xFF1A1B26),
    dialogBackgroundColor: const Color(0xFF1A1B26),
    // bottomAppBarColor: const Color(0xFF1A1B26),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      titleTextStyle: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.cyanAccent,
      ),
      iconTheme: IconThemeData(color: Colors.cyanAccent),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 16,
        color: Colors.white,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.cyanAccent,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: 'Orbitron'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );

  static final ThemeData nebulaHorizon = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.deepPurple,
    scaffoldBackgroundColor: const Color(0xFFF4F4F8),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.deepPurple.shade700,
      titleTextStyle: const TextStyle(
        fontFamily: 'Exo',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Exo',
        fontSize: 16,
        color: Colors.black87,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Exo',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: 'Exo'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  );

  static ThemeData getTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.cyberNeon:
        return cyberNeon;
      case AppTheme.matrixGreen:
        return matrixGreen;
      case AppTheme.spaceBlue:
        return spaceBlue;
      case AppTheme.cyberGalaxy:
        return cyberGalaxy;
      case AppTheme.nebulaHorizon:
        return nebulaHorizon;
    }
  }
}
