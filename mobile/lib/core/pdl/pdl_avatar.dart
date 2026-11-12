import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../widgets/authenticated_image.dart';

/// A4 — Avatar rond : photo authentifiée, sinon initiales sur un aplat.
///
/// **Teinte.** Elle est dérivée d'un hachage stable du nom sur les onze
/// teintes foncées de [PdlColors.avatarAccents] — deux personnes homonymes ont la même
/// couleur, la même personne garde la sienne d'un écran à l'autre. Le hachage
/// est calculé à la main sur les unités de code : `String.hashCode` n'est pas
/// garanti stable d'une exécution à l'autre, et un avatar qui change de couleur
/// au redémarrage détruit exactement la reconnaissance qu'on cherche.
///
/// **L'utilisateur courant est toujours `primary`.** C'est le seul repère qui
/// permette de se retrouver dans une grappe de trente avatars : passer
/// [isCurrentUser] à `true` court-circuite le hachage.
class PdlAvatar extends StatelessWidget {
  const PdlAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 32,
    this.isCurrentUser = false,
    this.initials,
    this.ring = false,
  });

  /// Nom affiché : source des initiales **et** du hachage de teinte.
  final String name;

  /// URL de la photo, éventuellement templatée `{size}`.
  final String? imageUrl;

  /// Diamètre. Les tailles de la charte sont 16 / 20 / 26 / 32 / 40 / 56 / 100.
  final double size;

  /// Force la teinte `primary`.
  final bool isCurrentUser;

  /// Initiales imposées, quand le nom affiché n'est pas celui qu'on veut
  /// abréger.
  final String? initials;

  /// Anneau 2 px `surface` — grappes d'avatars qui se chevauchent.
  final bool ring;

  /// Épaisseur de l'anneau, prise **sur** le diamètre et non autour.
  static const double _kRingWidth = 2;

  /// Corps de la police par taille (§1.2.1 : 8/10/10/12/14/19/34, graisse 700).
  ///
  /// Clés entières : une `Map<double, …>` constante est refusée par l'analyse,
  /// et les sept tailles de la charte sont entières de toute façon.
  static const Map<int, double> _fontSizes = <int, double>{
    16: 8,
    20: 10,
    26: 10,
    32: 12,
    40: 14,
    56: 19,
    100: 34,
  };

  /// Hachage stable, indépendant de `String.hashCode`.
  static int stableHash(String value) {
    int hash = 0;
    for (final int unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  /// La teinte d'un nom sur les onze accents ; l'indigo de
  /// [PdlColors.primary] n'y est pas, il est à la personne qui lit. Exposée pour que les composés
  /// (grappe d'avatars, ligne de personne) n'aient pas à la recalculer.
  static Color tintFor(PdlColors c, String name, {bool isCurrentUser = false}) {
    if (isCurrentUser) return c.primary;
    final List<Color> accents = c.avatarAccents;
    return accents[stableHash(name) % accents.length];
  }

  /// Deux initiales au plus, extraites des mots du nom.
  static String initialsOf(String name) {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    String take(String word) => word.characters.first.toUpperCase();
    if (words.length == 1) return take(words.first);
    return '${take(words.first)}${take(words[1])}';
  }

  /// Hors des sept tailles de la charte, le rapport moyen 0,35 tient : il
  /// encadre les sept valeurs publiées (0,34 à 0,5 pour la plus petite).
  double get _fontSize => _fontSizes[size.round()] ?? size * 0.35;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final Color tint = tintFor(c, name, isCurrentUser: isCurrentUser);

    final Widget fallback = Container(
      alignment: Alignment.center,
      color: tint,
      child: Text(
        initials ?? initialsOf(name),
        textAlign: TextAlign.center,
        // Le texte de l'avatar ne suit pas l'agrandissement typographique :
        // une initiale mise à l'échelle déborde d'un disque de 16 px.
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          color: c.onPrimary,
          height: 1,
        ),
      ),
    );

    // L'anneau est tracé **à l'intérieur** du diamètre : un `PdlAvatar` occupe
    // toujours `size × size`, avec ou sans anneau. Sinon un
    // `Border.all(width: 2)` posé autour porterait l'empreinte réelle à
    // `size + 4`, et tout appelant qui dimensionne à `size` — la grappe
    // d'avatars la première, qui pose ses disques dans un `Stack` clippé —
    // rognerait le disque à droite et l'aplatirait en haut et en bas.
    final double inner = ring ? size - _kRingWidth * 2 : size;

    final Widget disc = ClipOval(
      child: SizedBox(
        width: inner,
        height: inner,
        child: imageUrl == null
            ? fallback
            : AuthenticatedImage(
                imageUrl: imageUrl!,
                size: (inner * 3).round(),
                width: inner,
                height: inner,
                fit: BoxFit.cover,
                placeholder: fallback,
                errorWidget: fallback,
              ),
      ),
    );

    final Widget avatar = ring
        ? Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.surface, width: _kRingWidth),
            ),
            child: disc,
          )
        : disc;

    return Semantics(label: name, image: true, child: avatar);
  }
}
