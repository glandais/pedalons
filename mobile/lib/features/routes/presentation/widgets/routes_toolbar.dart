import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/route_filters.dart';
import 'route_filter_chips_bar.dart';

/// La barre d'outils de la parcothèque, épinglée sous l'app bar.
///
/// Elle porte, **dans cet ordre** :
///
/// 1. la recherche et le bouton de filtres — toujours ;
/// 2. le sélecteur de portée — vue Liste seulement ;
/// 3. le segmenté Liste / Carte — toujours ;
/// 4. la rangée de chips — vue Liste seulement.
///
/// **L'écart de maquette est assumé et documenté** (§3.1) : en vue Carte la
/// maquette retire la portée et les chips, et on la suit — le budget vertical
/// d'une carte n'a pas de place pour deux rangées. En échange, le compteur du
/// [PdlFilterButton] devient *obligatoire* : il est alors le seul témoin
/// qu'une carte vide l'est à cause des filtres et non du territoire. C'est
/// [RouteFilters.activeCount] qui le fournit, **portée comprise**.
class RoutesToolbar extends ConsumerWidget {
  const RoutesToolbar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onOpenFilters,
    required this.view,
    required this.onViewChanged,
    this.showScopeSelector = true,
    this.trailing,
  });

  final RouteFilters filters;
  final ValueChanged<RouteFilters> onChanged;
  final VoidCallback onOpenFilters;
  final RouteViewMode view;
  final ValueChanged<RouteViewMode> onViewChanged;

  /// Faux quand l'écran impose déjà sa portée — la section Parcours d'une
  /// équipe, où changer d'équipe n'aurait pas de sens.
  final bool showScopeSelector;

  /// Un bouton à droite du filtre : « Ajouter » pour un organisateur de la
  /// section Parcours d'une équipe (ledger `MOB-79`).
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool listView = view == RouteViewMode.list;

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
                  clearTooltip: 'common.cancel'.tr(),
                  onChanged: (String? value) =>
                      onChanged(filters.copyWith(search: value)),
                ),
              ),
              const SizedBox(width: 10),
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
        if (listView && showScopeSelector) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
            child: PdlScopeSelector(
              style: PdlScopeStyle.row,
              label: scopeLabel(context, ref, filters),
              semanticLabel: 'routes.scope.title'.tr(),
              onTap: () => _pickScope(context, ref),
            ),
          ),
        ],
        const SizedBox(height: PdlSpacing.chipGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: PdlSegmented<RouteViewMode>(
            value: view,
            onChanged: onViewChanged,
            segments: <PdlSegment<RouteViewMode>>[
              PdlSegment<RouteViewMode>(
                key: keys.routes.listViewSegment,
                value: RouteViewMode.list,
                label: 'routes.view.list'.tr(),
                icon: PdlIcons.list,
              ),
              PdlSegment<RouteViewMode>(
                key: keys.routes.mapViewSegment,
                value: RouteViewMode.map,
                label: 'routes.view.map'.tr(),
                icon: PdlIcons.map,
              ),
            ],
          ),
        ),
        if (listView) ...<Widget>[
          const SizedBox(height: 4),
          RouteFilterChipsBar(filters: filters, onChanged: onChanged),
        ],
      ],
    );
  }

  Future<void> _pickScope(BuildContext context, WidgetRef ref) async {
    final RouteFilters? next = await PdlSheet.show<RouteFilters>(
      context: context,
      builder: (BuildContext sheetContext) => _ScopeSheet(filters: filters),
    );
    if (next != null) onChanged(next);
  }
}

/// La portée courante en toutes lettres : « Toutes mes équipes »,
/// « N-Peloton », « Toutes mes équipes · Organisateur ».
String scopeLabel(BuildContext context, WidgetRef ref, RouteFilters filters) {
  final String? teamSlug = filters.teamSlug;
  final String base = teamSlug == null
      ? 'routes.scope.allTeams'.tr()
      : ref
                .watch(myTeamsProvider)
                .value
                ?.where((TeamDetailDto t) => t.slug == teamSlug)
                .firstOrNull
                ?.name ??
            teamSlug;
  if (filters.minRole == null) return base;
  return '$base · ${AppFormatters.roleName(filters.minRole!.json ?? '')}';
}

/// Le choix de portée : une équipe, ou toutes, plus un rôle minimum.
///
/// Le rôle minimum ne s'offre **que** pour « toutes mes équipes » : les
/// endpoints d'équipe n'acceptent pas `minRole`, et le proposer là produirait
/// un réglage sans effet — exactement ce que le brief §5 interdit.
class _ScopeSheet extends ConsumerWidget {
  const _ScopeSheet({required this.filters});

  final RouteFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final List<TeamDetailDto> teams =
        ref.watch(myTeamsProvider).value ?? const <TeamDetailDto>[];

    Widget check(bool selected) => selected
        ? Icon(PdlIcons.check, size: 20, color: c.primary)
        : const SizedBox.shrink();

    return PdlSheet(
      title: 'routes.scope.title'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        PdlSettingRow(
          title: 'routes.scope.allTeams'.tr(),
          trailing: check(filters.teamSlug == null),
          onTap: () =>
              Navigator.of(context).pop(filters.copyWith(teamSlug: null)),
        ),
        for (final TeamDetailDto team in teams)
          PdlSettingRow(
            title: team.name,
            trailing: check(filters.teamSlug == team.slug),
            // Choisir une équipe efface le rôle minimum : il ne partirait pas
            // à l'API, et le laisser affiché mentirait sur ce qui filtre.
            onTap: () =>
                Navigator.of(context)
                    .pop(filters.copyWith(teamSlug: team.slug, minRole: null)),
          ),
        if (filters.teamSlug == null) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlSectionHeader(title: 'routes.scope.minRole'.tr()),
          PdlSettingRow(
            title: 'routes.scope.anyRole'.tr(),
            trailing: check(filters.minRole == null),
            onTap: () =>
                Navigator.of(context).pop(filters.copyWith(minRole: null)),
          ),
          for (final MinRole role in MinRole.$valuesDefined)
            PdlSettingRow(
              title: AppFormatters.roleName(role.json ?? ''),
              trailing: check(filters.minRole == role),
              onTap: () =>
                  Navigator.of(context).pop(filters.copyWith(minRole: role)),
            ),
        ],
      ],
    );
  }
}
