import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Spacing system
// ---------------------------------------------------------------------------
class RpgSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets cardPadding   = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(sm);
  static const EdgeInsets pagePadding   = EdgeInsets.symmetric(horizontal: md, vertical: sm);

  static const SizedBox gapXs  = SizedBox(height: xs);
  static const SizedBox gapSm  = SizedBox(height: sm);
  static const SizedBox gapMd  = SizedBox(height: md);
  static const SizedBox gapLg  = SizedBox(height: lg);
  static const SizedBox gapXl  = SizedBox(height: xl);
  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
}

// ---------------------------------------------------------------------------
// Color palette — deep purple-black identity (dark) / soft lavender (light)
// ---------------------------------------------------------------------------
class RpgColors {
  static bool _dark = true;
  static void setMode(bool dark) { _dark = dark; }
  static bool get isDark => _dark;

  // Elevation stack — adaptive dark/light
  static Color get obsidian    => _dark ? const Color(0xFF09080F) : const Color(0xFFF5F3FF);
  static Color get darkVoid    => _dark ? const Color(0xFF0F0D1A) : const Color(0xFFFFFFFF);
  static Color get charcoal    => _dark ? const Color(0xFF141130) : const Color(0xFFEDE9FF);
  static Color get surface     => _dark ? const Color(0xFF1A1730) : const Color(0xFFFFFFFF);
  static Color get surfaceHigh => _dark ? const Color(0xFF221F40) : const Color(0xFFF8F5FF);
  static Color get border      => _dark ? const Color(0xFF2A2548) : const Color(0xFFCDC5F0);
  static Color get divider     => _dark ? const Color(0xFF1E1C38) : const Color(0xFFE8E4FF);

  // Primary accent — indigo-violet (same in both modes)
  static const Color accent      = Color(0xFF7C6FEB);
  static const Color gold        = Color(0xFF7C6FEB);  // alias kept for compat
  static const Color goldLight   = Color(0xFF9D94F5);
  static const Color goldDark    = Color(0xFF5B52CC);
  static const Color goldGlow    = Color(0x337C6FEB);

  // Secondary — sky blue (replaces harsh cyan)
  static const Color amethyst      = Color(0xFF38BDF8);
  static const Color amethystLight = Color(0xFF7DD3FC);
  static const Color amethystGlow  = Color(0x3338BDF8);
  static const Color violet        = Color(0xFF4C1D95);

  // Text — adaptive warm white (dark) / deep purple (light)
  static Color get textPrimary   => _dark ? const Color(0xFFF4F1FF) : const Color(0xFF1A1730);
  static Color get textSecondary => _dark ? const Color(0xFF8B84B0) : const Color(0xFF4A4570);
  static Color get textMuted     => _dark ? const Color(0xFF4A4570) : const Color(0xFF8B84B0);

  // Emission status
  static const Color emissionAiring    = Color(0xFF3CC98A); // emerald
  static const Color emissionFinished  = Color(0xFF5BB8F5); // sky
  static const Color emissionUpcoming  = Color(0xFFF4AB35); // amber
  static const Color emissionCancelled = Color(0xFFF06080); // rose-red
  static const Color emissionHiatus    = Color(0xFFE08840); // orange

  // User tracking status — comfortable, not harsh
  static const Color statusWatching = Color(0xFF5BB8F5); // sky blue
  static const Color statusComplete = Color(0xFF3CC98A); // emerald
  static const Color statusPlan     = Color(0xFFF4AB35); // amber
  static const Color statusOnHold   = Color(0xFFA78BFA); // lavender
  static const Color statusDropped  = Color(0xFFF06080); // rose-red

  // Rating defaults (overridden by user config)
  static const Color ratingMust       = Color(0xFFF4AB35);
  static const Color ratingMeEncanta  = Color(0xFF5BB8F5);
  static const Color ratingMuyBonita  = Color(0xFF3CC98A);
  static const Color ratingBonita     = Color(0xFF6EE7B7);
  static const Color ratingPasable    = Color(0xFFE08840);
  static const Color ratingNoMeGusto  = Color(0xFFF06080);
  static const Color ratingSinValorar = Color(0xFF4A4570);
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
    const _RatingEntry('must',        '★ Must',         '#F4AB35', 0),
    const _RatingEntry('me_encanta',  '♥ Me encanta',   '#5BB8F5', 1),
    const _RatingEntry('muy_bonita',  '✦ Muy bonita',   '#3CC98A', 2),
    const _RatingEntry('bonita',      '◆ Bonita',       '#6EE7B7', 3),
    const _RatingEntry('pasable',     '◇ Pasable',      '#E08840', 4),
    const _RatingEntry('no_me_gusto', '✕ No me gustó', '#F06080', 5),
    const _RatingEntry('sin_valorar', '· Sin valorar', '#4A4570', 6),
  ];

  static void update(List<Map<String, dynamic>> configs) {
    if (configs.isEmpty) return;
    _entries = configs.map((c) => _RatingEntry(
      c['key']?.toString() ?? '',
      c['label']?.toString() ?? '',
      c['color']?.toString() ?? '#4A4570',
      (c['sort_order'] as num?)?.toInt() ?? 99,
    )).toList();
    // sin_valorar must always exist so the "no rating" dropdown option is valid
    if (!_entries.any((e) => e.key == 'sin_valorar')) {
      _entries.add(const _RatingEntry('sin_valorar', '· Sin valorar', '#4A4570', 999));
    }
  }

  static List<Map<String, dynamic>> get configs => _entries.map((e) =>
    <String, dynamic>{'key': e.key, 'label': e.label, 'color': e.color, 'sort_order': e.sortOrder}
  ).toList();

  static Color colorFor(String? key) {
    if (key == null) return RpgColors.ratingSinValorar;
    for (final e in _entries) {
      if (e.key == key) return _hexColor(e.color);
    }
    return _hexColor('#4A4570');
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
    brightness: RpgColors.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: RpgColors.obsidian,
    colorScheme: RpgColors.isDark
      ? ColorScheme.dark(
          primary:     RpgColors.accent,
          secondary:   RpgColors.amethyst,
          surface:     RpgColors.surface,
          error:       RpgColors.statusDropped,
          onPrimary:   Colors.white,
          onSecondary: RpgColors.textPrimary,
          onSurface:   RpgColors.textPrimary,
        )
      : ColorScheme.light(
          primary:     RpgColors.accent,
          secondary:   RpgColors.amethyst,
          surface:     RpgColors.surface,
          error:       RpgColors.statusDropped,
          onPrimary:   Colors.white,
          onSecondary: RpgColors.textPrimary,
          onSurface:   RpgColors.textPrimary,
        ),

    // AppBar — same as scaffold, seamless feel
    appBarTheme: AppBarTheme(
      backgroundColor: RpgColors.obsidian,
      foregroundColor: RpgColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cinzel',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: RpgColors.textPrimary,
        letterSpacing: 0.8,
      ),
    ),

    // Bottom nav — elevated one step
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: RpgColors.darkVoid,
      selectedItemColor: RpgColors.accent,
      unselectedItemColor: RpgColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 10),
    ),

    // Cards — no border, depth from color only, larger radius
    cardTheme: CardThemeData(
      color: RpgColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Inputs — subtle fill, only accent border on focus
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RpgColors.charcoal,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: RpgColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: RpgColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RpgColors.accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: RpgColors.textSecondary, fontFamily: 'DMSans', fontSize: 13),
      hintStyle: TextStyle(color: RpgColors.textMuted, fontFamily: 'DMSans', fontSize: 13),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RpgColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: TextStyle(fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RpgColors.textSecondary,
        side: BorderSide(color: RpgColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: TextStyle(fontFamily: 'DMSans', fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RpgColors.textSecondary,
        textStyle: TextStyle(fontFamily: 'DMSans', fontSize: 13),
      ),
    ),

    // Typography hierarchy:
    //   Cinzel   → brand identity (display, big titles)
    //   DMSans   → UI chrome (labels, nav, buttons, metadata)
    //   Crimson  → content (descriptions, body text)
    textTheme: TextTheme(
      displayLarge:  TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 34, letterSpacing: 1.5, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 26, letterSpacing: 1),
      displaySmall:  TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 20, letterSpacing: 0.5),
      titleLarge:    TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 18, letterSpacing: 0.5, fontWeight: FontWeight.w700),
      titleMedium:   TextStyle(fontFamily: 'Cinzel', color: RpgColors.textPrimary, fontSize: 15, letterSpacing: 0.3),
      titleSmall:    TextStyle(fontFamily: 'DMSans',  color: RpgColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
      bodyLarge:     TextStyle(fontFamily: 'Crimson', color: RpgColors.textPrimary,   fontSize: 17, height: 1.55),
      bodyMedium:    TextStyle(fontFamily: 'Crimson', color: RpgColors.textSecondary, fontSize: 15, height: 1.5),
      bodySmall:     TextStyle(fontFamily: 'Crimson', color: RpgColors.textMuted,     fontSize: 13, height: 1.4),
      labelLarge:    TextStyle(fontFamily: 'DMSans',  color: RpgColors.textPrimary,   fontSize: 13, fontWeight: FontWeight.w600),
      labelMedium:   TextStyle(fontFamily: 'DMSans',  color: RpgColors.textSecondary, fontSize: 12),
      labelSmall:    TextStyle(fontFamily: 'DMSans',  color: RpgColors.textMuted,     fontSize: 10, letterSpacing: 0.3),
    ),

    // Divider — very subtle
    dividerTheme: DividerThemeData(color: RpgColors.divider, thickness: 1),

    // Chips — pill style
    chipTheme: ChipThemeData(
      backgroundColor: RpgColors.charcoal,
      labelStyle: TextStyle(color: RpgColors.textSecondary, fontSize: 12, fontFamily: 'DMSans'),
      side: BorderSide(color: RpgColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),

    // TabBar — pill-style indicator
    tabBarTheme: TabBarThemeData(
      labelColor: RpgColors.textPrimary,
      unselectedLabelColor: RpgColors.textMuted,
      indicator: BoxDecoration(
        color: RpgColors.accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RpgColors.accent.withOpacity(0.5)),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 12),
      dividerColor: Colors.transparent,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: RpgColors.surfaceHigh,
      contentTextStyle: TextStyle(color: RpgColors.textPrimary, fontFamily: 'DMSans', fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: RpgColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(fontFamily: 'Cinzel', fontSize: 16, fontWeight: FontWeight.w700, color: RpgColors.textPrimary),
      contentTextStyle: TextStyle(fontFamily: 'Crimson', fontSize: 15, color: RpgColors.textSecondary),
    ),
  );
}

// ---------------------------------------------------------------------------
// Theme switcher — dark-first app
// ---------------------------------------------------------------------------
class AppTheme {
  static ThemeData dark()  { RpgColors.setMode(true);  return buildRpgTheme(); }
  static ThemeData light() { RpgColors.setMode(false); return buildRpgTheme(); }
}
