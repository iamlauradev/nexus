import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Color palette — vibrant dark media tracker
// ---------------------------------------------------------------------------
class RpgColors {
  // Backgrounds — dark blue-black base
  static const Color obsidian    = Color(0xFF0D1117);
  static const Color darkVoid    = Color(0xFF131929);
  static const Color charcoal    = Color(0xFF1A2236);
  static const Color surface     = Color(0xFF212B42);
  static const Color surfaceHigh = Color(0xFF2C3A57);
  static const Color border      = Color(0xFF3D4F6B);

  // Primary accent — bright violet
  static const Color accent      = Color(0xFF8B5CF6);
  static const Color gold        = Color(0xFF8B5CF6);  // alias
  static const Color goldLight   = Color(0xFFA78BFA);
  static const Color goldDark    = Color(0xFF6D28D9);
  static const Color goldGlow    = Color(0x408B5CF6);

  // Secondary — teal/cyan
  static const Color amethyst      = Color(0xFF06B6D4);
  static const Color amethystLight = Color(0xFF67E8F9);
  static const Color amethystGlow  = Color(0x4006B6D4);
  static const Color violet        = Color(0xFF4C1D95);

  // Text
  static const Color textPrimary   = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // Emission status
  static const Color emissionAiring    = Color(0xFF10B981);
  static const Color emissionFinished  = Color(0xFF60A5FA);
  static const Color emissionUpcoming  = Color(0xFFFBBF24);
  static const Color emissionCancelled = Color(0xFFEF4444);
  static const Color emissionHiatus    = Color(0xFFF97316);

  // Status — vibrant
  static const Color statusWatching = Color(0xFF60A5FA);
  static const Color statusComplete = Color(0xFF34D399);
  static const Color statusPlan     = Color(0xFFFBBF24);
  static const Color statusOnHold   = Color(0xFFC084FC);
  static const Color statusDropped  = Color(0xFFF87171);

  // Rating defaults (overridden by user config)
  static const Color ratingMust       = Color(0xFFFBBF24);
  static const Color ratingMeEncanta  = Color(0xFF60A5FA);
  static const Color ratingMuyBonita  = Color(0xFF34D399);
  static const Color ratingBonita     = Color(0xFF6EE7B7);
  static const Color ratingPasable    = Color(0xFFF97316);
  static const Color ratingNoMeGusto  = Color(0xFFF87171);
  static const Color ratingSinValorar = Color(0xFF475569);
}

// ---------------------------------------------------------------------------
// Dynamic rating config cache
// ---------------------------------------------------------------------------
class _RatingEntry {
  final String key;
  final String label;
  final String color;
  final int sortOrder;
  const _RatingEntry(this.key, this.label, this.color, this.sortOrder);
}

class RatingConfigCache {
  static List<_RatingEntry> _entries = _defaults();

  static List<_RatingEntry> _defaults() => [
    const _RatingEntry('must',        '★ Must',         '#FBBF24', 0),
    const _RatingEntry('me_encanta',  '♥ Me encanta',   '#60A5FA', 1),
    const _RatingEntry('muy_bonita',  '✦ Muy bonita',   '#34D399', 2),
    const _RatingEntry('bonita',      '◆ Bonita',       '#6EE7B7', 3),
    const _RatingEntry('pasable',     '◇ Pasable',      '#F97316', 4),
    const _RatingEntry('no_me_gusto', '✕ No me gustó', '#F87171', 5),
    const _RatingEntry('sin_valorar', '· Sin valorar', '#475569', 6),
  ];

  static void update(List<Map<String, dynamic>> configs) {
    if (configs.isEmpty) return;
    _entries = configs.map((c) => _RatingEntry(
      c['key']?.toString() ?? '',
      c['label']?.toString() ?? '',
      c['color']?.toString() ?? '#475569',
      (c['sort_order'] as num?)?.toInt() ?? 99,
    )).toList();
  }

  // Returns a list of plain maps for backward-compat with existing widgets
  static List<Map<String, dynamic>> get configs => _entries.map((e) =>
    <String, dynamic>{'key': e.key, 'label': e.label, 'color': e.color, 'sort_order': e.sortOrder}
  ).toList();

  static Color colorFor(String? key) {
    if (key == null) return RpgColors.ratingSinValorar;
    for (final e in _entries) {
      if (e.key == key) return _hexColor(e.color);
    }
    return _hexColor('#484F58');
  }

  static String labelFor(String? key) {
    if (key == null) return '· Sin valorar';
    for (final e in _entries) {
      if (e.key == key) return e.label;
    }
    return key;
  }
}

Color _hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

// Keep these for backward compat within theme files
Color ratingColor(String? label)  => RatingConfigCache.colorFor(label);
String ratingLabel(String? label) => RatingConfigCache.labelFor(label);

// ---------------------------------------------------------------------------
// Status / type helpers
// ---------------------------------------------------------------------------
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

Color emissionColor(String? status) {
  switch (status) {
    case 'AIRING':    return RpgColors.emissionAiring;
    case 'FINISHED':  return RpgColors.emissionFinished;
    case 'UPCOMING':  return RpgColors.emissionUpcoming;
    case 'CANCELLED': return RpgColors.emissionCancelled;
    case 'HIATUS':    return RpgColors.emissionHiatus;
    default:          return RpgColors.textMuted;
  }
}

String emissionLabel(String? status) {
  switch (status) {
    case 'AIRING':    return 'En emisión';
    case 'FINISHED':  return 'Finalizada';
    case 'UPCOMING':  return 'Próximamente';
    case 'CANCELLED': return 'Cancelada';
    case 'HIATUS':    return 'En hiato';
    default:          return '';
  }
}

String typeLabel(String? type) {
  switch (type) {
    case 'MANGA':   return 'Manga';
    case 'MANHWA':  return 'Manhwa';
    case 'MANHUA':  return 'Manhua';
    case 'WEBTOON': return 'Webtoon';
    case 'NOVEL':   return 'Novela';
    case 'ANIME':   return 'Anime';
    case 'MOVIE':   return 'Película';
    case 'SERIES':  return 'Serie';
    case 'DORAMA':  return 'Dorama';
    default:        return type ?? '';
  }
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------
ThemeData buildRpgTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RpgColors.obsidian,
    colorScheme: ColorScheme.dark(
      primary:    RpgColors.gold,
      secondary:  RpgColors.amethyst,
      surface:    RpgColors.surface,
      error:      RpgColors.statusDropped,
      onPrimary:  RpgColors.obsidian,
      onSecondary: RpgColors.textPrimary,
      onSurface:  RpgColors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: RpgColors.darkVoid,
      foregroundColor: RpgColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      shadowColor: RpgColors.accent.withOpacity(0.3),
      titleTextStyle: const TextStyle(
        fontFamily: 'Cinzel',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: RpgColors.textPrimary,
        letterSpacing: 2,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: RpgColors.darkVoid,
      selectedItemColor: RpgColors.accent,
      unselectedItemColor: RpgColors.textMuted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontFamily: 'Crimson', fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Crimson', fontSize: 9),
    ),
    cardTheme: CardThemeData(
      color: RpgColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: RpgColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RpgColors.charcoal,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RpgColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RpgColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RpgColors.gold, width: 1.5),
      ),
      labelStyle: const TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson'),
      hintStyle: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RpgColors.gold,
        foregroundColor: RpgColors.obsidian,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: 'Cinzel', letterSpacing: 1, fontWeight: FontWeight.bold),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, letterSpacing: 2),
      displayMedium: TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, letterSpacing: 1),
      titleLarge:    TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 18, letterSpacing: 1),
      titleMedium:   TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 14),
      bodyLarge:     TextStyle(fontFamily: 'Crimson', color: RpgColors.textPrimary, fontSize: 16),
      bodyMedium:    TextStyle(fontFamily: 'Crimson', color: RpgColors.textSecondary, fontSize: 14),
      labelMedium:   TextStyle(fontFamily: 'Crimson', color: RpgColors.textMuted, fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(color: RpgColors.border),
    chipTheme: ChipThemeData(
      backgroundColor: RpgColors.charcoal,
      labelStyle: const TextStyle(color: RpgColors.textSecondary, fontSize: 12, fontFamily: 'Crimson'),
      side: const BorderSide(color: RpgColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Light / Dark theme switcher
// ---------------------------------------------------------------------------
class AppTheme {
  static ThemeData dark() => buildRpgTheme();

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    colorScheme: const ColorScheme.light(
      primary: RpgColors.accent,
      surface: Colors.white,
    ),
    fontFamily: 'Crimson',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFEEEEEE),
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cinzel',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A2E),
        letterSpacing: 2,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFEEEEEE),
      selectedItemColor: RpgColors.accent,
      unselectedItemColor: Color(0xFF888888),
      type: BottomNavigationBarType.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RpgColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF555555), fontFamily: 'Crimson'),
      hintStyle: const TextStyle(color: Color(0xFF999999), fontFamily: 'Crimson'),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RpgColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: 'Cinzel', letterSpacing: 1, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
