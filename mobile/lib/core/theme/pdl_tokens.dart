import 'package:flutter/material.dart';

import 'enum_colors.generated.dart';
import 'pdl_colors.dart';

/// Espacements de la charte (§1.1.7). Les valeurs sont en pixels logiques.
abstract final class PdlSpacing {
  /// `.sec` — marge de section, horizontale **et** verticale.
  static const double section = 16;

  /// `.sec--tight` — 12 vertical, 16 horizontal.
  static const double sectionTightV = 12;
  static const double sectionTightH = 16;

  /// Corps de carte.
  static const double card = 16;
  static const double cardTight = 12;

  /// Écart entre deux cartes de fil.
  static const double feedGap = 8;

  /// Écart entre deux cartes d'équipe.
  static const double teamCardGap = 12;

  /// Rangée de statistiques repliable — 4 vertical, 16 horizontal.
  static const double statsWrapV = 4;
  static const double statsWrapH = 16;

  /// Rangée de statistiques non repliable.
  static const double statsNowrap = 12;

  /// Rangée de chips.
  static const double chipGap = 8;

  /// Pile de badges.
  static const double badgeGap = 4;

  /// Chevauchement d'une grappe d'avatars.
  static const double avatarOverlap = -8;

  /// Grille méta à deux colonnes — 14 vertical, 16 horizontal.
  static const double meta2V = 14;
  static const double meta2H = 16;

  /// Largeur maximale d'une colonne de contenu bornée (tablette, écran 33).
  static const double contentMaxWidth = 600;
}

/// Rayons de la charte (§1.1.7).
abstract final class PdlRadii {
  /// Squelettes, info-bulle.
  static const Radius sm = Radius.circular(4);

  /// Boutons, champs, vignettes, bandeaux, segmenté, boutons de carte.
  static const Radius md = Radius.circular(8);

  /// Pastille active du segmenté.
  static const Radius segThumb = Radius.circular(6);

  /// Cartes **uniquement**.
  static const Radius card = Radius.circular(12);

  /// Feuilles modales — coins hauts.
  static const Radius lg = Radius.circular(16);

  /// Badges, chips, avatars, poignée, barre de places.
  static const Radius pill = Radius.circular(1000);

  /// Traits de rappel de couleur de tracé.
  static const Radius track = Radius.circular(2);

  static const BorderRadius smAll = BorderRadius.all(sm);
  static const BorderRadius mdAll = BorderRadius.all(md);
  static const BorderRadius segThumbAll = BorderRadius.all(segThumb);
  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius pillAll = BorderRadius.all(pill);
  static const BorderRadius trackAll = BorderRadius.all(track);

  /// Coins hauts d'une feuille modale.
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: lg,
    topRight: lg,
  );
}

/// Métriques fixes de la charte (§1.1.7).
///
/// `tabBottomInset` n'y figure pas : c'est le `MediaQuery.viewPadding.bottom`
/// réel de l'appareil, jamais une constante.
abstract final class PdlMetrics {
  static const double appBar = 56;
  static const double barAction = 44;
  static const double toolbarPadding = 10;
  static const double tabItem = 52;
  static const double actionBar = 44;

  /// Hauteur **visuelle** d'une chip. Sa cible tactile est [tapTarget].
  static const double chipVisual = 34;

  /// Cible tactile minimale du brief §5. Aucune action n'y déroge.
  static const double tapTarget = 44;

  static const double media = 160;
  static const double media16x9 = 208;
  static const double media120 = 120;

  static const double thumbLg = 80;
  static const double thumbMd = 64;
  static const double thumbSm = 56;

  /// Hauteurs de profil altimétrique : compact, écrans 12/24, écrans 13/25.
  static const double elevationCompact = 72;
  static const double elevationMedium = 110;
  static const double elevationLarge = 140;

  /// La bande sous un profil (le vent en mode Météo, ledger `MOB-106`) et
  /// son écart au graphique — les 6 px et 2 px du site (`windBand.ts`).
  static const double elevationBand = 6;
  static const double elevationBandGap = 2;

  /// Barre de places.
  static const double seatsBar = 6;

  /// Hauteur de la barre de segments (`PdlSegmentBar`) : vent le long du
  /// parcours, exposition au vent.
  static const double segmentBar = 8;

  /// Taille par défaut de la flèche de vent (`PdlWindArrow`).
  static const double windArrow = 18;

  /// Rail d'étapes collant.
  static const double stageRail = 64;
}

/// Durées et courbes (§1.1.7).
abstract final class PdlMotion {
  /// Boucle de scintillement des squelettes.
  static const Duration shimmer = Duration(milliseconds: 1400);
  static const Curve shimmerCurve = Curves.easeInOut;

  /// Sélection, bascule optimiste, ouverture de feuille.
  ///
  /// Non chiffré par les maquettes : valeur retenue par le plan §1.1.7.
  static const Duration stateChange = Duration(milliseconds: 180);
  static const Curve stateChangeCurve = Curves.easeOut;

  /// Recentrage de la caméra sur un point de parcours (ledger `MOB-84`).
  static const Duration mapFocus = Duration(milliseconds: 600);

  /// Flou des barres épinglées.
  static const double blurToolbar = 12;

  /// Flou des boutons posés sur une carte.
  static const double blurOverlayButton = 6;
}

/// Ombres de la charte (§1.1.7).
///
/// **En mode sombre l'ombre ne porte pas** : c'est la bordure `#424242` qui
/// sépare les surfaces (`docs/BRANDING.md` §5.2). [md] et [segThumb] rendent donc
/// une liste vide en sombre, et l'appelant pose une bordure à la place ;
/// seule [sheet] est conservée dans les deux modes.
abstract final class PdlShadows {
  static const List<BoxShadow> _md = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 10),
      blurRadius: 10,
      spreadRadius: -5,
    ),
  ];

  static const List<BoxShadow> _segThumb = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> sheet = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, -2), blurRadius: 16),
  ];

  static List<BoxShadow> md(Brightness brightness) =>
      brightness == Brightness.light ? _md : const <BoxShadow>[];

  static List<BoxShadow> segThumb(Brightness brightness) =>
      brightness == Brightness.light ? _segThumb : const <BoxShadow>[];
}

/// Dégradés de repli des bandeaux média (§1.1.5).
///
/// 135° en CSS, soit `topLeft → bottomRight`. **Identiques dans les deux
/// modes** : ils portent une icône blanche à 80 %. Les couleurs viennent de
/// `contracts/brand-colors.yaml` (`PdlFallbackGradients`, généré).
abstract final class PdlGradients {
  static const LinearGradient ride = PdlFallbackGradients.ride;
  static const LinearGradient post = PdlFallbackGradients.post;
  static const LinearGradient trip = PdlFallbackGradients.trip;
  static const LinearGradient team = PdlFallbackGradients.team;
  static const LinearGradient ad = PdlFallbackGradients.ad;

  /// Voile haut de carte : 150 px, `.90 → .55 à 45 % → 0`.
  static LinearGradient scrimTop(PdlColors c) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const <double>[0, 0.45, 1],
    colors: <Color>[
      c.scrim,
      c.scrim.withValues(alpha: 0.55),
      c.scrim.withValues(alpha: 0),
    ],
  );

  /// Voile bas de carte : 90 px, `.75 → 0`.
  static LinearGradient scrimBottom(PdlColors c) => LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[
      c.scrim.withValues(alpha: 0.75),
      c.scrim.withValues(alpha: 0),
    ],
  );
}

/// Palette ordonnée des tracés multiples (§1.1.5).
///
/// Indexée par `RideGroupDto.sortOrder` puis `TripStageDto.stageIndex`,
/// **modulo 10**, identique dans les deux modes. L'ordre est imposé : ne pas
/// le trier, ne pas le compléter.
const List<Color> kMultiTrackPalette = <Color>[
  Color(0xFF566B13),
  Color(0xFF1D32A8),
  Color(0xFF732C7B),
  Color(0xFFBDBD22),
  Color(0xFFC90808),
  Color(0xFFB81491),
  Color(0xFF628DE3),
  Color(0xFF6DCC5C),
  Color(0xFFC694D4),
  Color(0xFFE3A209),
];

/// Couleur du tracé d'indice [index] dans la palette multi-parcours.
Color multiTrackColor(int index) =>
    kMultiTrackPalette[index.remainder(kMultiTrackPalette.length).abs()];

/// Échelle de pente du tracé et du profil (BRANDING §3.7), celle du site
/// (`getColorFromGradient`, `frontend/src/components/map/mapUtils.ts`).
///
/// La teinte **descend** de 85 (vert) à 0 % jusqu'à −105 à 18 % et au-delà,
/// puis s'enroule (−105 → 255) : vert → jaune → orange → rouge → magenta,
/// jamais par le cyan ni le bleu, qui appartiennent au neutre. Elle est
/// arrondie au degré, comme au site. Une pente **nulle** — hors montée —
/// prend [slopeNeutral] ; une pente négative est bornée sur le vert.
Color slopeColor(double gradePercent) {
  if (gradePercent == 0) return slopeNeutral;
  final double t = (gradePercent / 18).clamp(0.0, 1.0);
  // `Math.round` du site : un demi-degré négatif s'arrondit vers le haut.
  int hue = (85 + (-105 - 85) * t + 0.5).floor();
  if (hue < 0) hue += 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.86, 0.62).toColor();
}

/// Couleur d'un tronçon hors montée, ou dont la pente est inconnue — le
/// `NEUTRAL_COLOR` du site. C'est aussi celle d'un tronçon sans vent connu en
/// mode « Météo » (ledger `MOB-105`).
final Color slopeNeutral = const HSLColor.fromAHSL(
  1,
  210,
  0.86,
  0.62,
).toColor();
