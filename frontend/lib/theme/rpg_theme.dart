import 'package:flutter/material.dart';

class RpgColors {
  // Base palette
  static const Color obsidian      = Color(0xFF0A0A0F);
  static const Color darkVoid      = Color(0xFF111118);
  static const Color charcoal      = Color(0xFF1A1A25);
  static const Color surface       = Color(0xFF1E1E2E);
  static const Color surfaceHigh   = Color(0xFF262638);
  static const Color border        = Color(0xFF2D2D45);

  // Gold accents
  static const Color gold          = Color(0xFFD4A843);
  static const Color goldLight     = Color(0xFFE8C876);
  static const Color goldDark      = Color(0xFF8B6914);
  static const Color goldGlow      = Color(0x40D4A843);

  // Purple accents
  static const Color amethyst      = Color(0xFF7B2FBE);
  static const Color amethystLight = Color(0xFF9D4EDD);
  static const Color amethystGlow  = Color(0x407B2FBE);
  static const Color violet        = Color(0xFF4A0E8F);

  // Text
  static const Color textPrimary   = Color(0xFFE8DCC8);
  static const Color textSecondary = Color(0xFFAA9E87);
  static const Color textMuted     = Color(0xFF6B6358);

  // Rating colors
  static const Color ratingMust       = Color(0xFF674EA7);  // purple
  static const Color ratingMeEncanta  = Color(0xFF45818E);  // teal
  static const Color ratingMuyBonita  = Color(0xFFF1C232);  // yellow-gold
  static const Color ratingBonita     = Color(0xFF6AA84F);  // green
  static const Color ratingPasable    = Color(0xFFE69138);  // orange
  static const Color ratingNoMeGusto  = Color(0xFFCC4125);  // red
  static const Color ratingAbandonado = Color(0xFF666666);  // gray
  static const Color ratingSinValorar = Color(0xFF2D2D45);  // dark

  // Status colors
  static const Color statusWatching = Color(0xFF4FC3F7);
  static const Color statusComplete = Color(0xFF81C784);
  static const Color statusPlan     = Color(0xFFFFB74D);
  static const Color statusOnHold   = Color(0xFFBA68C8);
  static const Color statusDropped  = Color(0xFFE57373);
}

Color ratingColor(String? label) {
  switch (label) {
    case 'must':        return RpgColors.ratingMust;
    case 'me_encanta':  return RpgColors.ratingMeEncanta;
    case 'muy_bonita':  return RpgColors.ratingMuyBonita;
    case 'bonita':      return RpgColors.ratingBonita;
    case 'pasable':     return RpgColors.ratingPasable;
    case 'no_me_gusto': return RpgColors.ratingNoMeGusto;
    case 'abandonado':  return RpgColors.ratingAbandonado;
    default:            return RpgColors.ratingSinValorar;
  }
}

String ratingLabel(String? label) {
  switch (label) {
    case 'must':        return '★ Must';
    case 'me_encanta':  return '♥ Me encanta';
    case 'muy_bonita':  return '✦ Es muy bonita';
    case 'bonita':      return '◆ Es bonita';
    case 'pasable':     return '◇ Pasable';
    case 'no_me_gusto': return '✕ No me ha gustado';
    case 'abandonado':  return '— Abandonado';
    default:            return '· Sin valorar';
  }
}

Color statusColor(String? status) {
  switch (status) {
    case 'watching':      return RpgColors.statusWatching;
    case 'completed':     return RpgColors.statusComplete;
    case 'plan_to_watch': return RpgColors.statusPlan;
    case 'on_hold':       return RpgColors.statusOnHold;
    case 'dropped':       return RpgColors.statusDropped;
    default:              return RpgColors.textMuted;
  }
}

String statusLabel(String? status) {
  switch (status) {
    case 'watching':      return 'Viendo';
    case 'completed':     return 'Completado';
    case 'plan_to_watch': return 'Pendiente';
    case 'on_hold':       return 'En espera';
    case 'dropped':       return 'Abandonado';
    default:              return status ?? '';
  }
}

String typeLabel(String? type) {
  switch (type) {
    case 'MANGA':   return 'Manga';
    case 'MANHWA':  return 'Manhwa';
    case 'MANHUA':  return 'Manhua';
    case 'WEBTOON': return 'Webtoon';
    case 'ANIME':   return 'Anime';
    case 'MOVIE':   return 'Película';
    case 'SERIES':  return 'Serie';
    case 'DORAMA':  return 'Dorama';
    default:        return type ?? '';
  }
}

ThemeData buildRpgTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RpgColors.obsidian,
    colorScheme: ColorScheme.dark(
      primary:    RpgColors.gold,
      secondary:  RpgColors.amethyst,
      surface:    RpgColors.surface,
      error:      RpgColors.ratingNoMeGusto,
      onPrimary:  RpgColors.obsidian,
      onSecondary: RpgColors.textPrimary,
      onSurface:  RpgColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RpgColors.darkVoid,
      foregroundColor: RpgColors.gold,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cinzel',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: RpgColors.gold,
        letterSpacing: 2,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: RpgColors.darkVoid,
      selectedItemColor: RpgColors.gold,
      unselectedItemColor: RpgColors.textMuted,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardThemeData(
      color: RpgColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: RpgColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RpgColors.charcoal,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: RpgColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: RpgColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: RpgColors.gold, width: 2),
      ),
      labelStyle: const TextStyle(color: RpgColors.textSecondary),
      hintStyle: const TextStyle(color: RpgColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RpgColors.goldDark,
        foregroundColor: RpgColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontFamily: 'Cinzel', letterSpacing: 1),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Cinzel', color: RpgColors.gold, letterSpacing: 3),
      displayMedium: TextStyle(fontFamily: 'Cinzel', color: RpgColors.gold, letterSpacing: 2),
      titleLarge: TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 18, letterSpacing: 1),
      titleMedium: TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 14),
      bodyLarge: TextStyle(fontFamily: 'Crimson', color: RpgColors.textPrimary, fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'Crimson', color: RpgColors.textSecondary, fontSize: 14),
      labelMedium: TextStyle(fontFamily: 'Crimson', color: RpgColors.textMuted, fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(color: RpgColors.border),
    chipTheme: ChipThemeData(
      backgroundColor: RpgColors.charcoal,
      labelStyle: const TextStyle(color: RpgColors.textSecondary, fontSize: 12),
      side: const BorderSide(color: RpgColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}
