import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_blur_surface.dart';

/// Une entrée de la barre d'onglets.
///
/// Le libellé arrive **déjà traduit** : `core/pdl` ne connaît aucune clé de
/// localisation.
@immutable
class PdlTabItem {
  const PdlTabItem({
    this.key,
    required this.icon,
    required this.label,
    IconData? activeIcon,
  }) : activeIcon = activeIcon ?? icon;

  /// Posée sur l'entrée rendue — c'est elle que trouve un test de bout en bout.
  final Key? key;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// C2 — La barre d'onglets, et il n'y en a qu'une.
///
/// **Cinq entrées racine fixes, aucune variante d'équipe** (§1.0.3-6). La
/// seconde `NavigationBar` d'équipe est supprimée : c'était la cause directe
/// des feuilles rendues *sous* la barre et de la superposition d'états
/// d'erreur. Les sections d'une équipe sont devenues du contenu — une
/// [PdlChipRow] collante — et n'ont plus rien à faire ici.
///
/// Deux points de rendu comptent :
///
/// * **L'inset système est le vrai.** `MediaQuery.viewPadding.bottom` et
///   jamais la constante de 22 px de la maquette : sur un iPhone à barre
///   d'accueil il vaut 34, et 22 fait passer les libellés sous le trait.
///   `viewPadding` et non `padding` : la seconde tombe à zéro dès qu'un
///   clavier est ouvert, la barre sauterait.
/// * **La hauteur de 52 px est un minimum, pas un plafond.** À 130 %
///   d'agrandissement typographique un `SizedBox(height: 52)` rogne le
///   libellé — c'est-à-dire la seule chose qui dit où l'on est. L'entrée
///   prend donc la hauteur de son contenu, avec 52 pour plancher.
class PdlBottomTabs extends StatelessWidget {
  const PdlBottomTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PdlTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final double inset = MediaQuery.viewPaddingOf(context).bottom;

    return PdlBlurSurface(
      color: c.overlay,
      sigma: PdlMotion.blurToolbar,
      border: Border(top: BorderSide(color: c.borderSubtle)),
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Row(
          // Pas de `stretch` : la barre est posée dans une boîte de hauteur
          // libre (`bottomNavigationBar`), s'étirer y demanderait une hauteur
          // infinie. Les cinq entrées ont de toute façon le même contenu, donc
          // la même hauteur.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: _PdlTab(
                  key: items[i].key,
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PdlTab extends StatelessWidget {
  const _PdlTab({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PdlTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PdlMetrics.tabItem),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 20,
                  color: selected ? c.primary : c.textDimmed,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: selected ? t.tabActive : t.tab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
