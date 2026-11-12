import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/lists/list_scope.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../domain/route_filters.dart';
import 'route_filter_chips_bar.dart';

/// La barre d'outils de la parcothèque, épinglée sous l'app bar.
///
/// Elle porte, **dans cet ordre** (règles RL2, RL6 et RL13 des listes, KIT
/// §10) :
///
/// 1. la recherche, le bouton de filtres et, pour qui crée des parcours,
///    « Créer » — toujours ;
/// 2. la rangée de chips — vue liste seulement : la puce « Portée » en tête
///    dans Explorer, puis le tri, puis les critères.
///
/// Le contrôle de vue « Vignettes · Lignes · Carte » n'est plus dans la barre :
/// il est sur la ligne du compteur, sous elle (règle RL9).
///
/// En vue carte les chips disparaissent — le budget vertical d'une carte n'a
/// pas de place pour elles. Le compteur du [PdlFilterButton] est alors le seul
/// témoin qu'une carte vide l'est à cause des filtres : c'est
/// [RouteFilters.activeCount] qui le fournit, exactement ce que « Effacer les
/// filtres » lèverait.
class RoutesToolbar extends StatelessWidget {
  const RoutesToolbar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onOpenFilters,
    required this.listView,
    this.showScopeSelector = true,
    this.trailing,
  });

  final RouteFilters filters;
  final ValueChanged<RouteFilters> onChanged;
  final VoidCallback onOpenFilters;

  /// Vrai en vue liste (vignettes ou lignes) : la rangée de chips s'affiche.
  final bool listView;

  /// Faux quand l'écran impose déjà sa portée — la section Parcours d'une
  /// équipe, où changer d'équipe n'aurait pas de sens.
  final bool showScopeSelector;

  /// Un bouton à droite du filtre : « Créer » pour qui crée des parcours dans
  /// la section Parcours d'une équipe (ledger `MOB-79`, règle RL13).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PdlSearchField(
                  key: keys.routes.searchField,
                  value: filters.search,
                  hintText: 'routes.filters.searchPlaceholder'.tr(),
                  clearTooltip: 'common.clearSearch'.tr(),
                  onChanged: (String? value) =>
                      onChanged(filters.copyWith(search: value)),
                ),
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              PdlFilterButton(
                key: keys.routes.filterButton,
                onPressed: onOpenFilters,
                semanticLabel: 'routes.filters.title'.tr(),
                activeCount: filters.activeCount,
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                trailing!,
              ],
            ],
          ),
        ),
        if (listView) ...<Widget>[
          const SizedBox(height: 4),
          RouteFilterChipsBar(
            filters: filters,
            onChanged: onChanged,
            leading: showScopeSelector
                ? <Widget>[
                    // La portée d'Explorer : la même puce qu'au fil d'accueil,
                    // quatre rôles, plus de choix d'une équipe — la page de
                    // l'équipe montre ses parcours (règle RL2).
                    MembershipScopeChip(
                      key: keys.routes.scopeChip,
                      scope: filters.minRole,
                      defaultScope: filters.defaultMinRole,
                      onChanged: (value) =>
                          onChanged(filters.copyWith(minRole: value)),
                    ),
                  ]
                : const <Widget>[],
          ),
        ],
      ],
    );
  }
}
