import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/lists/list_toolbar.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../../calendar/presentation/pages/calendar_page.dart';
import '../../../calendar/providers/calendar_month_provider.dart';
import '../../../feed/presentation/widgets/publication_feed_view.dart';
import '../../../rides/presentation/ride_editor_location.dart';
import '../../../rides/providers/ride_editor_providers.dart';
import '../widgets/team_header.dart';
import '../widgets/team_sections.dart';
import '../widgets/team_sections_bar.dart';

/// Le cadre d'une section d'équipe : l'en-tête fixe ([header], quand le corps
/// a son propre défileur) ou aucun (quand le corps est une liste de slivers
/// qui porte l'en-tête interpolé). Fourni par `TeamHomePage`.
typedef TeamChromeBuilder = Widget Function({
  required Widget? header,
  required Widget body,
});

/// Les types de l'Agenda : ses sorties et ses voyages, jamais ses
/// publications (plan `2026-10-06-team-agenda.md` §2).
///
/// Ceux que l'Agenda de [team] propose : « Tout », puis « Sorties » et
/// « Voyages » **seulement si l'équipe a le module** — et les parcours, sans
/// lesquels ni l'un ni l'autre ne se publie —, comme au site
/// (`AgendaFilterBar`). Une chip qui ne peut rien trouver n'est pas offerte.
List<PublicationType?> agendaTypeOptions(TeamDetailDto team) =>
    <PublicationType?>[
      null,
      if (team.enableRides && team.enableRoutes) PublicationType.ride,
      if (team.enableTrips && team.enableRoutes) PublicationType.trip,
    ];

/// L'Agenda d'une équipe : ses sorties et ses voyages (ledger `MOB-60`).
///
/// **Une liste, deux sections** (règle RL15 des listes, KIT §10) : « À
/// venir », du plus proche au plus lointain — une sortie partie et pas rentrée
/// y reste, marquée « En cours » —, puis « Plus tôt », du plus récent au plus
/// ancien, chacune avec son compteur, dans le même défilement
/// (`when=UPCOMING_FIRST`). **La période** se réduit à « Toutes les dates /
/// Je participe », qui vaut pour les deux sections.
///
/// **La barre** (règle RL6) : la recherche en tête, « Créer » à sa droite pour
/// qui crée des sorties (RL13) ; la période sur toute la largeur ; les types
/// en puces alignées à gauche ; puis, sur la ligne du compteur, **le seul**
/// contrôle de vue : « Vignettes · Lignes · Calendrier » (RL9) — le
/// calendrier du mois filtré sur l'équipe, réservé aux membres, comme au site
/// (plan §7.2).
///
/// **Le type** (Tout / Sorties / Voyages) est tenu **ici**, ouvert sur celui
/// du lien (`teamTrips`, `?type=ride`) et gardé d'une vue à l'autre. Il n'est
/// jamais recopié dans `publicationFeedTypeProvider` — leçon de `WEB-64`.
class TeamAgendaPage extends ConsumerStatefulWidget {
  const TeamAgendaPage({
    super.key,
    required this.team,
    required this.sections,
    required this.chrome,
    this.leadingSlivers = const <Widget>[],
    this.initialType,
    this.initialScope = AgendaScope.all,
    this.initialView = AgendaView.cards,
    this.platformAdmin = false,
  });

  final TeamDetailDto team;

  /// La rangée de sections, épinglée sous l'en-tête.
  final List<TeamSection> sections;

  final TeamChromeBuilder chrome;

  /// L'en-tête d'équipe interpolé et ce qui le suit, en vue liste.
  final List<Widget> leadingSlivers;

  final PublicationType? initialType;
  final AgendaScope initialScope;
  final AgendaView initialView;

  /// Le lecteur est administrateur de la plateforme : `team.role` reste son
  /// vrai rôle, nul s'il n'est pas membre (docs/LEDGER_*.md API-137), mais il
  /// ouvre le calendrier de toute équipe.
  final bool platformAdmin;

  @override
  ConsumerState<TeamAgendaPage> createState() => _TeamAgendaPageState();
}

class _TeamAgendaPageState extends ConsumerState<TeamAgendaPage> {
  /// Les types offerts : ceux des modules de l'équipe.
  List<PublicationType?> get _typeOptions => agendaTypeOptions(widget.team);

  /// Le type du lien, s'il est offert : `?type=trip` sur une équipe sans
  /// voyages s'ouvre sur « Tout », pas sur une chip absente.
  late PublicationType? _type = _typeOptions.contains(widget.initialType)
      ? widget.initialType
      : null;
  late AgendaScope _scope = widget.initialScope;
  late AgendaView _view = widget.initialView;

  /// Le calendrier d'une équipe est réservé à ses membres — et à
  /// l'administration de la plateforme.
  bool get _canShowCalendar => widget.team.role != null || widget.platformAdmin;

  /// Créer une sortie : la règle de l'éditeur et du tableau de bord
  /// (`canManageRidesProvider` — organisation, modules sorties et parcours).
  bool get _canCreate =>
      ref.watch(canManageRidesProvider(widget.team.slug)) ?? false;

  void _openNew() => context.push(rideNewLocation(widget.team.slug));

  @override
  Widget build(BuildContext context) {
    final AgendaView view = _canShowCalendar || _view != AgendaView.calendar
        ? _view
        : AgendaView.cards;
    final String slug = widget.team.slug;
    final bool canCreate = _canCreate;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PdlSpacing.section,
                      PdlMetrics.toolbarPadding,
                      PdlSpacing.section,
                      0,
                    ),
                    child: _period(),
                  ),
                  ListCountRow(viewSwitch: _viewSwitch(view)),
                ],
              ),
            ),
            Expanded(
              child: CalendarPage(
                teamSlug: slug,
                embedded: true,
                typeFilter: _calendarType(_type),
                typeOptions: <CalendarTypeFilter>[
                  for (final PublicationType? type in _typeOptions)
                    _calendarType(type),
                ],
                onTypeChanged: (CalendarTypeFilter next) =>
                    setState(() => _type = _publicationType(next)),
                registeredOnly: _scope == AgendaScope.participating,
                onClearRegisteredOnly: () =>
                    setState(() => _scope = AgendaScope.all),
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
        period: _period(),
        searchTrailing: canCreate
            ? ListCreateButton(
                key: keys.teamAgenda.createButton,
                semanticLabel: 'lists.createLabel.ride'.tr(),
                onPressed: _openNew,
              )
            : null,
        viewSwitch: _viewSwitch(view),
        rows: view == AgendaView.rows,
        typeOptions: _typeOptions,
        selectedType: _type,
        onTypeChanged: (PublicationType? next) => setState(() => _type = next),
        datedSections: true,
        datedOnly: true,
        participating: _scope == AgendaScope.participating,
        // « Je participe » est un filtre : le vide filtré le nomme, et
        // « Effacer les filtres » ramène à « Toutes les dates » (règle RL10).
        periodFilterLabel: _scope == AgendaScope.participating
            ? 'lists.period.participating'.tr()
            : null,
        onClearPeriod: () => setState(() => _scope = AgendaScope.all),
        filteredTitleKey: 'lists.emptyFiltered.agenda',
        itemNounKey: 'lists.noun.agenda',
        searchHint: 'teams.agenda.searchPlaceholder'.tr(),
        emptyMessage: 'teams.agenda.empty.title'.tr(),
        emptyHint: 'teams.agenda.empty.message'.tr(),
        // Le vide simple reprend l'action de la barre, nom complet (RL13).
        emptyActions: <Widget>[
          if (canCreate)
            ListEmptyCreateButton(
              key: keys.teamAgenda.emptyCreateButton,
              label: 'lists.createLabel.ride'.tr(),
              onPressed: _openNew,
            ),
        ],
      ),
    );
  }

  /// « Toutes les dates / Je participe », sur toute la largeur.
  Widget _period() => FeedPeriodControl(
    allLabelKey: 'lists.period.allDates',
    participating: _scope == AgendaScope.participating,
    onChanged: (bool participating) => setState(
      () =>
          _scope = participating ? AgendaScope.participating : AgendaScope.all,
    ),
  );

  /// « Vignettes · Lignes · Calendrier » ; sans le calendrier pour qui n'est
  /// pas membre.
  Widget _viewSwitch(AgendaView view) => ListViewSwitch(
    views: <ListViewKind>[
      ListViewKind.cards,
      ListViewKind.rows,
      if (_canShowCalendar) ListViewKind.calendar,
    ],
    value: switch (view) {
      AgendaView.cards => ListViewKind.cards,
      AgendaView.rows => ListViewKind.rows,
      AgendaView.calendar => ListViewKind.calendar,
    },
    segmentKey: (ListViewKind kind) => keys.teamAgenda.view(kind.name),
    onChanged: (ListViewKind next) => setState(
      () => _view = switch (next) {
        ListViewKind.rows => AgendaView.rows,
        ListViewKind.calendar => AgendaView.calendar,
        _ => AgendaView.cards,
      },
    ),
  );

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
