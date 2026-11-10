import 'package:flutter/material.dart';

import '../pdl/pdl.dart';
import '../theme/pdl_tokens.dart';

/// Le rang d'un titre dans un écran de détail.
enum DetailSectionLevel {
  /// Titre de section (h2 des maquettes : « Parcours », « Groupes ») —
  /// [PdlSpacing.detailSectionGap] au-dessus.
  section,

  /// Sous-titre (h3 : « Météo au départ de 09:00 », « Exposition au vent ») —
  /// [PdlSpacing.detailSubsectionGap] au-dessus.
  subsection,
}

/// Le rythme des sections des écrans de détail (ledger `MOB-134`, KIT §8) :
/// l'espace au-dessus du titre, le titre ([PdlSectionHeader], compte à droite
/// en 12 gris : « 3 groupes », « 2 commentaires », « 8/12 »), puis [child].
///
/// Le titre garde la marge latérale de l'écran ([PdlSpacing.section]) ;
/// [child] aussi, sauf avec [bleed] — une carte pleine largeur. Sans [child],
/// seul le titre est posé : l'appelant met sa liste dans le sliver suivant.
///
/// [DetailSection.sliver] donne la même chose dans un `CustomScrollView`.
class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    required this.title,
    this.count,
    this.action,
    this.child,
    this.level = DetailSectionLevel.section,
    this.bleed = false,
  });

  /// La même section, posée dans un `SliverToBoxAdapter`.
  static Widget sliver({
    Key? key,
    required String title,
    String? count,
    Widget? action,
    Widget? child,
    DetailSectionLevel level = DetailSectionLevel.section,
    bool bleed = false,
  }) => SliverToBoxAdapter(
    key: key,
    child: DetailSection(
      title: title,
      count: count,
      action: action,
      level: level,
      bleed: bleed,
      child: child,
    ),
  );

  final String title;

  /// Déjà formaté et accordé par l'appelant.
  final String? count;

  final Widget? action;
  final Widget? child;
  final DetailSectionLevel level;

  /// [child] occupe toute la largeur, sans la marge latérale.
  final bool bleed;

  /// L'espace au-dessus d'un titre de ce rang.
  static double gapAbove(DetailSectionLevel level) => switch (level) {
    DetailSectionLevel.section => PdlSpacing.detailSectionGap,
    DetailSectionLevel.subsection => PdlSpacing.detailSubsectionGap,
  };

  @override
  Widget build(BuildContext context) {
    const EdgeInsets side = EdgeInsets.symmetric(
      horizontal: PdlSpacing.section,
    );
    final Widget header = Semantics(
      header: true,
      child: PdlSectionHeader(
        title: title,
        count: count,
        action: action,
        countAtEnd: true,
        subsection: level == DetailSectionLevel.subsection,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: gapAbove(level)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(padding: side, child: header),
          if (child != null)
            bleed ? child! : Padding(padding: side, child: child),
        ],
      ),
    );
  }
}
