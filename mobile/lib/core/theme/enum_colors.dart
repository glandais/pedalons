import 'package:flutter/widgets.dart';

import '../../api/generated/models/track_surface.dart';
import 'enum_colors.generated.dart';
import 'pdl_colors.dart';

export 'enum_colors.generated.dart';

/// La teinte d'un badge : un aplat, une paire douce, et la façon de la rendre.
///
/// Les badges de la charte sont **doux** par défaut — fond pâle, texte foncé
/// de la même famille. Une seule série fait exception, les catégories de col,
/// qui se rendent en **aplat** (`style: filled` dans le YAML) : d'où
/// [filledStyle] et [onFill].
///
/// [onFill] n'est pas décoratif : la famille jaune (`CAT3`) porte du
/// `#212529`, là où les autres portent du blanc. Sans ce champ, une catégorie
/// sur cinq serait illisible.
@immutable
class PdlTone {
  const PdlTone({
    required this.fill,
    required this.soft,
    required this.onSoft,
    this.onFill = const Color(0xFFFFFFFF),
    this.filledStyle = false,
  });

  /// L'aplat de la famille — trait de rappel, point, icône pleine.
  final Color fill;

  /// Le fond doux du badge.
  final Color soft;

  /// Le texte posé sur [soft].
  final Color onSoft;

  /// Le texte posé sur [fill], quand le badge est rendu en aplat.
  final Color onFill;

  /// Vrai quand le badge de cette famille se rend en aplat et non en doux.
  final bool filledStyle;

  /// Raccourci pour une famille rendue en doux : la paire vient du jeton, et
  /// [fill] est l'aplat correspondant.
  ///
  /// Publique parce que tous les badges ne sortent pas d'une énumération du
  /// contrat : « ✓ Inscrit » (famille indigo) et « Terminée » (famille grise
  /// foncée) sont des états dérivés côté client, sans champ d'API qui les
  /// porte.
  PdlTone.pair(PdlSoftPair pair, this.fill)
    : soft = pair.background,
      onSoft = pair.foreground,
      onFill = const Color(0xFFFFFFFF),
      filledStyle = false;
}

// ── Rendu des familles ──────────────────────────────────────────────────────

/// Comment le mobile rend chaque famille du code couleur métier.
///
/// Le choix de la famille d'une valeur d'énumération vient de
/// `contracts/brand-colors.yaml`, généré dans `enum_colors.generated.dart`
/// (`StatusTone`, `SurfaceTypeTone`…) ; seul le rendu est écrit ici. Une
/// famille ajoutée au YAML fait échouer ces `switch` tant qu'elle n'y est pas.
extension PdlFamilyTone on PdlFamily {
  /// Le fond doux de la famille, et son aplat en trait de rappel.
  PdlTone soft(PdlColors c) => switch (this) {
    PdlFamily.indigo => PdlTone.pair(c.softIndigo, c.accentIndigo),
    PdlFamily.blue => PdlTone.pair(c.softBlue, c.accentBlue),
    PdlFamily.green => PdlTone.pair(c.softGreen, c.success),
    PdlFamily.red => PdlTone.pair(c.softRed, c.danger),
    PdlFamily.yellow => PdlTone(
      fill: c.warning,
      soft: c.warningSoft,
      onSoft: c.warningOnSoft,
      onFill: c.neutralOnSoft,
    ),
    PdlFamily.orange => PdlTone.pair(c.softOrange, c.accentOrange),
    PdlFamily.grape => PdlTone.pair(c.softGrape, c.accentGrape),
    PdlFamily.teal => PdlTone.pair(c.softTeal, c.accentTeal),
    PdlFamily.gray => PdlTone.pair(c.softGray, c.neutral),
  };

  /// La même teinte, rendue en aplat (`filledStyle`).
  PdlTone filled(PdlColors c) {
    final PdlTone t = soft(c);
    return PdlTone(
      fill: t.fill,
      soft: t.soft,
      onSoft: t.onSoft,
      onFill: t.onFill,
      filledStyle: true,
    );
  }
}

// ── Tags d'équipe ───────────────────────────────────────────────────────────

/// La famille d'un tag d'équipe (`TagDto.color`, ledger `MOB-39`).
///
/// `TagColor` n'est pas une valeur métier de `contracts/brand-colors.yaml` :
/// ses neuf valeurs **sont** les neuf familles, en capitales au contrat. Il n'y
/// a donc pas de table à générer, seulement le nom à passer en minuscules. Une
/// valeur inconnue — une famille ajoutée côté serveur avant l'app — retombe sur
/// le gris plutôt que de faire disparaître le tag.
PdlFamily tagFamily(String color) {
  final String name = color.toLowerCase();
  for (final PdlFamily family in PdlFamily.values) {
    if (family.name == name) return family;
  }
  return PdlFamily.gray;
}

// ── États dérivés côté client ───────────────────────────────────────────────

/// Les familles de badge qu'aucune énumération du contrat ne porte.
///
/// « Inscrit » se déduit de `registered`, « Terminée » de `dateTime < now`
/// (§5.2-18 : le statut `TERMINÉE` n'existe pas dans l'enum `Status`),
/// « Supprimé » du booléen `deleted` — qui est un champ à part, et non une
/// valeur de `Status`. Les nommer ici évite qu'un écran ne recompose la paire
/// à la main — et donc qu'un écran se retrouve avec une autre teinte que son
/// voisin.
abstract final class PdlDerivedTones {
  /// `.b-ins` — indigo. Inscription à une sortie ou à un groupe.
  static PdlTone registered(PdlColors c) =>
      PdlTone.pair(c.softIndigo, c.primary);

  /// Vert doux, à pastille (`PdlBadge.dot`). Sortie ou voyage **en cours** :
  /// parti et pas encore rentré (`dateTime <= now < endDateTime`, ledger
  /// `API-85`) — « EN COURS » au web, même famille.
  static PdlTone underWay(PdlColors c) => PdlTone.pair(c.softGreen, c.success);

  /// `.b-done` — gris foncé. Sortie ou voyage terminé.
  static PdlTone done(PdlColors c) => PdlTone.pair(c.softDone, c.neutral);

  /// Rouge **en aplat**. Entité soft-deleted, que le backend ne renvoie qu'aux
  /// administrateurs de l'équipe.
  ///
  /// L'aplat n'est pas une coquetterie : `cancelled` occupe déjà le rouge doux
  /// et les deux badges peuvent coexister sur la même carte. Rendus tous deux
  /// en doux, ils seraient deux pastilles rouges qu'il faut lire pour les
  /// distinguer — l'aplat fait ressortir celui des deux qui prime.
  static PdlTone deleted(PdlColors c) => PdlTone(
    fill: c.danger,
    soft: c.softRed.background,
    onSoft: c.softRed.foreground,
    filledStyle: true,
  );
}

// ── Revêtement ──────────────────────────────────────────────────────────────

/// Le trait d'une classe de revêtement sur la carte et le profil (`MOB-81`) :
/// l'aplat de sa famille (`contracts/brand-colors.yaml`), et, pour les classes
/// grises, la nuance que le site prend dans `TRACK_SURFACE_SHADES` — asphalte
/// foncé, hors réseau moyen, inconnu pâle en clair ; l'inverse, lisible, sur
/// le fond sombre.
///
/// Une famille non grise prend l'aplat **du thème clair dans les deux
/// thèmes**, comme le site (nuances 6–7 en clair comme en sombre) : les aplats
/// de [PdlColors.dark] sont un cran plus foncés, faits pour porter du texte
/// blanc, et le violet du sentier y tombe sous 3:1 sur le fond de carte sombre
/// et la surface du profil.
extension TrackSurfaceStroke on TrackSurface {
  Color stroke(PdlColors c) {
    if (family != PdlFamily.gray) return family.soft(PdlColors.light).fill;
    return switch (this) {
      TrackSurface.paved => c.mapSurfacePaved,
      TrackSurface.offNetwork => c.mapSurfaceOffNetwork,
      _ => c.mapSurfaceUnknown,
    };
  }
}
