import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// C5 — La feuille modale, et la seule manière d'en ouvrir une.
///
/// **`showModalBottomSheet` ne s'appelle plus directement.** La règle de revue :
///
/// ```bash
/// grep -rn --include='*.dart' "showModalBottomSheet" mobile/lib   # seul pdl_sheet.dart
/// ```
///
/// Elle corrige deux défauts d'un coup, et les deux venaient d'un drapeau
/// oublié :
///
/// * **F-DE-8 — la feuille rendue sous la barre d'onglets.** Sans
///   `useRootNavigator: true`, la feuille s'ouvre dans le navigateur de la
///   branche, c'est-à-dire *à l'intérieur* de la coquille : la barre d'onglets
///   lui passe devant. [show] force le drapeau, il n'est pas paramétrable.
/// * **Le « Trier par » écrasé à 1 pt.** Sans `isScrollControlled: true`, une
///   `Column` à `Expanded` dans une feuille de hauteur non bornée s'effondre.
///   Le gabarit ci-dessous — en-tête fixe, corps défilant borné, pied fixe —
///   est le seul autorisé, et il ne peut pas s'effondrer : le corps est
///   [Flexible] dans une colonne `min`, il prend la place qu'il a et pas plus.
///
/// Et elle tient le clavier, que `showModalBottomSheet` ne gère pas : la
/// feuille remonte au-dessus de lui — sans quoi le pied, donc « Envoyer »,
/// restait caché dessous — et un appui hors d'un champ le referme, puisque
/// la touche retour d'un champ multiligne insère une ligne au lieu de le
/// fermer.
class PdlSheet extends StatelessWidget {
  const PdlSheet({
    super.key,
    this.title,
    this.header,
    this.headerAction,
    this.children,
    this.body,
    this.footer,
    this.showHandle = true,
    this.maxHeightFraction = 0.9,
    this.bodyPadding = const EdgeInsets.only(bottom: PdlSpacing.section),
  }) : assert(
         children == null || body == null,
         'Une feuille a un corps de liste (children) ou un corps libre (body), '
         'pas les deux.',
       );

  /// Titre 18/700. Ignoré si [header] est fourni.
  final String? title;

  /// En-tête libre — un segmenté, un champ de recherche.
  final Widget? header;

  /// Action de droite de l'en-tête : une croix, un « Effacer ».
  final Widget? headerAction;

  /// Corps défilant, en liste.
  final List<Widget>? children;

  /// Corps défilant libre. **Doit défiler lui-même** : il est posé dans un
  /// [Flexible], pas dans un défileur.
  final Widget? body;

  /// Pied fixe : la ou les actions de validation.
  final Widget? footer;

  final bool showHandle;

  /// Plafond de hauteur, en fraction de la hauteur disponible.
  final double maxHeightFraction;

  final EdgeInsetsGeometry bodyPadding;

  /// Ouvre une feuille. **Les quatre drapeaux ci-dessous ne se négocient pas.**
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    final PdlColors c = context.pdl;
    return showModalBottomSheet<T>(
      context: context,
      // Au-dessus de la coquille, donc au-dessus de la barre d'onglets.
      useRootNavigator: true,
      // Sans quoi la feuille est plafonnée à la moitié de l'écran et son
      // contenu s'écrase.
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: c.sheetBarrier,
      // La feuille peint sa propre surface : coins hauts, ombre, bordure.
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double maxHeight =
        (MediaQuery.sizeOf(context).height - keyboard) * maxHeightFraction;

    Widget? headerChild = header;
    if (headerChild == null && title != null) {
      headerChild = Text(title!, style: t.sectionTitle);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: GestureDetector(
        // Les boutons et les champs gagnent l'appui : seul un appui dans le
        // vide referme le clavier.
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Align(
          alignment: Alignment.bottomCenter,
          // La hauteur de la feuille, pas celle de l'écran : sans ce facteur,
          // l'`Align` prenait toute la place que la route lui offre, et la
          // feuille — transparente au-dessus de sa surface — couvrait la
          // barrière. Un appui hors de la feuille ne faisait alors que fermer
          // le clavier, au lieu de la refermer.
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: PdlSpacing.contentMaxWidth,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: PdlRadii.sheetTop,
                border: Border(top: BorderSide(color: c.borderSubtle)),
                boxShadow: PdlShadows.sheet,
              ),
              // La surface est un `Material` et non une simple couleur de
              // décoration : `ListTile`, `InkWell` et compagnie peignent leur
              // fond et leur onde d'appui sur le `Material` le plus proche. Avec
              // un `DecoratedBox` coloré au-dessus, l'onde était peinte puis
              // recouverte — un appui sans le moindre retour visuel.
              child: Material(
                type: MaterialType.card,
                color: c.surfaceRaised,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                borderRadius: PdlRadii.sheetTop,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (showHandle) const PdlSheetHandle(),
                    if (headerChild != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PdlSpacing.section,
                          PdlSpacing.sectionTightV,
                          PdlSpacing.section,
                          PdlSpacing.sectionTightV,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: headerChild),
                            ?headerAction,
                          ],
                        ),
                      ),
                    if (children != null)
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: bodyPadding,
                          children: children!,
                        ),
                      )
                    else if (body != null)
                      Flexible(child: body!),
                    ?footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La poignée de préhension : 36 × 4, `border`, marge `8 auto 4`.
///
/// Elle est dessinée ici et non par `showDragHandle` : la poignée Material
/// mesure 32 × 4 dans une boîte de 24 px de haut et se colore en
/// `onSurfaceVariant`, deux valeurs qui ne sont pas les nôtres.
class PdlSheetHandle extends StatelessWidget {
  const PdlSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        decoration: BoxDecoration(
          color: c.border,
          borderRadius: PdlRadii.pillAll,
        ),
      ),
    );
  }
}
