import 'package:flutter/widgets.dart';

import '../../theme/pdl_tokens.dart';

/// La hauteur qu'occupe le bas d'une carte, que la ligne du bas — l'échelle
/// (`PdlMapScaleBar`) et le crédit ⓘ (`PdlMapAttribution`) — doit enjamber
/// (ledger `docs/LEDGER_*.md MOB-129`).
///
/// L'échelle et le crédit sont des enfants de `MapLibreMap`, donc **sous**
/// toutes les couches que `PdlMapHero` empile : une carte flottante, un
/// interrupteur de mode ou une feuille posés en bas les recouvraient. Le hero
/// mesure ce qu'il pose en bas et publie ici la place prise ; la ligne du bas
/// se pose au-dessus.
///
/// [value] se compte **depuis le bord bas de la carte, zone sûre comprise** :
/// la ligne du bas prend le plus grand de [value] et de la zone sûre basse,
/// jamais leur somme (voir [safeArea]). Hors d'un hero — la carte d'une
/// annonce —, rien ne l'occupe : `0`.
class PdlMapBottomInset extends InheritedWidget {
  const PdlMapBottomInset({
    super.key,
    required this.value,
    required super.child,
  });

  /// La place occupée en bas, en pixels logiques.
  final double value;

  /// La marge autour de la ligne du bas : entre l'échelle ou le crédit et le
  /// bord de la carte (ou ce qui occupe le bas).
  static const double rowPadding = PdlSpacing.chipGap;

  /// La taille de l'icône ⓘ du crédit replié.
  static const double creditIconSize = 16;

  /// La marge intérieure du bouton ⓘ, autour de son icône.
  static const double creditTogglePadding = 6;

  /// La hauteur du crédit **replié** : son icône et sa marge intérieure (la
  /// bordure est peinte, elle ne prend pas de place). C'est ce que la colonne
  /// de boutons du hero enjambe ; déplié, le crédit s'étend vers le haut le
  /// temps de sa lecture.
  static const double creditExtent = creditIconSize + 2 * creditTogglePadding;

  /// La place occupée en bas de la carte qui encadre [context] ; `0` hors
  /// d'un hero.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PdlMapBottomInset>()?.value ??
      0;

  /// L'enveloppe commune de l'échelle et du crédit : la zone sûre, ou
  /// [PdlMapBottomInset.of] en bas s'il est plus grand, puis [padding].
  ///
  /// Le plus grand des deux et non leur somme : ce que le hero pose en bas en
  /// plein écran est déjà au-dessus de la zone sûre, et sa mesure la compte.
  static Widget safeArea(
    BuildContext context, {
    required EdgeInsets padding,
    required Widget child,
  }) => SafeArea(
    minimum: EdgeInsets.only(bottom: of(context)),
    child: Padding(padding: padding, child: child),
  );

  @override
  bool updateShouldNotify(PdlMapBottomInset oldWidget) =>
      oldWidget.value != value;
}
