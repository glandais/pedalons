import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../teams/providers/team_providers.dart';
import '../../providers/calendar_month_provider.dart';

/// Au-delà de ce nombre d'équipes, la rangée de chips devient illisible et
/// c'est le sélecteur de portée qui prend le relais. En deçà, une chip par
/// équipe est plus rapide qu'une feuille à ouvrir.
const int kCalendarTeamChipsMax = 3;

/// La barre d'outils du calendrier : le mois, la portée, les filtres.
///
/// **Sémantique des chips**, que la maquette ne dit pas et que le plan tranche
/// (§3.2) : le **type** est exclusif (Tout | Sorties | Voyages), l'**équipe**
/// est exclusive (Toutes mes équipes | une équipe), et les deux groupes se
/// combinent. Un filet vertical les sépare, parce que deux exclusivités côte à
/// côte sans séparation se lisent comme une seule.
///
/// La chip d'équipe **change d'endpoint** : elle ne filtre pas une liste déjà
/// chargée, elle en demande une autre. La chip de type, elle, ne coûte aucun
/// appel — le mois entier est en mémoire.
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
    final bool chipsFitTeams =
        showScope && teams.length <= kCalendarTeamChipsMax;

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
        // Au-delà de trois équipes, la portée passe par le sélecteur : une
        // rangée de dix chips d'équipe ne se lit pas. En deçà, les chips
        // ci-dessous suffisent et le sélecteur ferait doublon.
        if (showScope && !chipsFitTeams) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
            child: PdlScopeSelector(
              style: PdlScopeStyle.row,
              label: _scopeLabel(teams),
              semanticLabel: 'calendar.scope'.tr(),
              onTap: () => _pickScope(context, teams),
            ),
          ),
        ],
        const SizedBox(height: 4),
        PdlChipRow(
          children: <Widget>[
            for (final CalendarTypeFilter type in typeOptions)
              PdlChip(
                label: _typeLabel(type),
                icon: _typeIcon(type),
                selected: typeFilter == type,
                onTap: () => onTypeChanged(type),
              ),
            if (chipsFitTeams && teams.isNotEmpty) ...<Widget>[
              _ChipDivider(color: c.borderSubtle),
              PdlChip(
                label: 'calendar.allMyTeams'.tr(),
                selected: monthKey.teamSlug == null,
                onTap: () => onMonthChanged(
                  CalendarMonthKey(year: monthKey.year, month: monthKey.month),
                ),
              ),
              for (final TeamDetailDto team in teams)
                PdlChip(
                  label: team.name,
                  selected: monthKey.teamSlug == team.slug,
                  onTap: () => onMonthChanged(
                    CalendarMonthKey(
                      year: monthKey.year,
                      month: monthKey.month,
                      teamSlug: team.slug,
                    ),
                  ),
                ),
            ],
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
    final Object? picked = await PdlSheet.show<Object>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title: 'calendar.scope'.tr(),
        bodyPadding: EdgeInsets.zero,
        footer: const SafeArea(top: false, child: SizedBox(height: 8)),
        children: <Widget>[
          PdlSettingRow(
            title: 'calendar.allMyTeams'.tr(),
            trailing: _check(sheetContext, monthKey.teamSlug == null),
            onTap: () => Navigator.of(sheetContext).pop(_kAllTeams),
          ),
          for (final TeamDetailDto team in teams)
            PdlSettingRow(
              title: team.name,
              trailing: _check(sheetContext, monthKey.teamSlug == team.slug),
              onTap: () => Navigator.of(sheetContext).pop(team.slug),
            ),
        ],
      ),
    );
    if (picked == null) return;
    onMonthChanged(
      CalendarMonthKey(
        year: monthKey.year,
        month: monthKey.month,
        teamSlug: picked == _kAllTeams ? null : picked as String,
      ),
    );
  }

  static Widget _check(BuildContext context, bool selected) => selected
      ? Icon(PdlIcons.check, size: 20, color: context.pdl.primary)
      : const SizedBox.shrink();
}

/// Sentinelle : « toutes mes équipes » n'est pas un slug, et rendre `null`
/// depuis une feuille se confondrait avec un abandon.
const Object _kAllTeams = Object();

/// Le filet vertical qui sépare les deux exclusivités de la rangée.
class _ChipDivider extends StatelessWidget {
  const _ChipDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: PdlMetrics.tapTarget,
    child: Center(child: Container(width: 1, height: 20, color: color)),
  );
}
