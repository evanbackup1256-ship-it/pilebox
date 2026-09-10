import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// A named colour scheme.
///
/// Themes are data, not code, so new ones ship without touching widgets,
/// and users can author their own in the theme builder.
@immutable
class AppSkin {
  const AppSkin({
    required this.id,
    required this.name,
    required this.blurb,
    required this.voidColor,
    required this.surface,
    required this.surfaceRaised,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.live,
    required this.paused,
    required this.dropped,
    required this.glowOrigin,
    this.custom = false,
  });

  final String id;
  final String name;
  final String blurb;
  final bool custom;

  final Color voidColor;
  final Color surface;
  final Color surfaceRaised;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentSoft;
  final Color live;
  final Color paused;
  final Color dropped;

  /// Where the ambient background light sits, in normalised alignment coords.
  final Alignment glowOrigin;

  bool get isLight => voidColor.computeLuminance() > 0.5;

  AppSkin withAccent(Color next) => copyWith(accent: next, accentSoft: next);

  AppSkin copyWith({
    String? id,
    String? name,
    String? blurb,
    Color? voidColor,
    Color? surface,
    Color? surfaceRaised,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentSoft,
    Color? live,
    Color? paused,
    Color? dropped,
    Alignment? glowOrigin,
    bool? custom,
  }) {
    return AppSkin(
      id: id ?? this.id,
      name: name ?? this.name,
      blurb: blurb ?? this.blurb,
      custom: custom ?? this.custom,
      voidColor: voidColor ?? this.voidColor,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      live: live ?? this.live,
      paused: paused ?? this.paused,
      dropped: dropped ?? this.dropped,
      glowOrigin: glowOrigin ?? this.glowOrigin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'blurb': blurb,
        'voidColor': voidColor.toARGB32(),
        'surface': surface.toARGB32(),
        'surfaceRaised': surfaceRaised.toARGB32(),
        'hairline': hairline.toARGB32(),
        'textPrimary': textPrimary.toARGB32(),
        'textSecondary': textSecondary.toARGB32(),
        'textTertiary': textTertiary.toARGB32(),
        'accent': accent.toARGB32(),
        'accentSoft': accentSoft.toARGB32(),
        'live': live.toARGB32(),
        'paused': paused.toARGB32(),
        'dropped': dropped.toARGB32(),
        'glowX': glowOrigin.x,
        'glowY': glowOrigin.y,
      };

  factory AppSkin.fromJson(Map<String, dynamic> json) {
    Color col(String key, Color fallback) {
      final v = json[key];
      return v is num ? Color(v.toInt()) : fallback;
    }

    const base = Skins.amber;
    return AppSkin(
      id: json['id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Custom',
      blurb: json['blurb'] as String? ?? 'Your own theme.',
      custom: true,
      voidColor: col('voidColor', base.voidColor),
      surface: col('surface', base.surface),
      surfaceRaised: col('surfaceRaised', base.surfaceRaised),
      hairline: col('hairline', base.hairline),
      textPrimary: col('textPrimary', base.textPrimary),
      textSecondary: col('textSecondary', base.textSecondary),
      textTertiary: col('textTertiary', base.textTertiary),
      accent: col('accent', base.accent),
      accentSoft: col('accentSoft', base.accentSoft),
      live: col('live', base.live),
      paused: col('paused', base.paused),
      dropped: col('dropped', base.dropped),
      glowOrigin: Alignment(
        switch (json['glowX']) { final num v => v.toDouble(), _ => -0.75 },
        switch (json['glowY']) { final num v => v.toDouble(), _ => -0.95 },
      ),
    );
  }
}

/// Built-in skins.
///
/// Each is tuned as a whole rather than by hue-rotating one base: the greys
/// carry a different cast per theme, which is what stops them looking like
/// a generated palette set.
class Skins {
  const Skins._();

  static const amber = AppSkin(
    id: 'amber',
    name: 'Studio Amber',
    blurb: 'Warm charcoal and VU-lamp gold.',
    voidColor: Color(0xFF0B0B0F),
    surface: Color(0xFF131318),
    surfaceRaised: Color(0xFF1A1A21),
    hairline: Color(0xFF26262F),
    textPrimary: Color(0xFFF2F1F5),
    textSecondary: Color(0xFF9B9AA8),
    textTertiary: Color(0xFF5F5E6B),
    accent: Color(0xFFE8A33D),
    accentSoft: Color(0xFFF0BB63),
    live: Color(0xFF57D2A0),
    paused: Color(0xFFD8B04A),
    dropped: Color(0xFFE0685E),
    glowOrigin: Alignment(-0.75, -0.95),
  );

  static const graphite = AppSkin(
    id: 'graphite',
    name: 'Graphite',
    blurb: 'Neutral and quiet. Nothing competes with the art.',
    voidColor: Color(0xFF0C0D0E),
    surface: Color(0xFF141618),
    surfaceRaised: Color(0xFF1B1E21),
    hairline: Color(0xFF272B2F),
    textPrimary: Color(0xFFF0F2F4),
    textSecondary: Color(0xFF98A0A8),
    textTertiary: Color(0xFF5C646C),
    accent: Color(0xFFD6DCE2),
    accentSoft: Color(0xFFFFFFFF),
    live: Color(0xFF6FCF97),
    paused: Color(0xFFC9C06A),
    dropped: Color(0xFFD97C72),
    glowOrigin: Alignment(0.0, -1.0),
  );

  static const oxide = AppSkin(
    id: 'oxide',
    name: 'Oxide',
    blurb: 'Rust and iron. Heavy, industrial contrast.',
    voidColor: Color(0xFF0D0A09),
    surface: Color(0xFF16110F),
    surfaceRaised: Color(0xFF1F1815),
    hairline: Color(0xFF2E231E),
    textPrimary: Color(0xFFF5EEE9),
    textSecondary: Color(0xFFA89286),
    textTertiary: Color(0xFF6B5850),
    accent: Color(0xFFD2603A),
    accentSoft: Color(0xFFE8815C),
    live: Color(0xFF7FB069),
    paused: Color(0xFFC98B3A),
    dropped: Color(0xFFD9534F),
    glowOrigin: Alignment(-0.85, -0.8),
  );

  static const cyan = AppSkin(
    id: 'cyan',
    name: 'Cold Storage',
    blurb: 'Deep blue steel with a signal-cyan accent.',
    voidColor: Color(0xFF070A0E),
    surface: Color(0xFF0F151C),
    surfaceRaised: Color(0xFF161E27),
    hairline: Color(0xFF222D3A),
    textPrimary: Color(0xFFEAF2F8),
    textSecondary: Color(0xFF8A9BAB),
    textTertiary: Color(0xFF52626F),
    accent: Color(0xFF4EC5D9),
    accentSoft: Color(0xFF7FDCEB),
    live: Color(0xFF4ED9A4),
    paused: Color(0xFFD9C24E),
    dropped: Color(0xFFE06B7E),
    glowOrigin: Alignment(0.85, -0.9),
  );

  static const bloom = AppSkin(
    id: 'bloom',
    name: 'Nocturne',
    blurb: 'Ink violet with a muted rose highlight.',
    voidColor: Color(0xFF0A0810),
    surface: Color(0xFF120F1A),
    surfaceRaised: Color(0xFF1A1524),
    hairline: Color(0xFF272033),
    textPrimary: Color(0xFFF1ECF7),
    textSecondary: Color(0xFF9C93AE),
    textTertiary: Color(0xFF605872),
    accent: Color(0xFFD98BA6),
    accentSoft: Color(0xFFEDAFC4),
    live: Color(0xFF6FCFA8),
    paused: Color(0xFFCBA96B),
    dropped: Color(0xFFE0707E),
    glowOrigin: Alignment(-0.2, -1.0),
  );

  static const forest = AppSkin(
    id: 'forest',
    name: 'Understory',
    blurb: 'Deep green with a warm moss accent.',
    voidColor: Color(0xFF080C09),
    surface: Color(0xFF0F1611),
    surfaceRaised: Color(0xFF161F18),
    hairline: Color(0xFF223026),
    textPrimary: Color(0xFFEDF4EE),
    textSecondary: Color(0xFF8FA495),
    textTertiary: Color(0xFF566A5C),
    accent: Color(0xFF8FBF6A),
    accentSoft: Color(0xFFB0D68F),
    live: Color(0xFF6FCF97),
    paused: Color(0xFFC9B06A),
    dropped: Color(0xFFD97C72),
    glowOrigin: Alignment(-0.6, -0.85),
  );

  static const paper = AppSkin(
    id: 'paper',
    name: 'Daylight',
    blurb: 'A light theme that still reads as a pro tool.',
    voidColor: Color(0xFFF4F3F1),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFAF9F7),
    hairline: Color(0xFFE2E0DC),
    textPrimary: Color(0xFF1A1A1F),
    textSecondary: Color(0xFF5F5E68),
    textTertiary: Color(0xFF95939C),
    accent: Color(0xFFB8761A),
    accentSoft: Color(0xFFD79B3D),
    live: Color(0xFF2E9E6B),
    paused: Color(0xFFB08A2E),
    dropped: Color(0xFFC7503F),
    glowOrigin: Alignment(-0.8, -1.0),
  );

  static const builtIn = [
    amber,
    graphite,
    oxide,
    cyan,
    bloom,
    forest,
    paper,
  ];

  /// Custom skins loaded from settings, registered at startup.
  static List<AppSkin> userSkins = const [];

  static List<AppSkin> get all => [...builtIn, ...userSkins];

  static AppSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => amber);

  /// A sensible starting point for the theme builder.
  static AppSkin blank(String name) => amber.copyWith(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        blurb: 'Your own theme.',
        custom: true,
      );
}

/// The active skin, swapped at runtime.
class Palette {
  const Palette._();

  static AppSkin skin = Skins.amber;

  /// Bumped on every visual change so widgets can key off it and rebuild.
  ///
  /// The colours are read through static getters, which Flutter cannot
  /// observe. Rebuilding the whole tree under a changing key is what
  /// actually makes a theme switch take effect.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void apply(AppSkin next, {Color? accentOverride}) {
    final resolved =
        accentOverride == null ? next : next.withAccent(accentOverride);
    if (resolved.id == skin.id &&
        resolved.accent.toARGB32() == skin.accent.toARGB32()) {
      return;
    }
    skin = resolved;
    bump();
  }

  /// Schedules a repaint of everything that reads these colours.
  ///
  /// Deferred to after the current frame: settings are applied from inside a
  /// build in some paths, and notifying a listener mid-build throws.
  static void bump() {
    WidgetsBinding.instance.addPostFrameCallback((_) => revision.value++);
  }

  static Color get void_ => skin.voidColor;
  static Color get surface => skin.surface;
  static Color get surfaceRaised => skin.surfaceRaised;
  static Color get hairline => skin.hairline;
  static Color get textPrimary => skin.textPrimary;
  static Color get textSecondary => skin.textSecondary;
  static Color get textTertiary => skin.textTertiary;
  static Color get amber => skin.accent;
  static Color get amberSoft => skin.accentSoft;
  static Color get live => skin.live;
  static Color get paused => skin.paused;
  static Color get dropped => skin.dropped;

  /// A surface that sits above [surface], used for the app chrome.
  static Color get chrome => Color.alphaBlend(
        (skin.isLight ? Colors.white : Colors.black).withValues(alpha: 0.35),
        skin.voidColor,
      );
}

/// Layout scale, driven by the density setting.
class Layout {
  const Layout._();

  static double _scale = 1.0;
  static double textScale = 1.0;

  static void apply(double densityScale, double text) {
    if (_scale == densityScale && textScale == text) return;
    _scale = densityScale;
    textScale = text;
    Palette.bump();
  }

  static double get gutter => 30 * _scale;
  static double get gap => 22 * _scale;
  static double get tight => 12 * _scale;
  static double get cardPad => 15 * _scale;
  static double get rowGap => 9 * _scale;
}

/// A deliberate type scale. Sizes are not a linear ramp: the display size
/// jumps hard from the label size so the track title dominates, which is how
/// premium music clients establish hierarchy.
class AppType {
  const AppType._();

  static const _family = 'Segoe UI';

  static double _s(double size) => size * Layout.textScale;

  static TextStyle get label => TextStyle(
        fontFamily: _family,
        fontSize: _s(10),
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.7,
        color: Palette.textTertiary,
      );

  static TextStyle get title => TextStyle(
        fontFamily: _family,
        fontSize: _s(28),
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: Palette.textPrimary,
      );

  static TextStyle get heading => TextStyle(
        fontFamily: _family,
        fontSize: _s(17),
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Palette.textPrimary,
      );

  static TextStyle get artist => TextStyle(
        fontFamily: _family,
        fontSize: _s(15),
        height: 1.3,
        color: Palette.textSecondary,
      );

  static TextStyle get body => TextStyle(
        fontFamily: _family,
        fontSize: _s(13),
        height: 1.45,
        color: Palette.textSecondary,
      );

  static TextStyle get small => TextStyle(
        fontFamily: _family,
        fontSize: _s(11.5),
        height: 1.4,
        color: Palette.textTertiary,
      );

  /// Tabular figures keep the timecode from jittering as digits change.
  static TextStyle get timecode => TextStyle(
        fontFamily: 'Consolas',
        fontSize: _s(11),
        height: 1.2,
        letterSpacing: 0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: Palette.textTertiary,
      );

  static TextStyle get numeral => TextStyle(
        fontFamily: _family,
        fontSize: _s(26),
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: Palette.textPrimary,
      );

  static TextStyle get mono => TextStyle(
        fontFamily: 'Consolas',
        fontSize: _s(11.5),
        height: 1.6,
        color: Palette.textSecondary,
      );
}

/// Motion tokens. Springs, not linear curves - every transition here is
/// interruptible and settles rather than stopping dead.
class Motion {
  const Motion._();

  /// 0 = reduced, 1 = normal, 2 = expressive.
  static int level = 1;

  static Duration _d(int ms) => switch (level) {
        0 => Duration.zero,
        2 => Duration(milliseconds: (ms * 1.25).round()),
        _ => Duration(milliseconds: ms),
      };

  static Duration get quick => _d(170);
  static Duration get base => _d(320);
  static Duration get slow => _d(620);

  /// Overshoots slightly, then settles. For state badges and entrances.
  static Curve get spring =>
      level == 0 ? Curves.linear : const Cubic(0.2, 0.9, 0.24, 1.08);

  /// No overshoot, fast out. For hover and press.
  static Curve get swift =>
      level == 0 ? Curves.linear : const Cubic(0.22, 1, 0.36, 1);

  /// Slow settle for large surfaces.
  static Curve get glide =>
      level == 0 ? Curves.linear : const Cubic(0.16, 1, 0.3, 1);

  static bool get enabled => level > 0;
}

/// Reads the saved appearance settings before the app builds, so the first
/// painted frame is already correct.
Future<void> bootstrapSkin() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}\\settings.json');
    if (!await file.exists()) return;

    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) return;

    // Register custom skins first so a saved custom id resolves.
    final custom = json['customSkins'];
    if (custom is List) {
      Skins.userSkins = custom
          .whereType<Map<String, dynamic>>()
          .map(AppSkin.fromJson)
          .toList(growable: false);
    }

    Motion.level = switch (json['motionLevel']) {
      'reduced' => 0,
      'expressive' => 2,
      _ => 1,
    };

    Layout.apply(
      switch (json['density']) {
        'compact' => 0.82,
        'spacious' => 1.18,
        _ => 1.0,
      },
      // Read defensively: bootstrapSkin runs before any UI exists, so an
      // unhandled cast error here means the app never starts.
      switch (json['textScale']) {
        final num v => v.toDouble().clamp(0.7, 1.6),
        _ => 1.0,
      },
    );

    final id = json['skinId'];
    if (id is! String) return;

    final skin = Skins.byId(id);
    final override = json['accentOverride'];
    Palette.skin = (override is num && override != 0)
        ? skin.withAccent(Color(override.toInt()))
        : skin;
  } catch (_) {
    // Any failure just means the default theme, which is fine.
  }
}

ThemeData buildTheme() {
  final light = Palette.skin.isLight;
  return ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: Palette.void_,
    colorScheme: (light ? const ColorScheme.light() : const ColorScheme.dark())
        .copyWith(
      surface: Palette.surface,
      primary: Palette.amber,
      onPrimary: light ? Colors.white : Palette.void_,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Palette.amber,
      selectionColor: Palette.amber.withValues(alpha: 0.25),
    ),
  );
}
