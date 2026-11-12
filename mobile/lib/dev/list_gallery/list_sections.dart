// Les sections et les cas de la galerie des listes — page de DEBUG.
//
// Recopiés du cahier commun à l'app et au site
// (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/galerie.md`,
// § Cas, par liste), dans son ordre. Chaque cas monte **la page de
// production** et ne pose que trois choses :
//
// - les réponses du serveur factice (`gallery_api.dart`) : une page pleine
//   avec un total plus grand, une page vide, un vide filtré, une erreur 500,
//   une attente sans fin ;
// - l'état initial de la page, quand il vit dans un fournisseur (un filtre
//   posé) — par un remplacement de ce fournisseur ;
// - les gestes qui mènent à l'état quand il vit dans la page elle-même (une
//   feuille ouverte, une recherche tapée dans un champ tenu par l'écran) : la
//   galerie les décrit ([ListStep]), le test de capture les joue par de vrais
//   appuis.
//
// Un cas sans objet dans l'app est omis, avec sa raison ([ListSection.omitted]).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../api/generated/export.dart';
import '../../core/material.dart';
import '../../core/pdl/pdl.dart';
import '../../core/theme/pdl_icons.dart';
import '../../features/ads/domain/ad_filters.dart';
import '../../features/ads/providers/ad_list_provider.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/calendar/providers/calendar_month_provider.dart';
import '../../features/feed/providers/publication_feed_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/participants/presentation/widgets/participants_sheet.dart';
import '../../features/rides/presentation/pages/ride_template_list_page.dart';
import '../../features/routes/domain/route_filters.dart';
import '../../features/routes/presentation/pages/all_routes_page.dart';
import '../../features/routes/providers/route_list_provider.dart';
import '../../features/teams/domain/member_filters.dart';
import '../../features/teams/presentation/pages/team_home_page.dart';
import '../../features/teams/presentation/pages/teams_discover_page.dart';
import '../../features/teams/presentation/pages/teams_page.dart';
import '../../features/teams/presentation/widgets/team_sections.dart';
import '../../features/teams/providers/team_members_provider.dart';
import '../../keys.dart';
import '../card_gallery/gallery_data.dart';
import 'gallery_api.dart';
import 'list_data.dart';

/// Le slug du Vélo Club des Monts.
final String _vcm = GalleryData.vcm.slug;

// ─────────────────────────────────────────────────────────────── modèle

/// Ce qu'un geste vise : une clé, un texte, une icône, une infobulle ou le
/// premier champ de saisie — dans un widget de type [within] quand il est
/// donné.
@immutable
class ListTarget {
  const ListTarget.key(Key this.key)
    : text = null,
      icon = null,
      tooltip = null,
      field = false,
      within = null;
  const ListTarget.icon(IconData this.icon, {this.within})
    : key = null,
      text = null,
      tooltip = null,
      field = false;
  const ListTarget.tooltip(String this.tooltip)
    : key = null,
      text = null,
      icon = null,
      field = false,
      within = null;

  /// Le premier champ de saisie de l'écran, ou celui sous [key].
  const ListTarget.field([this.key])
    : text = null,
      icon = null,
      tooltip = null,
      field = true,
      within = null;

  final Key? key;
  final String? text;
  final IconData? icon;

  /// Une clé de traduction : l'infobulle se lit traduite.
  final String? tooltip;
  final bool field;
  final Type? within;
}

/// Un geste du test de capture.
sealed class ListStep {
  const ListStep();
}

/// Un appui.
final class ListTap extends ListStep {
  const ListTap(this.target);
  final ListTarget target;
}

/// Un défilement, par de vrais glissés, jusqu'à ce que [target] arrive en
/// haut de l'écran (ou que la page ne défile plus).
final class ListScrollTo extends ListStep {
  const ListScrollTo(this.target);
  final ListTarget target;
}

/// Une saisie dans un champ.
final class ListEnterText extends ListStep {
  const ListEnterText(this.target, this.text);
  final ListTarget target;
  final String text;
}

/// Un cas : une page de production, ses réponses, son état initial.
class ListCase {
  const ListCase(
    this.id, {
    required this.page,
    required this.api,
    this.overrides = _noOverrides,
    this.steps = const <ListStep>[],
    this.loaded,
  });

  /// L'identifiant du cahier (`parcours-vide-filtre`).
  final String id;

  final Widget Function(GalleryData data) page;

  /// Les adresses de l'API que la page appelle, et leurs réponses.
  final List<GalleryRoute> Function(GalleryData data) api;

  /// Les fournisseurs d'état initial (un filtre posé).
  final List<Override> Function(GalleryData data) overrides;

  /// Les gestes qui mènent à l'état — joués par le test de capture.
  final List<ListStep> steps;

  /// Un texte que la page montre une fois chargée : le test de galerie le
  /// cherche, preuve qu'elle n'est restée ni en chargement ni en erreur.
  final String? loaded;
}

List<Override> _noOverrides(GalleryData _) => const <Override>[];

class ListSection {
  const ListSection({
    required this.id,
    required this.title,
    required this.cases,
    this.omitted = const <String, String>{},
  });

  final String id;
  final String title;
  final List<ListCase> cases;

  /// Les cas du cahier sans objet dans l'app, et pourquoi.
  final Map<String, String> omitted;
}

ListSection? listSection(String? id) {
  for (final ListSection s in kListSections) {
    if (s.id == id) return s;
  }
  return null;
}

ListCase? listCase(String? sectionId, String? caseId) {
  for (final ListCase c
      in listSection(sectionId)?.cases ?? const <ListCase>[]) {
    if (c.id == caseId) return c;
  }
  return null;
}

// ───────────────────────────────────────────────────── réponses communes

/// Ce que toute page de la galerie peut demander en marge de sa liste : le
/// détail d'une équipe, ses tags, mes équipes, la cloche, les invitations.
/// Les cas posent leurs listes **devant** : la première adresse gagne.
List<GalleryRoute> _common(
  GalleryData d, {
  TeamDetailDto? team,
  ListMode myTeamsMode = ListMode.full,
}) {
  final TeamDetailDto vcm = team ?? d.clubDesMonts();
  return <GalleryRoute>[
    GalleryRoute.get('/api/teams/{teamSlug}', (GalleryRequest r) {
      final String slug = r.params['teamSlug']!;
      for (final TeamDetailDto t in <TeamDetailDto>[
        vcm,
        ...d.myTeams,
        ...d.discoverTeams,
      ]) {
        if (t.slug == slug) return GalleryJson(t);
      }
      return const GalleryError(404);
    }),
    GalleryRoute.get(
      '/api/teams/{teamSlug}/tags',
      (GalleryRequest r) => GalleryJson(switch (r.text('type')) {
        'POST' => ListGalleryData.postTags,
        'ROUTE' => ListGalleryData.routeTagVocabulary,
        _ => const <TagWithUsageDto>[],
      }),
    ),
    // « Mes équipes » transverse (rôles, accès, portée du fil).
    _myTeamsRoute(d, myTeamsMode, team: vcm),
    GalleryRoute.get(
      '/api/notifications/unread-count',
      (_) => const GalleryJson(UnreadCountDto(count: 2)),
    ),
    GalleryRoute.get(
      '/api/notifications/preferences',
      (_) => const GalleryJson(
        NotificationPreferencesDto(
          channels: <NotificationChannel>[],
          preferences: <NotificationPreferenceDto>[],
          teams: <NotificationTeamPreferenceDto>[],
          emailDigest: false,
        ),
      ),
    ),
    GalleryRoute.get(
      '/api/users/me/invitations',
      (_) => const GalleryJson(
        MyInvitationListResponse(invitations: <MyInvitationDto>[]),
      ),
    ),
  ];
}

/// `GET /api/teams?minRole=MEMBER` : mes équipes, cherchables.
GalleryRoute _myTeamsRoute(
  GalleryData d,
  ListMode mode, {
  TeamDetailDto? team,
}) {
  // Triées par nom, comme le serveur les rend sous `sortBy=NAME` — l'ordre de
  // « Mes équipes » (règle RL5).
  final List<TeamDetailDto> mine = sortedTeams(<TeamDetailDto>[
    team ?? d.clubDesMonts(),
    ...d.myTeams.skip(1),
  ], TeamSortBy.name);
  final ListFixture<TeamDetailDto> fixture = ListFixture<TeamDetailDto>(
    items: mine,
    total: ListTotals.myTeams,
    isFiltered: (GalleryRequest r) => r.any(<String>['search']),
    matches: (GalleryRequest r, TeamDetailDto t) =>
        textMatches(r.text('search'), <String?>[t.name, t.excerpt]),
  );
  return GalleryRoute.get(
    '/api/teams',
    (GalleryRequest r) => fixture.list(
      r,
      mode,
      (List<TeamDetailDto> page, int total) => TeamListResponse(
        teams: page,
        total: total,
        page: r.page,
        size: r.size,
      ),
    ),
    when: (GalleryRequest r) => r.text('minRole') != null,
  );
}

String _publicationType(PublicationDto p) => switch (p) {
  PublicationDtoRide() => 'RIDE',
  PublicationDtoTrip() => 'TRIP',
  PublicationDtoPost() => 'POST',
};

bool _registered(PublicationDto p) => switch (p) {
  PublicationDtoRide(:final bool registered) => registered,
  PublicationDtoTrip(:final bool registered) => registered,
  PublicationDtoPost() => false,
};

List<String> _tagIds(PublicationDto p) => switch (p) {
  PublicationDtoRide(:final List<TagDto> tags) =>
    tags.map((t) => t.id).toList(),
  PublicationDtoTrip(:final List<TagDto> tags) =>
    tags.map((t) => t.id).toList(),
  PublicationDtoPost(:final List<TagDto> tags) =>
    tags.map((t) => t.id).toList(),
};

String? _excerpt(PublicationDto p) => switch (p) {
  PublicationDtoRide(:final String? excerpt) => excerpt,
  PublicationDtoTrip(:final String? excerpt) => excerpt,
  PublicationDtoPost(:final String? excerpt) => excerpt,
};

List<String> _list(String? csv) =>
    csv == null ? const <String>[] : csv.split(',');

/// Ce qu'un filtre de publications retient : type, recherche, tags, « Je
/// participe ».
bool _publicationMatches(GalleryRequest r, PublicationDto p) {
  final String? type = r.text('type');
  if (type != null && _publicationType(p) != type) return false;
  if (!textMatches(r.text('search'), <String?>[p.name, _excerpt(p)])) {
    return false;
  }
  final List<String> tags = _list(r.text('tags'));
  if (tags.isNotEmpty && !_tagIds(p).any(tags.contains)) return false;
  if (r.text('participating') == 'true' && !_registered(p)) return false;
  return true;
}

/// Une liste de publications (`…/publications`) et son compteur.
List<GalleryRoute> _publicationRoutes(
  String template,
  ListMode mode,
  ListFixture<PublicationDto> Function(GalleryRequest r) fixture,
) => <GalleryRoute>[
  GalleryRoute.get(
    '$template/count',
    (GalleryRequest r) => fixture(r).count(r, mode),
  ),
  GalleryRoute.get(
    template,
    (GalleryRequest r) => fixture(r).list(
      r,
      mode,
      (List<PublicationDto> page, int total) => PublicationListResponse(
        publications: page,
        total: total,
        page: r.page,
        size: r.size,
      ),
    ),
  ),
];

/// Une liste de publications **à deux sections** quand la requête porte
/// `when=UPCOMING_FIRST` (règle RL15, contrat 14.8.0) : [upcoming] puis
/// [earlier], et `upcomingTotal`. Sans filtre, les totaux annoncés sont
/// [upcomingTotal] et [earlierTotal] ; sous un filtre, ceux des éléments
/// retenus. « Plus tôt » (`when=EARLIER` au fil d'accueil, `when=PAST` à
/// l'Agenda) lit [past], sur [earlierTotal] et sans `upcomingTotal`. Une
/// requête sans `when` lit [plain].
List<GalleryRoute> _datedPublicationRoutes(
  String template,
  ListMode mode, {
  required List<PublicationDto> upcoming,
  required List<PublicationDto> earlier,
  required List<PublicationDto> past,
  required int upcomingTotal,
  required int earlierTotal,
  required bool Function(GalleryRequest r) isFiltered,
  required ListFixture<PublicationDto> plain,
}) {
  bool dated(GalleryRequest r) => r.text('when') == 'UPCOMING_FIRST';
  bool pastOnly(GalleryRequest r) =>
      r.text('when') == 'EARLIER' || r.text('when') == 'PAST';
  final ListFixture<PublicationDto> pastFixture = ListFixture<PublicationDto>(
    items: past,
    total: earlierTotal,
    isFiltered: isFiltered,
    matches: _publicationMatches,
  );

  /// Les deux sections de la page 0 et leurs totaux, ou `null` (erreur,
  /// attente).
  ({List<PublicationDto> items, int total, int upcoming})? answer(
    GalleryRequest r,
  ) {
    switch (mode) {
      case ListMode.error:
      case ListMode.loading:
        return null;
      case ListMode.empty:
        return (items: const <PublicationDto>[], total: 0, upcoming: 0);
      case ListMode.emptyFiltered when isFiltered(r):
        return (items: const <PublicationDto>[], total: 0, upcoming: 0);
      case ListMode.full:
      case ListMode.emptyFiltered:
        if (!isFiltered(r)) {
          return (
            items: pageOf(r, <PublicationDto>[...upcoming, ...earlier]),
            total: upcomingTotal + earlierTotal,
            upcoming: upcomingTotal,
          );
        }
        final List<PublicationDto> keptUpcoming = <PublicationDto>[
          for (final PublicationDto p in upcoming)
            if (_publicationMatches(r, p)) p,
        ];
        final List<PublicationDto> keptEarlier = <PublicationDto>[
          for (final PublicationDto p in earlier)
            if (_publicationMatches(r, p)) p,
        ];
        return (
          items: pageOf(r, <PublicationDto>[...keptUpcoming, ...keptEarlier]),
          total: keptUpcoming.length + keptEarlier.length,
          upcoming: keptUpcoming.length,
        );
    }
  }

  GalleryReply reply(GalleryRequest r, Object Function(dynamic a) body) =>
      switch (mode) {
        ListMode.error => const GalleryError(),
        ListMode.loading => const GalleryPending(),
        _ => GalleryJson(body(answer(r)!)),
      };

  return <GalleryRoute>[
    GalleryRoute.get(
      '$template/count',
      (GalleryRequest r) =>
          reply(r, (dynamic a) => <String, int>{'total': a.total as int}),
      when: dated,
    ),
    GalleryRoute.get(
      template,
      (GalleryRequest r) => reply(
        r,
        (dynamic a) => PublicationListResponse(
          publications: a.items as List<PublicationDto>,
          total: a.total as int,
          page: r.page,
          size: r.size,
          upcomingTotal: a.upcoming as int,
        ),
      ),
      when: dated,
    ),
    // « Plus tôt » : une liste simple, servie comme une liste sans `when`.
    for (final GalleryRoute route in _publicationRoutes(
      template,
      mode,
      (_) => pastFixture,
    ))
      GalleryRoute.get(route.template, route.handler, when: pastOnly),
    ..._publicationRoutes(template, mode, (_) => plain),
  ];
}

/// Les événements de [events] compris entre `from` et `to`.
GalleryReply _events(
  GalleryRequest r,
  ListMode mode,
  List<CalendarEventDto> events,
) {
  switch (mode) {
    case ListMode.error:
      return const GalleryError();
    case ListMode.loading:
      return const GalleryPending();
    case ListMode.empty:
      return const GalleryJson(
        CalendarEventsResponse(events: <CalendarEventDto>[]),
      );
    case ListMode.full:
    case ListMode.emptyFiltered:
      final DateTime? from = DateTime.tryParse(r.text('from') ?? '');
      final DateTime? to = DateTime.tryParse(r.text('to') ?? '');
      return GalleryJson(
        CalendarEventsResponse(
          events: <CalendarEventDto>[
            for (final CalendarEventDto e in events)
              if ((from == null || !DateTime.parse(e.start).isBefore(from)) &&
                  (to == null || !DateTime.parse(e.start).isAfter(to)))
                e,
          ],
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────── accueil

ListCase _home(
  String id, {
  ListMode mode = ListMode.full,
  List<Override> Function(GalleryData d) overrides = _noOverrides,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
  bool frontier = false,
}) {
  // Un chargement initial vaut pour tout l'écran ; un vide, pour ce que
  // Camille fait à vélo — ni sortie à venir, ni semaine — mais elle garde ses
  // équipes.
  final ListMode blocks = switch (mode) {
    ListMode.loading => ListMode.loading,
    ListMode.empty => ListMode.empty,
    _ => ListMode.full,
  };
  return ListCase(
    id,
    page: (_) => const HomePage(),
    overrides: overrides,
    // Le fil vient sous « Ma prochaine sortie », « Les 7 prochains jours » et
    // « Mes équipes » : on le fait monter jusqu'à ce que sa barre s'épingle.
    steps: <ListStep>[
      ListScrollTo(ListTarget.key(keys.feed.searchField)),
      ...steps,
    ],
    loaded: loaded,
    api: (GalleryData d) {
      // « Membre » est la portée par défaut : « Toutes les équipes » en écarte
      // la requête, et c'est un filtre ; « Je participe » aussi.
      bool filtered(GalleryRequest r) =>
          r.any(<String>['type', 'search']) ||
          r.text('minRole') != 'MEMBER' ||
          r.text('participating') == 'true';
      return <GalleryRoute>[
        // « Tout » : « À venir » puis « Plus tôt » (règle RL15). Au repos, la
        // première page n'est faite que d'« À venir » ; `accueil-sections`
        // montre la frontière.
        ..._datedPublicationRoutes(
          '/api/publications',
          mode,
          upcoming: frontier ? d.homeUpcoming.take(2).toList() : d.homeUpcoming,
          earlier: frontier ? d.homeEarlier : const <PublicationDto>[],
          past: d.homeEarlier,
          upcomingTotal: frontier ? 2 : ListTotals.homeUpcoming,
          earlierTotal: ListTotals.homeEarlier,
          isFiltered: filtered,
          plain: ListFixture<PublicationDto>(
            items: d.feedItems,
            total: ListTotals.feed,
            isFiltered: filtered,
            matches: _publicationMatches,
          ),
        ),
        GalleryRoute.get('/api/users/me/participations', (GalleryRequest r) {
          if (blocks == ListMode.loading) return const GalleryPending();
          final List<PublicationDto> mine = blocks == ListMode.empty
              ? const <PublicationDto>[]
              : <PublicationDto>[d.feedRide(registeredIn: 'B')];
          return GalleryJson(
            PublicationListResponse(
              publications: mine,
              total: mine.length,
              page: 0,
              size: r.size,
            ),
          );
        }),
        GalleryRoute.get(
          '/api/calendar/events',
          (GalleryRequest r) => _events(r, blocks, d.weekEvents),
        ),
        ..._common(
          d,
          myTeamsMode: blocks == ListMode.loading
              ? ListMode.loading
              : ListMode.full,
        ),
      ];
    },
  );
}

List<Override> _homeAllRides(GalleryData _) => <Override>[
  publicationFeedScopeProvider(null).overrideWith((Ref ref) => (minRole: null)),
  publicationFeedTypeProvider(null)
      .overrideWith((Ref ref) => PublicationType.ride),
];

List<Override> _homeEarlier(GalleryData _) => <Override>[
  publicationFeedPeriodProvider(null)
      .overrideWith((Ref ref) => AgendaScope.earlier),
];

final List<ListCase> _accueilCases = <ListCase>[
  _home('accueil-repos', loaded: kRideName),
  // La frontière entre « À venir » et « Plus tôt », dans le même défilement.
  _home(
    'accueil-sections',
    frontier: true,
    // La dernière carte « À venir » en haut : l'en-tête « Plus tôt » suit,
    // sous la barre épinglée.
    steps: <ListStep>[ListScrollTo(ListTarget.key(keys.feed.card(kRideSlug)))],
    loaded: kPostName,
  ),
  // « Plus tôt » : tout sauf l'à-venir, en une liste simple, son compteur sur
  // sa ligne (RL15, complément du 12 novembre 2026).
  _home('accueil-plus-tot', overrides: _homeEarlier, loaded: kPostName),
  _home('accueil-filtre', overrides: _homeAllRides, loaded: kRideName),
  _home(
    'accueil-criteres',
    steps: <ListStep>[ListTap(ListTarget.key(keys.feed.scopeChip))],
    loaded: kRideName,
  ),
  _home('accueil-vide', mode: ListMode.empty),
  _home(
    'accueil-vide-filtre',
    mode: ListMode.emptyFiltered,
    overrides: _homeAllRides,
  ),
  _home('accueil-erreur', mode: ListMode.error),
  _home('accueil-chargement', mode: ListMode.loading),
];

// ───────────────────────────────────────────────────────── publications

ListCase _posts(
  String id, {
  ListMode mode = ListMode.full,
  String role = 'ORGANIZER',
  List<Override> Function(GalleryData d) overrides = _noOverrides,
  String? loaded,
}) => ListCase(
  id,
  page: (_) => TeamHomePage(teamSlug: _vcm, section: TeamSectionKind.posts),
  overrides: overrides,
  loaded: loaded,
  api: (GalleryData d) => <GalleryRoute>[
    ..._publicationRoutes(
      '/api/teams/{teamSlug}/publications',
      mode,
      (_) => ListFixture<PublicationDto>(
        items: d.posts,
        total: ListTotals.posts,
        isFiltered: (GalleryRequest r) => r.any(<String>['search', 'tags']),
        matches: _publicationMatches,
      ),
    ),
    ..._common(d, team: d.clubDesMonts(role: role)),
  ],
);

List<Override> _postsSearchAndTag(GalleryData _) => <Override>[
  publicationFeedSearchProvider('posts/$_vcm')
      .overrideWith((Ref ref) => 'monts'),
  publicationFeedTagsProvider('posts/$_vcm')
      .overrideWith((Ref ref) => const <String>['tag-recit']),
];

final List<ListCase> _publicationsCases = <ListCase>[
  _posts('publications-repos', loaded: kPostName),
  _posts(
    'publications-filtre',
    overrides: _postsSearchAndTag,
    loaded: 'Les Monts d’Arrée sous la neige',
  ),
  _posts('publications-vide', mode: ListMode.empty),
  _posts(
    'publications-vide-filtre',
    mode: ListMode.emptyFiltered,
    overrides: _postsSearchAndTag,
  ),
  _posts('publications-erreur', mode: ListMode.error),
  _posts('publications-lecture', role: 'MEMBER', loaded: kPostName),
];

// ─────────────────────────────────────────────────────────────── agenda

ListCase _agenda(
  String id, {
  ListMode mode = ListMode.full,
  String role = 'ORGANIZER',
  PublicationType? type,
  AgendaScope scope = AgendaScope.all,
  AgendaView view = AgendaView.cards,
  bool frontier = false,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) => ListCase(
  id,
  page: (_) => TeamHomePage(
    teamSlug: _vcm,
    section: TeamSectionKind.agenda,
    agendaType: type,
    agendaScope: scope,
    agendaView: view,
  ),
  steps: steps,
  loaded: loaded,
  api: (GalleryData d) {
    // Le type, la recherche, les tags et « Je participe » sont des filtres.
    bool filtered(GalleryRequest r) =>
        r.any(<String>['search', 'tags', 'type']) ||
        r.text('participating') == 'true';
    return <GalleryRoute>[
      // « À venir » puis « Plus tôt » (règle RL15). Au repos, la première
      // page n'est faite que d'« À venir » (18) ; `agenda-sections` montre
      // la frontière.
      ..._datedPublicationRoutes(
        '/api/teams/{teamSlug}/publications',
        mode,
        upcoming: d.agendaUpcoming,
        earlier: frontier ? d.agendaPast : const <PublicationDto>[],
        past: d.agendaPast,
        upcomingTotal: frontier ? d.agendaUpcoming.length : ListTotals.agenda,
        earlierTotal: ListTotals.past,
        isFiltered: filtered,
        plain: ListFixture<PublicationDto>(
          items: d.agendaUpcoming,
          total: ListTotals.agenda,
          isFiltered: filtered,
          matches: _publicationMatches,
        ),
      ),
      ..._common(d, team: d.clubDesMonts(role: role)),
    ];
  },
);

final List<ListCase> _agendaCases = <ListCase>[
  _agenda('agenda-repos', loaded: 'Sortie récupération'),
  // La frontière entre « À venir » et « Plus tôt », dans le même défilement.
  _agenda(
    'agenda-sections',
    frontier: true,
    // La dernière carte « À venir » en haut : l'en-tête « Plus tôt » suit,
    // sous la barre épinglée.
    steps: <ListStep>[ListScrollTo(ListTarget.key(keys.feed.card(kTripSlug)))],
    loaded: 'Tour du lac',
  ),
  // « Plus tôt » : les sorties et voyages passés, en une liste simple, son
  // compteur sur la ligne du contrôle de vue (RL15, 12 novembre 2026).
  _agenda(
    'agenda-plus-tot',
    scope: AgendaScope.earlier,
    loaded: 'Tour du lac du Drennec',
  ),
  _agenda(
    'agenda-filtre',
    type: PublicationType.ride,
    scope: AgendaScope.participating,
    loaded: kRideName,
  ),
  _agenda('agenda-vide', mode: ListMode.empty),
  _agenda(
    'agenda-vide-filtre',
    mode: ListMode.emptyFiltered,
    type: PublicationType.ride,
    scope: AgendaScope.participating,
  ),
  _agenda('agenda-erreur', mode: ListMode.error),
  _agenda('agenda-lecture', role: 'MEMBER', loaded: 'Sortie récupération'),
];

// ─────────────────────────────────────────────────────────── calendrier

ListCase _calendar(
  String id, {
  ListMode mode = ListMode.full,
  List<CalendarEventDto> Function(GalleryData d)? events,
  bool team = false,
  List<Override> Function(GalleryData d) overrides = _noOverrides,
  String? loaded,
}) => ListCase(
  id,
  page: (_) => team
      ? TeamHomePage(
          teamSlug: _vcm,
          section: TeamSectionKind.agenda,
          agendaView: AgendaView.calendar,
        )
      : const CalendarPage(),
  overrides: overrides,
  loaded: loaded,
  api: (GalleryData d) => <GalleryRoute>[
    GalleryRoute.get(
      team ? '/api/teams/{teamSlug}/calendar/events' : '/api/calendar/events',
      (GalleryRequest r) =>
          _events(r, mode, (events ?? (GalleryData d) => d.monthEvents)(d)),
    ),
    GalleryRoute.get('/api/calendar/token', (_) => const GalleryError(404)),
    ..._common(d),
  ],
);

List<Override> _ridesOnly(GalleryData _) => <Override>[
  calendarTypeFilterProvider.overrideWith(
    (Ref ref) => CalendarTypeFilter.rides,
  ),
];

final List<ListCase> _calendrierCases = <ListCase>[
  _calendar('calendrier-repos', loaded: 'Sortie récupération'),
  _calendar('calendrier-filtre', overrides: _ridesOnly, loaded: kRideName),
  _calendar('calendrier-equipe', team: true, loaded: 'Sortie récupération'),
  // Le mois courant est vide, le suivant ne l'est pas : l'état vide propose
  // « Aller au prochain mois avec une sortie » (règle RL10).
  _calendar('calendrier-vide', events: (GalleryData d) => d.laterMonthEvents),
  _calendar(
    'calendrier-vide-filtre',
    events: (GalleryData d) => d.monthStagesOnly,
    overrides: _ridesOnly,
  ),
  _calendar('calendrier-erreur', mode: ListMode.error),
  _calendar('calendrier-chargement', mode: ListMode.loading),
];

// ─────────────────────────────────────────────────────────────── parcours

/// La vue liste ou carte, imposée : sans quoi la dernière vue employée sur
/// l'appareil (préférences) déciderait de la capture.
class _GalleryRouteView extends RouteViewModeNotifier {
  _GalleryRouteView(super.kind, this.initial);
  final RouteViewMode initial;
  @override
  RouteViewMode build() => initial;
}

class _GalleryRouteDensity extends RouteDensityNotifier {
  _GalleryRouteDensity(super.kind, this.initial);
  final RouteListDensity? initial;
  @override
  RouteListDensity? build() => initial;
}

/// La portée (`minRole`) n'est pas un filtre du contenu : le total « sur 47 »
/// reste celui de toute la portée.
bool _routeFiltered(GalleryRequest r) => r.any(<String>[
  'search',
  'minDistance',
  'maxDistance',
  'minElevationGain',
  'maxElevationGain',
  'hilliness',
  'surfaceType',
  'windDirection',
  'nearLat',
  'tags',
]);

bool _routeMatches(GalleryRequest r, RouteDto route) {
  if (!textMatches(r.text('search'), <String?>[route.name])) return false;
  final double? min = double.tryParse(r.text('minDistance') ?? '');
  final double? max = double.tryParse(r.text('maxDistance') ?? '');
  if (min != null && route.distance < min) return false;
  if (max != null && route.distance > max) return false;
  final String? surface = r.text('surfaceType');
  if (surface != null && route.surfaceType != surface) return false;
  final List<String> tags = _list(r.text('tags'));
  if (tags.isNotEmpty && !route.tags.any((TagDto t) => tags.contains(t.id))) {
    return false;
  }
  return true;
}

List<GalleryRoute> _routeRoutes(
  String template,
  ListMode mode,
  List<RouteDto> items,
  int total,
) {
  final ListFixture<RouteDto> fixture = ListFixture<RouteDto>(
    items: items,
    total: total,
    isFiltered: _routeFiltered,
    matches: _routeMatches,
  );
  return <GalleryRoute>[
    GalleryRoute.get(
      '$template/count',
      (GalleryRequest r) => fixture.count(r, mode),
    ),
    // La vue Carte : ni jeton de tuiles ni emprise, la carte native n'existe
    // pas hors appareil.
    GalleryRoute.get('$template/bounds', (_) => const GalleryError(404)),
    GalleryRoute('POST', '/api/tiles/token', (_) => const GalleryError(404)),
    GalleryRoute.get(
      template,
      (GalleryRequest r) => fixture.list(
        r,
        mode,
        (List<RouteDto> page, int total) => RouteListResponse(
          routes: page,
          total: total,
          page: r.page,
          size: r.size,
        ),
      ),
    ),
  ];
}

ListCase _routes(
  String id, {
  ListMode mode = ListMode.full,
  String role = 'ORGANIZER',
  RouteViewMode view = RouteViewMode.list,
  RouteListDensity? density,
  RouteFilters? filters,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) => ListCase(
  id,
  page: (_) => TeamHomePage(teamSlug: _vcm, section: TeamSectionKind.routes),
  steps: steps,
  loaded: loaded,
  overrides: (_) => <Override>[
    routeViewModeProvider(RouteListKind.team)
        .overrideWith(() => _GalleryRouteView(RouteListKind.team, view)),
    routeDensityProvider(RouteListKind.team)
        .overrideWith(() => _GalleryRouteDensity(RouteListKind.team, density)),
    if (filters != null)
      routeFiltersProvider(_vcm).overrideWith((Ref ref) => filters),
  ],
  api: (GalleryData d) => <GalleryRoute>[
    ..._routeRoutes(
      '/api/teams/{teamSlug}/routes',
      mode,
      d.teamRoutes,
      ListTotals.routes,
    ),
    ..._common(d, team: d.clubDesMonts(role: role)),
  ],
);

final RouteFilters _hilly50to100 = RouteFilters(
  teamSlug: _vcm,
  minDistance: 50000,
  maxDistance: 100000,
  tagIds: const <String>['tag-vallonne'],
  addedOrder: const <RouteFilterField>[
    RouteFilterField.distance,
    RouteFilterField.tags,
  ],
);

final List<ListCase> _parcoursCases = <ListCase>[
  _routes('parcours-repos', density: RouteListDensity.cards, loaded: kRideName),
  _routes(
    'parcours-lignes',
    density: RouteListDensity.compact,
    loaded: kRideName,
  ),
  _routes('parcours-carte', view: RouteViewMode.map),
  _routes(
    'parcours-filtre',
    filters: _hilly50to100,
    loaded: 'Monts d’Arrée, parcours B',
  ),
  _routes(
    'parcours-criteres',
    steps: <ListStep>[ListTap(ListTarget.key(keys.routes.filterButton))],
    loaded: kRideName,
  ),
  _routes(
    'parcours-tri',
    steps: const <ListStep>[
      ListTap(ListTarget.icon(PdlIcons.chevronDown, within: PdlChip)),
    ],
    loaded: kRideName,
  ),
  _routes('parcours-vide', mode: ListMode.empty),
  _routes(
    'parcours-vide-filtre',
    mode: ListMode.emptyFiltered,
    filters: _hilly50to100,
  ),
  _routes('parcours-erreur', mode: ListMode.error),
  _routes('parcours-lecture', role: 'MEMBER', loaded: kRideName),
];

// ─────────────────────────────────────────────────────────────── explorer

ListCase _explore(
  String id, {
  ListMode mode = ListMode.full,
  RouteFilters? filters,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) => ListCase(
  id,
  page: (_) => const AllRoutesPage(),
  steps: steps,
  loaded: loaded,
  overrides: (_) => <Override>[
    routeViewModeProvider(RouteListKind.explore).overrideWith(
      () => _GalleryRouteView(RouteListKind.explore, RouteViewMode.list),
    ),
    routeDensityProvider(RouteListKind.explore)
        .overrideWith(() => _GalleryRouteDensity(RouteListKind.explore, null)),
    if (filters != null)
      routeFiltersProvider(null).overrideWith((Ref ref) => filters),
  ],
  api: (GalleryData d) => <GalleryRoute>[
    ..._routeRoutes('/api/routes', mode, d.exploreRoutes, ListTotals.explore),
    ..._common(d),
  ],
);

/// « Toutes les équipes » (la portée écartée de « Membre », son défaut) et
/// « Route » : deux filtres.
const RouteFilters _allTeamsRoad = RouteFilters(
  defaultMinRole: MinRole.member,
  surfaceType: SurfaceType.road,
  addedOrder: <RouteFilterField>[RouteFilterField.surfaceType],
);

final List<ListCase> _explorerCases = <ListCase>[
  _explore('explorer-repos', loaded: 'Landes du Cragou'),
  _explore('explorer-filtre', filters: _allTeamsRoad, loaded: kRideName),
  _explore(
    'explorer-criteres',
    steps: <ListStep>[ListTap(ListTarget.key(keys.routes.filterButton))],
    loaded: 'Landes du Cragou',
  ),
  _explore(
    'explorer-vide-filtre',
    mode: ListMode.emptyFiltered,
    filters: _allTeamsRoad,
  ),
  _explore('explorer-erreur', mode: ListMode.error),
];

// ─────────────────────────────────────────────────────────────── annonces

ListCase _ads(
  String id, {
  ListMode mode = ListMode.full,
  AdType? type,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) {
  return ListCase(
    id,
    page: (_) => TeamHomePage(teamSlug: _vcm, section: TeamSectionKind.ads),
    steps: steps,
    loaded: loaded,
    overrides: (_) => <Override>[
      if (type != null)
        adFiltersProvider(_vcm)
            .overrideWith((Ref ref) => AdFilters(teamSlug: _vcm, adType: type)),
    ],
    api: (GalleryData d) {
      final ListFixture<AdDto> fixture = ListFixture<AdDto>(
        items: d.ads,
        total: ListTotals.ads,
        isFiltered: (GalleryRequest r) =>
            r.any(<String>['search', 'adType', 'tags']),
        matches: (GalleryRequest r, AdDto ad) =>
            (r.text('adType') == null || ad.adType == r.text('adType')) &&
            textMatches(r.text('search'), <String?>[ad.name, ad.excerpt]),
      );
      return <GalleryRoute>[
        GalleryRoute.get(
          '/api/teams/{teamSlug}/classifieds/count',
          (GalleryRequest r) => fixture.count(r, mode),
        ),
        GalleryRoute.get(
          '/api/teams/{teamSlug}/classifieds',
          (GalleryRequest r) => fixture.list(
            r,
            mode,
            (List<AdDto> page, int total) => AdListResponse(
              ads: page,
              total: total,
              page: r.page,
              size: r.size,
            ),
          ),
        ),
        ..._common(d),
      ];
    },
  );
}

final List<ListCase> _annoncesCases = <ListCase>[
  _ads('annonces-repos', loaded: 'Remorque enfant'),
  _ads('annonces-filtre', type: AdType.sale, loaded: 'Vélo de route carbone'),
  _ads(
    'annonces-tri',
    steps: const <ListStep>[
      ListTap(ListTarget.icon(PdlIcons.sort, within: PdlChip)),
    ],
    loaded: 'Remorque enfant',
  ),
  _ads('annonces-vide', mode: ListMode.empty),
  _ads('annonces-vide-filtre', mode: ListMode.emptyFiltered, type: AdType.sale),
  _ads('annonces-erreur', mode: ListMode.error),
];

// ─────────────────────────────────────────────────────────────── équipes

// La recherche est toujours visible (règle RL6) : on y tape directement.
const List<ListStep> _searchBretagne = <ListStep>[
  ListEnterText(ListTarget.field(), 'bretagne'),
];

ListCase _myTeams(
  String id, {
  ListMode mode = ListMode.full,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) => ListCase(
  id,
  page: (_) => const TeamsPage(),
  steps: steps,
  loaded: loaded,
  api: (GalleryData d) => <GalleryRoute>[_myTeamsRoute(d, mode), ..._common(d)],
);

final List<ListCase> _equipesCases = <ListCase>[
  _myTeams('equipes-repos', loaded: 'Les Rouleurs du Léon'),
  ListCase(
    'equipes-decouvrir',
    page: (_) => const TeamsDiscoverPage(),
    loaded: 'Cyclos de Morlaix',
    api: (GalleryData d) {
      // Dans l'ordre demandé (`sortBy`) : par nombre de membres sous
      // « Toutes », par nom sous « Mes équipes » (règle RL5).
      ListFixture<TeamDetailDto> fixture(GalleryRequest r) =>
          ListFixture<TeamDetailDto>(
            items: sortedTeams(
              d.discoverTeams,
              r.text('sortBy') == 'MEMBER_COUNT'
                  ? TeamSortBy.memberCount
                  : TeamSortBy.name,
            ),
            total: ListTotals.discover,
            isFiltered: (GalleryRequest r) => r.any(<String>['search']),
            matches: (GalleryRequest r, TeamDetailDto t) =>
                textMatches(r.text('search'), <String?>[t.name, t.excerpt]),
          );
      return <GalleryRoute>[
        GalleryRoute.get(
          '/api/teams',
          (GalleryRequest r) => fixture(r).list(
            r,
            ListMode.full,
            (List<TeamDetailDto> page, int total) => TeamListResponse(
              teams: page,
              total: total,
              page: r.page,
              size: r.size,
            ),
          ),
          when: (GalleryRequest r) => r.text('minRole') == null,
        ),
        ..._common(d),
      ];
    },
  ),
  _myTeams('equipes-filtre', steps: _searchBretagne, loaded: 'Gravel Bretagne'),
  _myTeams('equipes-vide', mode: ListMode.empty),
  _myTeams(
    'equipes-vide-filtre',
    mode: ListMode.emptyFiltered,
    steps: _searchBretagne,
  ),
  _myTeams('equipes-erreur', mode: ListMode.error),
];

// ─────────────────────────────────────────────────────────────── membres

ListCase _members(
  String id, {
  ListMode mode = ListMode.full,
  TeamRole? role,
  String? loaded,
}) => ListCase(
  id,
  page: (_) => TeamHomePage(teamSlug: _vcm, section: TeamSectionKind.members),
  loaded: loaded,
  overrides: (_) => <Override>[
    if (role != null)
      memberFiltersProvider(_vcm)
          .overrideWith((Ref ref) => MemberFilters(teamSlug: _vcm, role: role)),
  ],
  api: (GalleryData d) {
    final ListFixture<MemberDto> fixture = ListFixture<MemberDto>(
      items: d.members,
      total: ListTotals.members,
      isFiltered: (GalleryRequest r) => r.any(<String>['search', 'role']),
      matches: (GalleryRequest r, MemberDto m) =>
          (r.text('role') == null || m.role == r.text('role')) &&
          textMatches(r.text('search'), <String?>[m.user.displayName]),
    );
    return <GalleryRoute>[
      GalleryRoute.get(
        '/api/teams/{teamSlug}/members',
        (GalleryRequest r) => fixture.list(
          r,
          mode,
          (List<MemberDto> page, int total) => MemberListResponse(
            members: page,
            total: total,
            page: r.page,
            size: r.size,
          ),
        ),
      ),
      ..._common(d, team: d.clubDesMontsDirectory()),
    ];
  },
);

final List<ListCase> _membresCases = <ListCase>[
  _members('membres-repos', loaded: 'Karim Benali'),
  _members('membres-filtre', role: TeamRole.organizer, loaded: 'Karim Benali'),
  _members(
    'membres-vide-filtre',
    mode: ListMode.emptyFiltered,
    role: TeamRole.organizer,
  ),
  _members('membres-erreur', mode: ListMode.error),
];

// ─────────────────────────────────────────────────────────────── inscrits

/// La feuille « Personnes inscrites » du groupe B, ouverte comme la page du
/// groupe l'ouvre (`ParticipantsSheet.open`), au-dessus d'un fond neutre : la
/// page du groupe porte une carte native, absente hors appareil.
class _ParticipantsHost extends StatefulWidget {
  const _ParticipantsHost({required this.data, required this.empty});
  final GalleryData data;

  /// Le groupe n'a personne : le détail le dit (0), la feuille le lit.
  final bool empty;

  @override
  State<_ParticipantsHost> createState() => _ParticipantsHostState();
}

class _ParticipantsHostState extends State<_ParticipantsHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RideDto ride = widget.data.ride();
      final RideGroupDto b = ride.groups.firstWhere(
        (RideGroupDto g) => g.name == 'B',
      );
      ParticipantsSheet.open(
        context,
        ride,
        widget.empty
            ? b.copyWith(countParticipants: 0, participants: const [])
            : b,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

ListCase _participants(
  String id, {
  ListMode mode = ListMode.full,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) => ListCase(
  id,
  page: (GalleryData d) =>
      _ParticipantsHost(data: d, empty: mode == ListMode.empty),
  steps: steps,
  loaded: loaded,
  api: (GalleryData d) {
    final ListFixture<PublicUserDto> fixture = ListFixture<PublicUserDto>(
      items: d.participants,
      total: ListTotals.participants,
      isFiltered: (GalleryRequest r) => r.any(<String>['search']),
      matches: (GalleryRequest r, PublicUserDto p) =>
          textMatches(r.text('search'), <String?>[p.displayName]),
    );
    return <GalleryRoute>[
      GalleryRoute.get(
        '/api/teams/{teamSlug}/rides/{rideSlug}/participants',
        (GalleryRequest r) => fixture.list(
          r,
          mode,
          (List<PublicUserDto> page, int total) => ParticipantListResponse(
            participants: page,
            total: total,
            page: r.page,
            size: r.size,
          ),
        ),
      ),
      ..._common(d),
    ];
  },
);

const List<ListStep> _searchMa = <ListStep>[
  ListEnterText(ListTarget.field(), 'ma'),
];

final List<ListCase> _inscritsCases = <ListCase>[
  _participants('inscrits-repos', loaded: 'Malo Guérin'),
  _participants('inscrits-filtre', steps: _searchMa, loaded: 'Malo Guérin'),
  _participants('inscrits-vide', mode: ListMode.empty),
  _participants(
    'inscrits-vide-filtre',
    mode: ListMode.emptyFiltered,
    steps: _searchMa,
  ),
  _participants('inscrits-erreur', mode: ListMode.error),
];

// ───────────────────────────────────────────────────────── notifications

ListCase _notifications(
  String id, {
  ListMode mode = ListMode.full,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) => ListCase(
  id,
  page: (_) => const NotificationsPage(),
  steps: steps,
  loaded: loaded,
  api: (GalleryData d) {
    final ListFixture<NotificationDto> fixture = ListFixture<NotificationDto>(
      items: d.notifications,
      total: ListTotals.notifications,
      isFiltered: (GalleryRequest r) => r.text('unreadOnly') == 'true',
      matches: (GalleryRequest r, NotificationDto n) => !n.read,
    );
    return <GalleryRoute>[
      // La cloche suit la boîte : rien à lire quand elle est vide.
      GalleryRoute.get(
        '/api/notifications/unread-count',
        (_) =>
            GalleryJson(UnreadCountDto(count: mode == ListMode.full ? 2 : 0)),
      ),
      GalleryRoute.get(
        '/api/notifications',
        (GalleryRequest r) => fixture.list(
          r,
          mode,
          (List<NotificationDto> page, int total) => NotificationListResponse(
            items: page,
            total: total,
            unreadCount: mode == ListMode.full ? 2 : 0,
            page: r.page,
            size: r.size,
          ),
        ),
      ),
      ..._common(d),
    ];
  },
);

final List<ListStep> _unreadOnly = <ListStep>[
  ListTap(ListTarget.key(keys.notifications.filterUnread)),
];

final List<ListCase> _notificationsCases = <ListCase>[
  _notifications('notifications-repos', loaded: 'Sortie récupération'),
  _notifications('notifications-filtre', steps: _unreadOnly, loaded: kRideName),
  _notifications('notifications-vide', mode: ListMode.empty),
  _notifications(
    'notifications-vide-filtre',
    mode: ListMode.emptyFiltered,
    steps: _unreadOnly,
  ),
  _notifications('notifications-erreur', mode: ListMode.error),
];

// ───────────────────────────────────────────────────────────── modèles

ListCase _templates(
  String id, {
  ListMode mode = ListMode.full,
  List<ListStep> steps = const <ListStep>[],
  String? loaded,
}) => ListCase(
  id,
  page: (_) => RideTemplateListPage(teamSlug: _vcm),
  steps: steps,
  loaded: loaded,
  api: (GalleryData d) {
    final ListFixture<RideTemplateDto> fixture = ListFixture<RideTemplateDto>(
      items: d.templates,
      total: ListTotals.templates,
      isFiltered: (GalleryRequest r) => r.any(<String>['search']),
      matches: (GalleryRequest r, RideTemplateDto t) =>
          textMatches(r.text('search'), <String?>[t.name, t.markdown]),
    );
    return <GalleryRoute>[
      GalleryRoute.get(
        '/api/teams/{teamSlug}/ride-templates',
        (GalleryRequest r) => fixture.list(
          r,
          mode,
          (List<RideTemplateDto> page, int total) => RideTemplateListResponse(
            templates: page,
            total: total,
            page: r.page,
            size: r.size,
          ),
        ),
      ),
      ..._common(d),
    ];
  },
);

const List<ListStep> _searchMonts = <ListStep>[
  ListEnterText(ListTarget.field(), 'monts'),
];

final List<ListCase> _modelesCases = <ListCase>[
  _templates('modeles-repos', loaded: 'Sortie du dimanche'),
  _templates('modeles-filtre', steps: _searchMonts, loaded: 'trois groupes'),
  _templates('modeles-vide', mode: ListMode.empty),
  _templates(
    'modeles-vide-filtre',
    mode: ListMode.emptyFiltered,
    steps: _searchMonts,
  ),
  _templates('modeles-erreur', mode: ListMode.error),
];

// ─────────────────────────────────────────────────────────────── sommaire

final List<ListSection> kListSections = <ListSection>[
  ListSection(id: 'accueil', title: 'Fil d’accueil', cases: _accueilCases),
  ListSection(
    id: 'publications',
    title: 'Publications d’une équipe',
    cases: _publicationsCases,
  ),
  ListSection(
    id: 'agenda',
    title: 'Agenda d’une équipe',
    cases: _agendaCases,
    omitted: const <String, String>{
      'agenda-criteres':
          'l’Agenda de l’app n’a pas de feuille de filtres : période, vue, '
          'type et tags sont en ligne dans sa barre épinglée.',
    },
  ),
  ListSection(id: 'calendrier', title: 'Calendrier', cases: _calendrierCases),
  ListSection(
    id: 'parcours',
    title: 'Parcours d’une équipe',
    cases: _parcoursCases,
  ),
  ListSection(
    id: 'explorer',
    title: 'Tous les parcours',
    cases: _explorerCases,
  ),
  ListSection(
    id: 'annonces',
    title: 'Annonces d’une équipe',
    cases: _annoncesCases,
    omitted: const <String, String>{
      'annonces-criteres':
          'les Annonces de l’app n’ont pas de feuille de filtres : recherche, '
          'tri, type et tags sont en ligne dans leur barre épinglée (la feuille '
          'de tri est le cas annonces-tri).',
    },
  ),
  ListSection(
    id: 'equipes',
    title: 'Mes équipes, découvrir',
    cases: _equipesCases,
  ),
  ListSection(
    id: 'membres',
    title: 'Membres d’une équipe',
    cases: _membresCases,
  ),
  ListSection(
    id: 'inscrits',
    title: 'Personnes inscrites',
    cases: _inscritsCases,
  ),
  ListSection(
    id: 'notifications',
    title: 'Notifications',
    cases: _notificationsCases,
  ),
  ListSection(id: 'modeles', title: 'Modèles de sortie', cases: _modelesCases),
];
