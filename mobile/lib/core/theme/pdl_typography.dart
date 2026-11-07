import 'package:flutter/material.dart';

import 'pdl_colors.dart';

/// Échelle typographique de la charte Pédalons (§1.1.6 du plan v2).
///
/// Famille `Inter`, aucune graisse au-delà de 700, capitales réservées aux
/// badges. Chaque rôle porte sa couleur par défaut : un widget qui pose une
/// couleur explicite le fait pour une raison nommée, pas par habitude.
///
/// Inter est embarquée dans l'application (`pubspec.yaml`, `assets/fonts/`) :
/// aucune police n'est téléchargée. La pile monospace passe par
/// [TextStyle.fontFamilyFallback] : quatre usages ne justifient pas d'embarquer
/// une seconde famille.
@immutable
class PdlTypography extends ThemeExtension<PdlTypography> {
  const PdlTypography({
    required this.screenTitle,
    required this.sectionTitle,
    required this.barTitle,
    required this.cardTitle,
    required this.wordmark,
    required this.body,
    required this.bodyStrong,
    required this.sub,
    required this.statValue,
    required this.statBigValue,
    required this.count,
    required this.xs,
    required this.tab,
    required this.tabActive,
    required this.badge,
    required this.badgeLg,
    required this.mono,
    required this.monoAxis,
    required this.button,
    required this.buttonSm,
    required this.textButton,
    required this.chip,
    required this.chipActive,
    required this.departureTime,
    required this.dayBoxWeekday,
    required this.dayBoxNumber,
    required this.dayBoxMonth,
    required this.departureLine,
    required this.departureLineLg,
    required this.dayPill,
  });

  /// Titre d'écran — 22/700, `letterSpacing −0.2`, sur `textBright`.
  final TextStyle screenTitle;

  /// Titre de section — 18/700, sur `textBright`.
  final TextStyle sectionTitle;

  /// Titre de barre supérieure — 17/700, une ligne + ellipsis.
  final TextStyle barTitle;

  /// Titre de carte — 16/700, une ligne + ellipsis.
  final TextStyle cardTitle;

  /// Logotype « Pédalons » de la barre d'accueil — 20/700 en `primary`.
  final TextStyle wordmark;

  /// Corps de texte — 15/400.
  final TextStyle body;

  /// Libellés actionnables et noms de personne — 15/600.
  final TextStyle bodyStrong;

  /// Sous-titre — 14/400 en `textDimmed`.
  final TextStyle sub;

  /// Valeur de statistique en ligne — 14/600.
  final TextStyle statValue;

  /// Valeur de statistique en colonne — 17/600.
  final TextStyle statBigValue;

  /// Compteur de liste, ligne d'équipe — 13/500 en `textDimmed`.
  final TextStyle count;

  /// Mention discrète — 12/400 en `textDimmed`.
  final TextStyle xs;

  /// Libellé d'onglet inactif — 10/500 en `textDimmed`.
  final TextStyle tab;

  /// Libellé d'onglet actif — 10/500 en `primary`.
  final TextStyle tabActive;

  /// Badge — 10/700, CAPS, `letterSpacing 0.25`. La couleur vient de la
  /// variante du badge, jamais du rôle.
  final TextStyle badge;

  /// Badge grande taille — 11/700, CAPS, `letterSpacing 0.25`.
  final TextStyle badgeLg;

  /// Monospace — 11/400.
  final TextStyle mono;

  /// Axe de profil altimétrique et info-bulle — 10/400 en `textPlaceholder`.
  final TextStyle monoAxis;

  /// Libellé de bouton — 15/600.
  final TextStyle button;

  /// Libellé de bouton compact — 14/600.
  final TextStyle buttonSm;

  /// Bouton textuel — 13/500 en `link`.
  final TextStyle textButton;

  /// Chip inactive — 14/500 en `textDimmed`.
  final TextStyle chip;

  /// Chip active — 14/600 en `primaryOnSoft`.
  final TextStyle chipActive;

  /// Heure de départ du bloc de départ — 22/700 sur `text` (BRANDING §7.8,
  /// ledger `BRAND-8` : l'heure de départ est en 700).
  final TextStyle departureTime;

  /// Jour de semaine de la boîte du jour — 12/600. La couleur vient du ton
  /// de la boîte.
  final TextStyle dayBoxWeekday;

  /// Chiffre du jour de la boîte du jour — 22/700 sur `text`.
  final TextStyle dayBoxNumber;

  /// Mois abrégé de la boîte du jour — 12/500. La couleur vient du ton.
  final TextStyle dayBoxMonth;

  /// « Départ 09:00 » de la ligne de départ d'une carte — 16/700 sur `text`
  /// (BRANDING §7.1, §7.8).
  final TextStyle departureLine;

  /// « Départ 09:30 » de la carte « Ma prochaine sortie » — 20/700 sur
  /// `text` (BRANDING §7.8).
  final TextStyle departureLineLg;

  /// Pastille « Aujourd'hui » / « Demain » posée sur l'image d'une carte —
  /// 12/700. La couleur vient de la pastille.
  final TextStyle dayPill;

  /// La famille déclarée dans `pubspec.yaml`.
  static const String family = 'Inter';

  static const List<String> monoFallback = <String>[
    'SFMono-Regular',
    'Menlo',
    'Roboto Mono',
    'monospace',
  ];

  /// Construit l'échelle pour une luminosité donnée.
  ///
  /// [base] porte la **famille** de police et rien d'autre : chaque rôle y
  /// superpose ses propres taille, graisse, interligne et couleur. Le thème
  /// (`PedalonsTheme.build`) y passe une `TextStyle` portant [family] ; la
  /// valeur par défaut est une `TextStyle` nue, ce que les tests de métriques
  /// n'ont pas besoin de changer.
  factory PdlTypography.of(Brightness brightness, {TextStyle? base}) {
    final PdlColors c = PdlColors.of(brightness);
    final TextStyle root = base ?? const TextStyle();
    TextStyle inter(
      double size,
      FontWeight weight, {
      Color? color,
      double? height,
      double? letterSpacing,
    }) => root.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

    // La pile mono ne passe PAS par [root] : c'est le seul rôle qui échappe à
    // Inter.
    TextStyle mono(double size, {Color? color, double? height, double? ls}) =>
        TextStyle(
          fontFamilyFallback: monoFallback,
          fontSize: size,
          fontWeight: FontWeight.w400,
          color: color,
          height: height,
          letterSpacing: ls,
        );

    return PdlTypography(
      screenTitle: inter(
        22,
        FontWeight.w700,
        color: c.textBright,
        height: 1.30,
        letterSpacing: -0.2,
      ),
      sectionTitle: inter(
        18,
        FontWeight.w700,
        color: c.textBright,
        height: 1.40,
      ),
      barTitle: inter(17, FontWeight.w700, color: c.text),
      cardTitle: inter(16, FontWeight.w700, color: c.text, height: 1.35),
      wordmark: inter(
        20,
        FontWeight.w700,
        color: c.primary,
        letterSpacing: -0.2,
      ),
      body: inter(15, FontWeight.w400, color: c.text, height: 1.55),
      bodyStrong: inter(15, FontWeight.w600, color: c.text),
      sub: inter(14, FontWeight.w400, color: c.textDimmed, height: 1.45),
      statValue: inter(14, FontWeight.w600, color: c.text),
      statBigValue: inter(17, FontWeight.w600, color: c.text),
      count: inter(13, FontWeight.w500, color: c.textDimmed),
      xs: inter(12, FontWeight.w400, color: c.textDimmed, height: 1.40),
      tab: inter(10, FontWeight.w500, color: c.textDimmed),
      tabActive: inter(10, FontWeight.w500, color: c.primary),
      badge: inter(10, FontWeight.w700, letterSpacing: 0.25),
      badgeLg: inter(11, FontWeight.w700, letterSpacing: 0.25),
      mono: mono(11, color: c.textDimmed, ls: -0.2),
      monoAxis: mono(10, color: c.textPlaceholder, height: 1.40),
      button: inter(15, FontWeight.w600),
      buttonSm: inter(14, FontWeight.w600),
      textButton: inter(13, FontWeight.w500, color: c.link),
      chip: inter(14, FontWeight.w500, color: c.textDimmed),
      chipActive: inter(14, FontWeight.w600, color: c.primaryOnSoft),
      departureTime: inter(22, FontWeight.w700, color: c.text, height: 1.25),
      dayBoxWeekday: inter(12, FontWeight.w600, height: 1.30),
      dayBoxNumber: inter(22, FontWeight.w700, color: c.text, height: 1.20),
      dayBoxMonth: inter(12, FontWeight.w500, height: 1.30),
      departureLine: inter(16, FontWeight.w700, color: c.text, height: 1.35),
      departureLineLg: inter(20, FontWeight.w700, color: c.text, height: 1.25),
      dayPill: inter(12, FontWeight.w700, height: 1.30),
    );
  }

  @override
  PdlTypography copyWith({
    TextStyle? screenTitle,
    TextStyle? sectionTitle,
    TextStyle? barTitle,
    TextStyle? cardTitle,
    TextStyle? wordmark,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? sub,
    TextStyle? statValue,
    TextStyle? statBigValue,
    TextStyle? count,
    TextStyle? xs,
    TextStyle? tab,
    TextStyle? tabActive,
    TextStyle? badge,
    TextStyle? badgeLg,
    TextStyle? mono,
    TextStyle? monoAxis,
    TextStyle? button,
    TextStyle? buttonSm,
    TextStyle? textButton,
    TextStyle? chip,
    TextStyle? chipActive,
    TextStyle? departureTime,
    TextStyle? dayBoxWeekday,
    TextStyle? dayBoxNumber,
    TextStyle? dayBoxMonth,
    TextStyle? departureLine,
    TextStyle? departureLineLg,
    TextStyle? dayPill,
  }) {
    return PdlTypography(
      screenTitle: screenTitle ?? this.screenTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      barTitle: barTitle ?? this.barTitle,
      cardTitle: cardTitle ?? this.cardTitle,
      wordmark: wordmark ?? this.wordmark,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      sub: sub ?? this.sub,
      statValue: statValue ?? this.statValue,
      statBigValue: statBigValue ?? this.statBigValue,
      count: count ?? this.count,
      xs: xs ?? this.xs,
      tab: tab ?? this.tab,
      tabActive: tabActive ?? this.tabActive,
      badge: badge ?? this.badge,
      badgeLg: badgeLg ?? this.badgeLg,
      mono: mono ?? this.mono,
      monoAxis: monoAxis ?? this.monoAxis,
      button: button ?? this.button,
      buttonSm: buttonSm ?? this.buttonSm,
      textButton: textButton ?? this.textButton,
      chip: chip ?? this.chip,
      chipActive: chipActive ?? this.chipActive,
      departureTime: departureTime ?? this.departureTime,
      dayBoxWeekday: dayBoxWeekday ?? this.dayBoxWeekday,
      dayBoxNumber: dayBoxNumber ?? this.dayBoxNumber,
      dayBoxMonth: dayBoxMonth ?? this.dayBoxMonth,
      departureLine: departureLine ?? this.departureLine,
      departureLineLg: departureLineLg ?? this.departureLineLg,
      dayPill: dayPill ?? this.dayPill,
    );
  }

  @override
  PdlTypography lerp(covariant ThemeExtension<PdlTypography>? other, double t) {
    if (other is! PdlTypography) return this;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return PdlTypography(
      screenTitle: s(screenTitle, other.screenTitle),
      sectionTitle: s(sectionTitle, other.sectionTitle),
      barTitle: s(barTitle, other.barTitle),
      cardTitle: s(cardTitle, other.cardTitle),
      wordmark: s(wordmark, other.wordmark),
      body: s(body, other.body),
      bodyStrong: s(bodyStrong, other.bodyStrong),
      sub: s(sub, other.sub),
      statValue: s(statValue, other.statValue),
      statBigValue: s(statBigValue, other.statBigValue),
      count: s(count, other.count),
      xs: s(xs, other.xs),
      tab: s(tab, other.tab),
      tabActive: s(tabActive, other.tabActive),
      badge: s(badge, other.badge),
      badgeLg: s(badgeLg, other.badgeLg),
      mono: s(mono, other.mono),
      monoAxis: s(monoAxis, other.monoAxis),
      button: s(button, other.button),
      buttonSm: s(buttonSm, other.buttonSm),
      textButton: s(textButton, other.textButton),
      chip: s(chip, other.chip),
      chipActive: s(chipActive, other.chipActive),
      departureTime: s(departureTime, other.departureTime),
      dayBoxWeekday: s(dayBoxWeekday, other.dayBoxWeekday),
      dayBoxNumber: s(dayBoxNumber, other.dayBoxNumber),
      dayBoxMonth: s(dayBoxMonth, other.dayBoxMonth),
      departureLine: s(departureLine, other.departureLine),
      departureLineLg: s(departureLineLg, other.departureLineLg),
      dayPill: s(dayPill, other.dayPill),
    );
  }
}

/// Accès court à l'échelle typographique : `context.pdlText.cardTitle`.
extension PdlTypographyContext on BuildContext {
  PdlTypography get pdlText =>
      Theme.of(this).extension<PdlTypography>() ??
      PdlTypography.of(Theme.of(this).brightness);
}
