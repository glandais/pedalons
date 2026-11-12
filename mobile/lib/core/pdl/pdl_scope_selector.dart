import '../material.dart';

import '../theme/pdl_icons.dart';
import 'pdl_chip.dart';

/// B23 — La puce « Portée » : la seule forme du choix de portée d'une liste
/// (règle RL2 des listes, KIT §10) — au fil d'accueil, dans Explorer et au
/// calendrier global.
///
/// Elle **ne choisit rien elle-même** : elle dit la portée courante et
/// déclenche [onTap], à charge de l'écran d'ouvrir la feuille à coche (la liste
/// des portées est faite de DTO, que `core/pdl` ne connaît pas).
///
/// **Neutre au défaut, teintée hors du défaut** ([active]) : une portée qu'on
/// a écartée de son défaut restreint ce qu'on lit, et la puce le dit comme
/// toute puce de filtre posée. Le chevron annonce une feuille de choix ; le
/// contour `text` ([PdlChip.sortStyle]) la distingue des filtres qui
/// l'entourent quand elle est au repos.
class PdlScopeSelector extends StatelessWidget {
  const PdlScopeSelector({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
    this.icon = PdlIcons.teams,
    this.semanticLabel,
  });

  /// Portée courante, déjà traduite — « Membre », « Toutes mes équipes ».
  final String label;

  final VoidCallback? onTap;

  /// Vrai quand la portée s'écarte de son défaut : la puce se teinte.
  final bool active;
  final IconData icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: PdlChip(
      label: label,
      icon: icon,
      trailingIcon: PdlIcons.chevronDown,
      sortStyle: true,
      selected: active,
      onTap: onTap,
    ),
  );
}
