import 'package:flutter/material.dart';

/// Jetons de couleur de rôle de la charte Pédalons.
///
/// Source de vérité : `docs/BRANDING.md` et `pedalons.css` (les
/// maquettes v2). Les valeurs claires sont toutes maquettées. Les valeurs
/// sombres publiées par `BRANDING.md` sont recopiées telles quelles ; celles qui
/// ne le sont pas — les fonds doux de badge, littéraux de `pedalons.css` —
/// sont **dérivées** par la règle suivante, seule justification des
/// hexadécimaux non maquettés de ce fichier :
///
/// ```
/// soft(sombre)    = nuance 9 de la famille Mantine × 0,5   (arrondi entier par canal)
/// on-soft(sombre) = nuance 0 de la famille Mantine
/// ```
///
/// Vérifiée sur les cinq paires que `BRANDING.md` publie :
/// `indigo-9 #364fc7 ×0,5 = #1b2864` · `green-9 #2b8a3e ×0,5 = #16451f` ·
/// `red-9 #c92a2a ×0,5 = #651515` · `gray-9 #212529 ×0,5 = #111315` ·
/// `yellow-9 #e67700 ×0,5 = #733c00` ; et les `on-soft` publiés (`#edf2ff`,
/// `#ebfbee`, `#fff5f5`, `#f8f9fa`, `#fff9db`) sont exactement les nuances 0.
///
/// Contrat : **aucun littéral de couleur hors de ce fichier**. Tout widget lit
/// ses couleurs par `context.pdl`.
@immutable
class PdlColors extends ThemeExtension<PdlColors> {
  const PdlColors({
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.border,
    required this.borderSubtle,
    required this.text,
    required this.textBright,
    required this.textDimmed,
    required this.textPlaceholder,
    required this.link,
    required this.overlay,
    required this.overlaySolid,
    required this.scrim,
    required this.sheetBarrier,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.primaryOnSoft,
    required this.onPrimary,
    required this.success,
    required this.successSoft,
    required this.successOnSoft,
    required this.warning,
    required this.warningSoft,
    required this.warningOnSoft,
    required this.danger,
    required this.dangerSoft,
    required this.dangerOnSoft,
    required this.neutral,
    required this.neutralSoft,
    required this.neutralOnSoft,
    required this.disabledBg,
    required this.disabledText,
    required this.disabledBorder,
    required this.accentBlue,
    required this.accentOrange,
    required this.accentGrape,
    required this.accentTeal,
    required this.accentViolet,
    required this.accentCyan,
    required this.accentLime,
    required this.accentPink,
    required this.blueSoft,
    required this.blueOnSoft,
    required this.grapeSoft,
    required this.grapeOnSoft,
    required this.tealSoft,
    required this.tealOnSoft,
    required this.orangeSoft,
    required this.orangeOnSoft,
    required this.doneSoft,
    required this.doneOnSoft,
    required this.mapTrack,
    required this.mapStart,
    required this.mapEnd,
    required this.mapWaypoint,
    required this.mapHillshadeShadow,
    required this.mapHillshadeHighlight,
    required this.mapArrow,
    required this.mapArrowRim,
  });

  // ── Surfaces, bordures, texte ──────────────────────────────────────────
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceRaised;
  final Color surfaceHover;
  final Color border;
  final Color borderSubtle;
  final Color text;

  /// Titres d'écran et de section : noir pur en clair, blanc pur en sombre,
  /// là où [text] reste à `#c9c9c9` en sombre.
  final Color textBright;
  final Color textDimmed;
  final Color textPlaceholder;
  final Color link;

  // ── Voiles ─────────────────────────────────────────────────────────────
  /// Barre d'onglets (90 %).
  final Color overlay;

  /// Barres d'outils et d'action, boutons de carte (95 %).
  final Color overlaySolid;

  /// Voile haut de carte — identique dans les deux modes.
  final Color scrim;

  /// `barrierColor` des feuilles modales — identique dans les deux modes.
  final Color sheetBarrier;

  // ── Rôles ──────────────────────────────────────────────────────────────
  final Color primary;
  final Color primaryHover;
  final Color primarySoft;
  final Color primaryOnSoft;
  final Color onPrimary;
  final Color success;
  final Color successSoft;
  final Color successOnSoft;
  final Color warning;
  final Color warningSoft;
  final Color warningOnSoft;
  final Color danger;
  final Color dangerSoft;
  final Color dangerOnSoft;
  final Color neutral;
  final Color neutralSoft;
  final Color neutralOnSoft;
  final Color disabledBg;
  final Color disabledText;
  final Color disabledBorder;

  // ── Accents ────────────────────────────────────────────────────────────
  final Color accentBlue;
  final Color accentOrange;
  final Color accentGrape;
  final Color accentTeal;
  final Color accentViolet;
  final Color accentCyan;
  final Color accentLime;
  final Color accentPink;

  // ── Paires douces de badge propres à une famille ───────────────────────
  // Les familles indigo, verte, rouge et grise sont exactement
  // primary/success/danger/neutral : elles sont exposées par les getters
  // [softIndigo], [softGreen], [softRed] et [softGray] plus bas.
  final Color blueSoft;
  final Color blueOnSoft;
  final Color grapeSoft;
  final Color grapeOnSoft;
  final Color tealSoft;
  final Color tealOnSoft;
  final Color orangeSoft;
  final Color orangeOnSoft;

  /// Gris foncé, réservé à « Terminée » (`.b-done`).
  final Color doneSoft;
  final Color doneOnSoft;

  // ── Carte ──────────────────────────────────────────────────────────────
  final Color mapTrack;
  final Color mapStart;
  final Color mapEnd;
  final Color mapWaypoint;

  /// Les deux teintes de l'ombrage du relief.
  ///
  /// Elles ne suivent **pas** le thème : l'ombrage se peint sur la tuile, pas
  /// sur la surface de l'app, et un fond de carte reste clair en thème sombre
  /// (seul `Plan` a une variante nocturne). Éclaircir l'ombre en sombre la
  /// ferait disparaître sur un satellite. Elles sont donc identiques dans les
  /// deux tables — inscrites ici quand même, parce qu'une couleur écrite
  /// ailleurs que dans `core/theme` est le défaut que la règle interdit.
  final Color mapHillshadeShadow;
  final Color mapHillshadeHighlight;

  /// Le chevron répété le long d'un tracé pour en montrer le sens, et son
  /// liseré. Comme l'ombrage, il ne suit pas le thème : il se peint sur le
  /// tracé, dont la couleur ne change pas, et un trait blanc cerné de sombre
  /// se lit sur toutes les teintes et tous les fonds (le site dessine le même,
  /// `frontend/src/components/map/RouteArrows.tsx`).
  final Color mapArrow;
  final Color mapArrowRim;

  /// Alias de [surface] : la charte nomme `--pdl-bg` le fond de page, qui vaut
  /// la surface dans les deux modes.
  Color get bg => surface;

  // ── Les 9 paires douces de badge (§1.1.4) ──────────────────────────────
  PdlSoftPair get softBlue => PdlSoftPair(blueSoft, blueOnSoft);
  PdlSoftPair get softGrape => PdlSoftPair(grapeSoft, grapeOnSoft);
  PdlSoftPair get softTeal => PdlSoftPair(tealSoft, tealOnSoft);
  PdlSoftPair get softOrange => PdlSoftPair(orangeSoft, orangeOnSoft);
  PdlSoftPair get softGreen => PdlSoftPair(successSoft, successOnSoft);
  PdlSoftPair get softGray => PdlSoftPair(neutralSoft, neutralOnSoft);
  PdlSoftPair get softDone => PdlSoftPair(doneSoft, doneOnSoft);
  PdlSoftPair get softRed => PdlSoftPair(dangerSoft, dangerOnSoft);
  PdlSoftPair get softIndigo => PdlSoftPair(primarySoft, primaryOnSoft);

  /// Les neuf paires, dans l'ordre du tableau §1.1.4.
  List<PdlSoftPair> get softPairs => <PdlSoftPair>[
    softBlue,
    softGrape,
    softTeal,
    softOrange,
    softGreen,
    softGray,
    softDone,
    softRed,
    softIndigo,
  ];

  /// Les douze accents servant à teinter un avatar par hachage de son nom.
  /// L'utilisateur courant n'y passe jamais : il est toujours [primary].
  List<Color> get avatarAccents => <Color>[
    accentBlue,
    accentTeal,
    accentGrape,
    accentLime,
    accentOrange,
    accentViolet,
    accentCyan,
    accentPink,
    success,
    warning,
    danger,
    primary,
  ];

  static const PdlColors light = PdlColors(
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF8F9FA),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF8F9FA),
    border: Color(0xFFCED4DA),
    borderSubtle: Color(0xFFDEE2E6),
    text: Color(0xFF000000),
    textBright: Color(0xFF000000),
    textDimmed: Color(0xFF868E96),
    textPlaceholder: Color(0xFFADB5BD),
    link: Color(0xFF228BE6),
    overlay: Color(0xE6FFFFFF),
    overlaySolid: Color(0xF2FFFFFF),
    scrim: Color(0xE6242424),
    sheetBarrier: Color(0x73242424),
    primary: Color(0xFF4C6EF5),
    primaryHover: Color(0xFF4263EB),
    primarySoft: Color(0xFFDBE4FF),
    primaryOnSoft: Color(0xFF364FC7),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF40C057),
    successSoft: Color(0xFFD3F9D8),
    successOnSoft: Color(0xFF2B8A3E),
    warning: Color(0xFFFAB005),
    warningSoft: Color(0xFFFFF3BF),
    warningOnSoft: Color(0xFFE67700),
    danger: Color(0xFFFA5252),
    dangerSoft: Color(0xFFFFE3E3),
    dangerOnSoft: Color(0xFFC92A2A),
    neutral: Color(0xFF868E96),
    neutralSoft: Color(0xFFF1F3F5),
    neutralOnSoft: Color(0xFF212529),
    disabledBg: Color(0xFFE9ECEF),
    disabledText: Color(0xFFADB5BD),
    disabledBorder: Color(0xFFCED4DA),
    accentBlue: Color(0xFF228BE6),
    accentOrange: Color(0xFFFD7E14),
    accentGrape: Color(0xFFBE4BDB),
    accentTeal: Color(0xFF12B886),
    accentViolet: Color(0xFF7950F2),
    accentCyan: Color(0xFF15AABF),
    accentLime: Color(0xFF82C91E),
    accentPink: Color(0xFFE64980),
    blueSoft: Color(0xFFD0EBFF),
    blueOnSoft: Color(0xFF1864AB),
    grapeSoft: Color(0xFFF3D9FA),
    grapeOnSoft: Color(0xFF862E9C),
    tealSoft: Color(0xFFC3FAE8),
    tealOnSoft: Color(0xFF087F5B),
    orangeSoft: Color(0xFFFFE8CC),
    orangeOnSoft: Color(0xFFD9480F),
    doneSoft: Color(0xFFE9ECEF),
    doneOnSoft: Color(0xFF495057),
    mapTrack: Color(0xFF228BE6),
    mapStart: Color(0xFF40C057),
    mapEnd: Color(0xFFFA5252),
    mapWaypoint: Color(0xFFFAB005),
    mapHillshadeShadow: Color(0xFF727C83),
    mapHillshadeHighlight: Color(0xFFFFFFE4),
    mapArrow: Color(0xFFFFFFFF),
    mapArrowRim: Color(0x8C000000),
  );

  static const PdlColors dark = PdlColors(
    surface: Color(0xFF242424),
    surfaceAlt: Color(0xFF2E2E2E),
    surfaceRaised: Color(0xFF2E2E2E),
    surfaceHover: Color(0xFF3B3B3B),
    border: Color(0xFF424242),
    borderSubtle: Color(0xFF2E2E2E),
    text: Color(0xFFC9C9C9),
    textBright: Color(0xFFFFFFFF),
    textDimmed: Color(0xFF828282),
    textPlaceholder: Color(0xFF696969),
    link: Color(0xFF4DABF7),
    overlay: Color(0xE6242424),
    overlaySolid: Color(0xF2242424),
    scrim: Color(0xE6242424),
    sheetBarrier: Color(0x73242424),
    primary: Color(0xFF3B5BDB),
    primaryHover: Color(0xFF364FC7),
    primarySoft: Color(0xFF1B2864),
    primaryOnSoft: Color(0xFFEDF2FF),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF2F9E44),
    successSoft: Color(0xFF16451F),
    successOnSoft: Color(0xFFEBFBEE),
    warning: Color(0xFFF08C00),
    warningSoft: Color(0xFF733C00),
    warningOnSoft: Color(0xFFFFF9DB),
    danger: Color(0xFFE03131),
    dangerSoft: Color(0xFF651515),
    dangerOnSoft: Color(0xFFFFF5F5),
    neutral: Color(0xFF343A40),
    neutralSoft: Color(0xFF111315),
    neutralOnSoft: Color(0xFFF8F9FA),
    disabledBg: Color(0xFF2E2E2E),
    disabledText: Color(0xFF696969),
    disabledBorder: Color(0xFF424242),
    accentBlue: Color(0xFF1971C2),
    accentOrange: Color(0xFFE8590C),
    accentGrape: Color(0xFF9C36B5),
    accentTeal: Color(0xFF099268),
    accentViolet: Color(0xFF6741D9),
    accentCyan: Color(0xFF0C8599),
    accentLime: Color(0xFF66A80F),
    accentPink: Color(0xFFC2255C),
    blueSoft: Color(0xFF0C3255),
    blueOnSoft: Color(0xFFE7F5FF),
    grapeSoft: Color(0xFF43174E),
    grapeOnSoft: Color(0xFFF8F0FC),
    tealSoft: Color(0xFF043F2D),
    tealOnSoft: Color(0xFFE6FCF5),
    orangeSoft: Color(0xFF6C2407),
    orangeOnSoft: Color(0xFFFFF4E6),
    doneSoft: Color(0xFF24282B),
    doneOnSoft: Color(0xFFF8F9FA),
    mapTrack: Color(0xFF4DABF7),
    mapStart: Color(0xFF40C057),
    mapEnd: Color(0xFFFA5252),
    mapWaypoint: Color(0xFFFAB005),
    mapHillshadeShadow: Color(0xFF727C83),
    mapHillshadeHighlight: Color(0xFFFFFFE4),
    mapArrow: Color(0xFFFFFFFF),
    mapArrowRim: Color(0x8C000000),
  );

  static PdlColors of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  @override
  PdlColors copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceRaised,
    Color? surfaceHover,
    Color? border,
    Color? borderSubtle,
    Color? text,
    Color? textBright,
    Color? textDimmed,
    Color? textPlaceholder,
    Color? link,
    Color? overlay,
    Color? overlaySolid,
    Color? scrim,
    Color? sheetBarrier,
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? primaryOnSoft,
    Color? onPrimary,
    Color? success,
    Color? successSoft,
    Color? successOnSoft,
    Color? warning,
    Color? warningSoft,
    Color? warningOnSoft,
    Color? danger,
    Color? dangerSoft,
    Color? dangerOnSoft,
    Color? neutral,
    Color? neutralSoft,
    Color? neutralOnSoft,
    Color? disabledBg,
    Color? disabledText,
    Color? disabledBorder,
    Color? accentBlue,
    Color? accentOrange,
    Color? accentGrape,
    Color? accentTeal,
    Color? accentViolet,
    Color? accentCyan,
    Color? accentLime,
    Color? accentPink,
    Color? blueSoft,
    Color? blueOnSoft,
    Color? grapeSoft,
    Color? grapeOnSoft,
    Color? tealSoft,
    Color? tealOnSoft,
    Color? orangeSoft,
    Color? orangeOnSoft,
    Color? doneSoft,
    Color? doneOnSoft,
    Color? mapTrack,
    Color? mapStart,
    Color? mapEnd,
    Color? mapWaypoint,
    Color? mapHillshadeShadow,
    Color? mapHillshadeHighlight,
    Color? mapArrow,
    Color? mapArrowRim,
  }) {
    return PdlColors(
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      text: text ?? this.text,
      textBright: textBright ?? this.textBright,
      textDimmed: textDimmed ?? this.textDimmed,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
      link: link ?? this.link,
      overlay: overlay ?? this.overlay,
      overlaySolid: overlaySolid ?? this.overlaySolid,
      scrim: scrim ?? this.scrim,
      sheetBarrier: sheetBarrier ?? this.sheetBarrier,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryOnSoft: primaryOnSoft ?? this.primaryOnSoft,
      onPrimary: onPrimary ?? this.onPrimary,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      successOnSoft: successOnSoft ?? this.successOnSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      warningOnSoft: warningOnSoft ?? this.warningOnSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerOnSoft: dangerOnSoft ?? this.dangerOnSoft,
      neutral: neutral ?? this.neutral,
      neutralSoft: neutralSoft ?? this.neutralSoft,
      neutralOnSoft: neutralOnSoft ?? this.neutralOnSoft,
      disabledBg: disabledBg ?? this.disabledBg,
      disabledText: disabledText ?? this.disabledText,
      disabledBorder: disabledBorder ?? this.disabledBorder,
      accentBlue: accentBlue ?? this.accentBlue,
      accentOrange: accentOrange ?? this.accentOrange,
      accentGrape: accentGrape ?? this.accentGrape,
      accentTeal: accentTeal ?? this.accentTeal,
      accentViolet: accentViolet ?? this.accentViolet,
      accentCyan: accentCyan ?? this.accentCyan,
      accentLime: accentLime ?? this.accentLime,
      accentPink: accentPink ?? this.accentPink,
      blueSoft: blueSoft ?? this.blueSoft,
      blueOnSoft: blueOnSoft ?? this.blueOnSoft,
      grapeSoft: grapeSoft ?? this.grapeSoft,
      grapeOnSoft: grapeOnSoft ?? this.grapeOnSoft,
      tealSoft: tealSoft ?? this.tealSoft,
      tealOnSoft: tealOnSoft ?? this.tealOnSoft,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      orangeOnSoft: orangeOnSoft ?? this.orangeOnSoft,
      doneSoft: doneSoft ?? this.doneSoft,
      doneOnSoft: doneOnSoft ?? this.doneOnSoft,
      mapTrack: mapTrack ?? this.mapTrack,
      mapStart: mapStart ?? this.mapStart,
      mapEnd: mapEnd ?? this.mapEnd,
      mapWaypoint: mapWaypoint ?? this.mapWaypoint,
      mapHillshadeShadow: mapHillshadeShadow ?? this.mapHillshadeShadow,
      mapHillshadeHighlight:
          mapHillshadeHighlight ?? this.mapHillshadeHighlight,
      mapArrow: mapArrow ?? this.mapArrow,
      mapArrowRim: mapArrowRim ?? this.mapArrowRim,
    );
  }

  @override
  PdlColors lerp(covariant ThemeExtension<PdlColors>? other, double t) {
    if (other is! PdlColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return PdlColors(
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      border: c(border, other.border),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      text: c(text, other.text),
      textBright: c(textBright, other.textBright),
      textDimmed: c(textDimmed, other.textDimmed),
      textPlaceholder: c(textPlaceholder, other.textPlaceholder),
      link: c(link, other.link),
      overlay: c(overlay, other.overlay),
      overlaySolid: c(overlaySolid, other.overlaySolid),
      scrim: c(scrim, other.scrim),
      sheetBarrier: c(sheetBarrier, other.sheetBarrier),
      primary: c(primary, other.primary),
      primaryHover: c(primaryHover, other.primaryHover),
      primarySoft: c(primarySoft, other.primarySoft),
      primaryOnSoft: c(primaryOnSoft, other.primaryOnSoft),
      onPrimary: c(onPrimary, other.onPrimary),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      successOnSoft: c(successOnSoft, other.successOnSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      warningOnSoft: c(warningOnSoft, other.warningOnSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      dangerOnSoft: c(dangerOnSoft, other.dangerOnSoft),
      neutral: c(neutral, other.neutral),
      neutralSoft: c(neutralSoft, other.neutralSoft),
      neutralOnSoft: c(neutralOnSoft, other.neutralOnSoft),
      disabledBg: c(disabledBg, other.disabledBg),
      disabledText: c(disabledText, other.disabledText),
      disabledBorder: c(disabledBorder, other.disabledBorder),
      accentBlue: c(accentBlue, other.accentBlue),
      accentOrange: c(accentOrange, other.accentOrange),
      accentGrape: c(accentGrape, other.accentGrape),
      accentTeal: c(accentTeal, other.accentTeal),
      accentViolet: c(accentViolet, other.accentViolet),
      accentCyan: c(accentCyan, other.accentCyan),
      accentLime: c(accentLime, other.accentLime),
      accentPink: c(accentPink, other.accentPink),
      blueSoft: c(blueSoft, other.blueSoft),
      blueOnSoft: c(blueOnSoft, other.blueOnSoft),
      grapeSoft: c(grapeSoft, other.grapeSoft),
      grapeOnSoft: c(grapeOnSoft, other.grapeOnSoft),
      tealSoft: c(tealSoft, other.tealSoft),
      tealOnSoft: c(tealOnSoft, other.tealOnSoft),
      orangeSoft: c(orangeSoft, other.orangeSoft),
      orangeOnSoft: c(orangeOnSoft, other.orangeOnSoft),
      doneSoft: c(doneSoft, other.doneSoft),
      doneOnSoft: c(doneOnSoft, other.doneOnSoft),
      mapTrack: c(mapTrack, other.mapTrack),
      mapStart: c(mapStart, other.mapStart),
      mapEnd: c(mapEnd, other.mapEnd),
      mapWaypoint: c(mapWaypoint, other.mapWaypoint),
      mapHillshadeShadow: c(mapHillshadeShadow, other.mapHillshadeShadow),
      mapHillshadeHighlight: c(
        mapHillshadeHighlight,
        other.mapHillshadeHighlight,
      ),
      mapArrow: c(mapArrow, other.mapArrow),
      mapArrowRim: c(mapArrowRim, other.mapArrowRim),
    );
  }
}

/// Une paire « fond doux / texte sur fond doux ».
@immutable
class PdlSoftPair {
  const PdlSoftPair(this.background, this.foreground);

  final Color background;
  final Color foreground;

  @override
  bool operator ==(Object other) =>
      other is PdlSoftPair &&
      other.background == background &&
      other.foreground == foreground;

  @override
  int get hashCode => Object.hash(background, foreground);
}

/// Accès court aux jetons de couleur : `context.pdl.primary`.
extension PdlColorsContext on BuildContext {
  PdlColors get pdl =>
      Theme.of(this).extension<PdlColors>() ??
      PdlColors.of(Theme.of(this).brightness);
}
