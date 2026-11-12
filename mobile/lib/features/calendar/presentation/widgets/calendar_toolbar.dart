import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/lists/list_scope.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../teams/providers/team_providers.dart';
import '../../providers/calendar_month_provider.dart';

/// La barre d'outils du calendrier : le mois, la portée, les filtres.
///
/// **La portée est la puce « Portée »** de toutes les listes (règle RL2 des
/// listes, KIT §10) — en tête de la rangée, neutre sur « Toutes mes équipes »,
/// teintée sur une équipe — et sa feuille à coche liste « Toutes mes équipes /
/// {équipe}… ». C'est la seule liste où l'on choisit une équipe : le
/// calendrier global n'a pas de page par équipe. Elle remplace la rangée de
/// puces d'équipe, coupée dès trois équipes (« Toutes m… »).
///
/// Le **type** est exclusif (Tout | Sorties | Voyages) et se combine avec la
/// portée. La portée **change d'endpoint** : elle ne filtre pas une liste déjà
/// chargée, elle en demande une autre. Le type, lui, ne coûte aucun appel — le
/// mois entier est en mémoire.
class CalendarToolbar extends ConsumerWidget {
  const CalendarToolbar({
    super.key,
    required this.monthKey,
    required this.onMonthChanged,
    required this.typeFilter,
    required this.onTypeChanged,
    this.showScope = true,
    this.onToday,
    this.typeOptions = CalendarTypeFilter.values,
  });

  final CalendarMonthKey monthKey;
  final ValueChanged<CalendarMonthKey> onMonthChanged;
  final CalendarTypeFilter typeFilter;
  final ValueChanged<CalendarTypeFilter> onTypeChanged;

  /// Faux dans la section Calendrier d'une équipe : la portée y est figée.
  final bool showScope;

  /// « Aujourd'hui ». Fourni **quand la page n'a pas d'app bar à elle** — la
  /// section d'équipe —, pour que le raccourci n'y disparaisse pas.
  final VoidCallback? onToday;

  /// Les types proposés en chips. Tous au calendrier global ; dans celui
  /// d'une équipe, seulement ceux de ses modules (`agendaTypeOptions`
  /// de l'Agenda, comme au site).
  final List<CalendarTypeFilter> typeOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final List<TeamDetailDto> teams =
        ref.watch(myTeamsProvider).value ?? const <TeamDetailDto>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            PdlAppBarAction(
              icon: PdlIcons.chevronLeft,
              semanticLabel: 'calendar.previousMonth'.tr(),
              onPressed: () => onMonthChanged(monthKey.shifted(-1)),
            ),
            Expanded(
              child: Text(
                AppFormatters.formatMonthYear(monthKey.start),
                textAlign: TextAlign.center,
                style: t.sectionTitle.copyWith(color: c.textBright),
              ),
            ),
            PdlAppBarAction(
              key: keys.calendar.nextMonthButton,
              icon: PdlIcons.chevronRight,
              semanticLabel: 'calendar.nextMonth'.tr(),
              onPressed: () => onMonthChanged(monthKey.shifted(1)),
            ),
            if (onToday != null) ...<Widget>[
              const SizedBox(width: 4),
              PdlButton(
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                pill: true,
                label: 'calendar.today'.tr(),
                onPressed: onToday,
              ),
              const SizedBox(width: PdlSpacing.chipGap),
            ],
          ],
        ),
        const SizedBox(height: 4),
        PdlChipRow(
          children: <Widget>[
            if (showScope)
              PdlScopeSelector(
                key: keys.calendar.scopeChip,
                label: _scopeLabel(teams),
                active: monthKey.teamSlug != null,
                semanticLabel: 'lists.scope.title'.tr(),
                onTap: () => _pickScope(context, teams),
              ),
            for (final CalendarTypeFilter type in typeOptions)
              PdlChip(
                label: _typeLabel(type),
                icon: _typeIcon(type),
                selected: typeFilter == type,
                onTap: () => onTypeChanged(type),
              ),
          ],
        ),
      ],
    );
  }

  String _scopeLabel(List<TeamDetailDto> teams) {
    final String? slug = monthKey.teamSlug;
    if (slug == null) return 'calendar.allMyTeams'.tr();
    return teams.where((TeamDetailDto t) => t.slug == slug).firstOrNull?.name ??
        slug;
  }

  static String _typeLabel(CalendarTypeFilter type) => switch (type) {
    CalendarTypeFilter.all => 'calendar.filters.all'.tr(),
    CalendarTypeFilter.rides => 'calendar.filters.rides'.tr(),
    CalendarTypeFilter.trips => 'calendar.filters.trips'.tr(),
  };

  static IconData? _typeIcon(CalendarTypeFilter type) => switch (type) {
    CalendarTypeFilter.all => null,
    CalendarTypeFilter.rides => PdlIcons.ride,
    CalendarTypeFilter.trips => PdlIcons.trip,
  };

  Future<void> _pickScope(
    BuildContext context,
    List<TeamDetailDto> teams,
  ) async {
    final List<String?> slugs = <String?>[
      null,
      for (final TeamDetailDto team in teams) team.slug,
    ];
    final int? picked = await showCheckSheet<String?>(
      context,
      title: 'lists.scope.title'.tr(),
      selected: monthKey.teamSlug,
      options: <CheckOption<String?>>[
        (value: null, label: 'calendar.allMyTeams'.tr()),
        for (final TeamDetailDto team in teams)
          (value: team.slug, label: team.name),
      ],
    );
    if (picked == null) return;
    onMonthChanged(
      CalendarMonthKey(
        year: monthKey.year,
        month: monthKey.month,
        teamSlug: slugs[picked],
      ),
    );
  }
}
