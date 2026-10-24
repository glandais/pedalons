import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../../calendar/presentation/pages/calendar_page.dart';
import '../../../calendar/providers/calendar_month_provider.dart';
import '../../../feed/presentation/widgets/publication_feed_view.dart';
import '../widgets/team_header.dart';
import '../widgets/team_sections.dart';
import '../widgets/team_sections_bar.dart';

/// Le cadre d'une section d'équipe : l'en-tête fixe ([header], quand le corps
/// a son propre défileur) ou aucun (quand le corps est une liste de slivers
/// qui porte l'en-tête interpolé). Fourni par `TeamHomePage`.
typedef TeamChromeBuilder =
    Widget Function({required Widget? header, required Widget body});

/// Les types de l'Agenda : ses sorties et ses voyages, jamais ses
/// publications (plan `2026-10-06-team-agenda.md` §2).
const List<PublicationType?> kAgendaTypeOptions = <PublicationType?>[
  null,
  PublicationType.ride,
  PublicationType.trip,
];

/// L'Agenda d'une équipe : ses sorties et ses voyages (ledger `MOB-60`).
///
/// **La période** : « À venir » (par défaut), « Je participe », « Passées » —
/// `when=UPCOMING|PAST` (+ `participating`), le serveur triant le plus proche
/// d'abord pour l'avenir, le plus récent d'abord pour le passé (ledger
/// `API-85`). Une sortie partie et pas rentrée reste dans « À venir », marquée
/// « En cours ».
///
/// **La vue** : la liste de cartes, ou le calendrier du mois filtré sur
/// l'équipe — réservé aux membres, comme au site (plan §7.2). En calendrier,
/// la période se réduit à « Tout / Je participe » : on y navigue par mois.
///
/// **Le type** (Tout / Sorties / Voyages) est tenu **ici**, ouvert sur celui
/// du lien (`teamTrips`, `?type=ride`) et gardé d'une vue à l'autre. Il n'est
/// jamais recopié dans `publicationFeedTypeProvider` — leçon de `WEB-64`.
class TeamAgendaPage extends StatefulWidget {
  const TeamAgendaPage({
    super.key,
    required this.team,
    required this.sections,
    required this.chrome,
    this.leadingSlivers = const <Widget>[],
    this.initialType,
    this.initialScope = AgendaScope.upcoming,
    this.initialView = AgendaView.list,
    this.platformAdmin = false,
  });

  final TeamDetailDto team;

  /// La rangée de sections, épinglée sous l'en-tête.
  final List<TeamSection> sections;

  final TeamChromeBuilder chrome;

  /// L'en-tête d'équipe interpolé et ce qui le suit, en vue Liste.
  final List<Widget> leadingSlivers;

  final PublicationType? initialType;
  final AgendaScope initialScope;
  final AgendaView initialView;

  /// Le lecteur est administrateur de la plateforme : `team.role` reste son
  /// vrai rôle, nul s'il n'est pas membre (docs/LEDGER_*.md API-137), mais il
  /// ouvre le calendrier de toute équipe.
  final bool platformAdmin;

  @override
  State<TeamAgendaPage> createState() => _TeamAgendaPageState();
}

class _TeamAgendaPageState extends State<TeamAgendaPage> {
  late PublicationType? _type = widget.initialType;
  late AgendaScope _scope = widget.initialScope;
  late AgendaView _view = widget.initialView;

  /// Le calendrier d'une équipe est réservé à ses membres — et à
  /// l'administration de la plateforme.
  bool get _canShowCalendar => widget.team.role != null || widget.platformAdmin;

  @override
  Widget build(BuildContext context) {
    final AgendaView view = _canShowCalendar ? _view : AgendaView.list;
    final String slug = widget.team.slug;

    if (view == AgendaView.calendar) {
      return widget.chrome(
        header: TeamHeaderBar(
          team: widget.team,
          section: TeamSectionKind.agenda,
        ),
        body: Column(
          children: <Widget>[
            TeamSectionsBar(
              sections: widget.sections,
              current: TeamSectionKind.agenda,
            ),
            Material(
              color: context.pdl.overlaySolid,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  PdlMetrics.toolbarPadding,
                  PdlSpacing.section,
                  0,
                ),
                child: _header(view),
              ),
            ),
            Expanded(
              child: CalendarPage(
                teamSlug: slug,
                embedded: true,
                typeFilter: _calendarType(_type),
                onTypeChanged: (CalendarTypeFilter next) =>
                    setState(() => _type = _publicationType(next)),
                registeredOnly: _scope == AgendaScope.participating,
                onClearRegisteredOnly: () =>
                    setState(() => _scope = AgendaScope.upcoming),
              ),
            ),
          ],
        ),
      );
    }

    return widget.chrome(
      header: null,
      body: PublicationFeedView(
        teamSlug: slug,
        // Recherche et tags à part des Publications de la même équipe.
        filterScope: 'agenda/$slug',
        leadingSlivers: <Widget>[
          ...widget.leadingSlivers,
          TeamSectionsToolbar(
            sections: widget.sections,
            current: TeamSectionKind.agenda,
          ),
        ],
        toolbarHeader: _header(view),
        typeOptions: kAgendaTypeOptions,
        selectedType: _type,
        onTypeChanged: (PublicationType? next) => setState(() => _type = next),
        when: _scope == AgendaScope.past
            ? PublicationWhen.past
            : PublicationWhen.upcoming,
        participating: _scope == AgendaScope.participating,
        searchHint: 'teams.agenda.searchPlaceholder'.tr(),
        countLabel: (int total) => agendaCountLabel(_scope, _type, total),
        emptyMessage: 'teams.agenda.empty.title'.tr(),
        emptyHint: 'teams.agenda.empty.message'.tr(),
        emptyActions: <Widget>[
          if (_scope != AgendaScope.past)
            PdlButton(
              key: keys.teamAgenda.seePastButton,
              label: 'teams.agenda.empty.seePast'.tr(),
              variant: PdlButtonVariant.outline,
              size: PdlButtonSize.sm,
              onPressed: () => setState(() => _scope = AgendaScope.past),
            ),
        ],
      ),
    );
  }

  /// La période à gauche, la bascule Liste / Calendrier à droite.
  Widget _header(AgendaView view) {
    final bool calendar = view == AgendaView.calendar;
    // En calendrier, « À venir » et « Passées » n'ont plus de sens : on y
    // navigue par mois. Le filtre se réduit à « Tout / Je participe ».
    final AgendaScope scope = calendar && _scope == AgendaScope.past
        ? AgendaScope.upcoming
        : _scope;

    return Row(
      children: <Widget>[
        Expanded(
          child: PdlSegmented<AgendaScope>(
            value: scope,
            onChanged: (AgendaScope next) => setState(() => _scope = next),
            segments: <PdlSegment<AgendaScope>>[
              PdlSegment<AgendaScope>(
                key: keys.teamAgenda.scope(AgendaScope.upcoming.name),
                value: AgendaScope.upcoming,
                label: calendar
                    ? 'teams.agenda.scope.all'.tr()
                    : 'teams.agenda.scope.upcoming'.tr(),
              ),
              PdlSegment<AgendaScope>(
                key: keys.teamAgenda.scope(AgendaScope.participating.name),
                value: AgendaScope.participating,
                label: 'teams.agenda.scope.participating'.tr(),
              ),
              if (!calendar)
                PdlSegment<AgendaScope>(
                  key: keys.teamAgenda.scope(AgendaScope.past.name),
                  value: AgendaScope.past,
                  label: 'teams.agenda.scope.past'.tr(),
                ),
            ],
          ),
        ),
        if (_canShowCalendar) ...<Widget>[
          const SizedBox(width: PdlSpacing.chipGap),
          Semantics(
            container: true,
            label: 'teams.agenda.view.label'.tr(),
            child: SizedBox(
              width: PdlMetrics.tapTarget * 2 + PdlSpacing.chipGap,
              child: PdlSegmented<AgendaView>(
                value: view,
                onChanged: (AgendaView next) => setState(() => _view = next),
                segments: <PdlSegment<AgendaView>>[
                  PdlSegment<AgendaView>(
                    key: keys.teamAgenda.view(AgendaView.list.name),
                    value: AgendaView.list,
                    label: 'teams.agenda.view.list'.tr(),
                    icon: PdlIcons.list,
                    iconOnly: true,
                  ),
                  PdlSegment<AgendaView>(
                    key: keys.teamAgenda.view(AgendaView.calendar.name),
                    value: AgendaView.calendar,
                    label: 'teams.agenda.view.calendar'.tr(),
                    icon: PdlIcons.calendar,
                    iconOnly: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static CalendarTypeFilter _calendarType(PublicationType? type) =>
      switch (type) {
        PublicationType.ride => CalendarTypeFilter.rides,
        PublicationType.trip => CalendarTypeFilter.trips,
        _ => CalendarTypeFilter.all,
      };

  static PublicationType? _publicationType(CalendarTypeFilter type) =>
      switch (type) {
        CalendarTypeFilter.rides => PublicationType.ride,
        CalendarTypeFilter.trips => PublicationType.trip,
        CalendarTypeFilter.all => null,
      };
}

/// « 5 sorties et voyages à venir », selon la période et le type — les mêmes
/// neuf tournures qu'au site (`list.count.agenda*`).
String agendaCountLabel(AgendaScope scope, PublicationType? type, int total) {
  final String period = switch (scope) {
    AgendaScope.upcoming => 'upcoming',
    AgendaScope.participating => 'participating',
    AgendaScope.past => 'past',
  };
  final String kind = switch (type) {
    PublicationType.ride => 'rides',
    PublicationType.trip => 'trips',
    _ => 'all',
  };
  return 'teams.agenda.count.$period.$kind'.plural(total);
}
