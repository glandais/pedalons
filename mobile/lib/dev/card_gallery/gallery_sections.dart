// Les sections et les cas de la galerie de cartes — page de DEBUG.
//
// Même ordre que le cahier commun
// (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/galerie.md`,
// § Sections et cas). Chaque cas monte la **carte de production**, dans son
// propre conteneur Riverpod ([GalleryScope]) quand elle lit un fournisseur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../api/generated/export.dart';
import '../../core/theme/pdl_tokens.dart';
import '../../features/ads/presentation/widgets/ad_card.dart';
import '../../features/calendar/presentation/widgets/agenda_card.dart';
import '../../features/comments/data/comment_repository.dart';
import '../../features/comments/presentation/widgets/comment_thread.dart';
import '../../features/home/presentation/widgets/my_teams_section.dart';
import '../../features/home/presentation/widgets/next_ride_card.dart';
import '../../features/home/presentation/widgets/week_agenda_section.dart';
import '../../features/home/providers/next_ride_provider.dart';
import '../../features/home/providers/week_events_provider.dart';
import '../../features/notifications/presentation/widgets/notification_tile.dart';
import '../../features/participants/data/participant_repository.dart';
import '../../features/participants/domain/participant_query.dart';
import '../../features/participants/presentation/widgets/participant_list_view.dart';
import '../../features/profile/presentation/widgets/paired_devices_section.dart';
import '../../features/rides/domain/ride_route_layers.dart';
import '../../features/rides/presentation/widgets/ride_group_card.dart';
import '../../features/rides/presentation/widgets/ride_groups_section.dart';
import '../../features/rides/presentation/widgets/ride_registration_control.dart';
import '../../features/rides/presentation/widgets/templates/ride_template_card.dart';
import '../../features/rides/providers/ride_detail_provider.dart';
import '../../features/rides/providers/ride_group_selection_provider.dart';
import '../../features/routes/presentation/widgets/compact_route_row.dart';
import '../../features/routes/presentation/widgets/route_card.dart';
import '../../features/routes/presentation/widgets/route_usages_section.dart';
import '../../features/routes/providers/route_detail_provider.dart';
import '../../features/teams/data/team_repository.dart';
import '../../features/teams/presentation/pages/team_members_page.dart';
import '../../features/teams/presentation/pages/teams_page.dart';
import '../../features/teams/presentation/widgets/dashboard/dashboard_content.dart';
import '../../features/teams/presentation/widgets/dashboard/dashboard_rides.dart';
import '../../features/teams/presentation/widgets/dashboard/dashboard_todo.dart';
import '../../features/teams/presentation/widgets/pending_invitations_card.dart';
import '../../features/teams/presentation/widgets/publication_card.dart';
import '../../features/teams/presentation/widgets/team_discovery_card.dart';
import '../../features/teams/providers/team_providers.dart';
import '../../features/trips/presentation/widgets/stage_card.dart';
import 'gallery_data.dart';
import 'gallery_scope.dart';

typedef GalleryCaseBuilder = Widget Function(GalleryData data);

/// Un cas : son identifiant (celui du cahier) et sa carte.
class GalleryCase {
  const GalleryCase(this.id, this.build, {this.bleed = false});

  final String id;
  final GalleryCaseBuilder build;

  /// La carte pose elle-même ses marges latérales (une section d'accueil, une
  /// page, une ligne pleine largeur) : la galerie n'en ajoute pas.
  final bool bleed;
}

/// Une section : son identifiant (celui de l'adresse `/dev/cartes/<id>`),
/// son titre, ses cas, et les cas du cahier qu'elle omet, avec la raison.
class GallerySection {
  const GallerySection({
    required this.id,
    required this.title,
    required this.cases,
    this.omitted = const <String, String>{},
  });

  final String id;
  final String title;
  final List<GalleryCase> cases;
  final Map<String, String> omitted;
}

/// Les dix sections, dans l'ordre du cahier.
final List<GallerySection> kGallerySections = <GallerySection>[
  _feed,
  _home,
  _agenda,
  _groups,
  _stages,
  _routes,
  _ads,
  _teams,
  _dashboard,
  _misc,
];

GallerySection? gallerySection(String? id) {
  for (final GallerySection s in kGallerySections) {
    if (s.id == id) return s;
  }
  return null;
}

/// Un cas qui ne lit que la base (session, unités, réseau coupé).
Widget _scoped(
  GalleryData d,
  Widget child, [
  List<Override> overrides = const <Override>[],
]) => GalleryScope(data: d, overrides: overrides, child: child);

void _noop() {}

// ────────────────────────────────────────────────────────────────────── fil

Widget _card(GalleryData d, PublicationDto p) =>
    _scoped(d, PublicationCard(publication: p));

final GallerySection _feed = GallerySection(
  id: 'fil',
  title: 'Fil',
  cases: <GalleryCase>[
    GalleryCase('fil-sortie', (GalleryData d) => _card(d, d.feedRide())),
    GalleryCase(
      'fil-sortie-inscrite',
      (GalleryData d) => _card(d, d.feedRide(registeredIn: 'B')),
    ),
    GalleryCase(
      'fil-sortie-demain',
      (GalleryData d) => _card(
        d,
        d.feedRide(
          slug: 'boucle-demain',
          dateTime: d.at(1, 9),
          endDateTime: d.at(1, 13),
        ),
      ),
    ),
    GalleryCase(
      'fil-sortie-en-cours',
      (GalleryData d) => _card(
        d,
        d.feedRide(
          slug: 'boucle-en-cours',
          dateTime: d.startedToday(),
          endDateTime: d.later(const Duration(hours: 3)),
          // Terminée dès le départ passé, au sens du serveur (`API-16`).
          finished: true,
        ),
      ),
    ),
    GalleryCase(
      'fil-sortie-terminee',
      (GalleryData d) => _card(
        d,
        d.feedRide(
          slug: 'boucle-terminee',
          dateTime: d.at(-2, 9),
          endDateTime: d.at(-2, 13),
          finished: true,
        ),
      ),
    ),
    GalleryCase(
      'fil-sortie-annulee',
      (GalleryData d) =>
          _card(d, d.feedRide(slug: 'boucle-annulee', status: 'CANCELLED')),
    ),
    GalleryCase(
      'fil-sortie-brouillon',
      (GalleryData d) =>
          _card(d, d.feedRide(slug: 'boucle-brouillon', status: 'DRAFT')),
    ),
    GalleryCase(
      'fil-sortie-sans-groupe',
      (GalleryData d) => _card(
        d,
        d.feedRide(
          slug: 'sortie-sans-groupe',
          name: 'Sortie libre du samedi',
          withGroups: false,
          commentCount: 0,
        ),
      ),
    ),
    GalleryCase(
      'fil-sortie-alerte-pluie',
      (GalleryData d) =>
          _card(d, d.feedRide(slug: 'boucle-pluie', rainAlert: true)),
    ),
    GalleryCase('fil-voyage', (GalleryData d) => _card(d, d.feedTrip())),
    GalleryCase(
      'fil-voyage-inscrit-en-cours',
      (GalleryData d) => _card(d, d.feedTrip(underWay: true, registered: true)),
    ),
    GalleryCase(
      'fil-voyage-annule',
      (GalleryData d) => _card(d, d.feedTrip(status: 'CANCELLED')),
    ),
    GalleryCase('fil-publication', (GalleryData d) => _card(d, d.feedPost())),
    GalleryCase(
      'fil-publication-brouillon',
      (GalleryData d) => _card(d, d.feedPost(draft: true)),
    ),
    GalleryCase(
      'fil-supprime',
      (GalleryData d) =>
          _card(d, d.feedRide(slug: 'boucle-supprimee', deleted: true)),
    ),
  ],
);

// ────────────────────────────────────────────────────────────────── accueil

Widget _nextRide(GalleryData d, {bool withMax = true}) {
  final RideDto ride = d.ride(registeredIn: 'B', withMaxInB: withMax);
  return _scoped(
    d,
    NextRideCard(
      next: NextRide(ride: ride, group: ride.registeredGroup),
    ),
  );
}

Widget _week(GalleryData d, List<CalendarEventDto> events) => _scoped(
  d,
  const WeekAgendaSection(),
  <Override>[
    weekEventsProvider.overrideWith((Ref ref) async => events),
    // La sortie de « Ma prochaine sortie » n'est pas répétée dans la semaine :
    // ici aucune, pour que les cinq lignes restent.
    nextRideProvider.overrideWith((Ref ref) async => null),
  ],
);

Widget _myTeams(GalleryData d, List<TeamDetailDto> teams) => _scoped(
  d,
  const MyTeamsSection(),
  <Override>[myTeamsProvider.overrideWith((Ref ref) async => teams)],
);

final GallerySection _home = GallerySection(
  id: 'accueil',
  title: 'Accueil',
  cases: <GalleryCase>[
    GalleryCase('prochaine-sortie', (GalleryData d) => _nextRide(d)),
    GalleryCase(
      'prochaine-sortie-sans-maximum',
      (GalleryData d) => _nextRide(d, withMax: false),
    ),
    GalleryCase(
      'prochaine-sortie-vide',
      (GalleryData d) => const NoNextRideCard(onExplore: _noop),
    ),
    GalleryCase(
      'semaine',
      (GalleryData d) => _week(d, d.weekEvents),
      bleed: true,
    ),
    GalleryCase(
      'semaine-vide',
      (GalleryData d) => _week(d, const <CalendarEventDto>[]),
      bleed: true,
    ),
    GalleryCase(
      'mes-equipes',
      (GalleryData d) => _myTeams(d, <TeamDetailDto>[
        d.teamDetail(clubDesMonts: true, role: 'MEMBER'),
        d.teamDetail(clubDesMonts: false, role: 'ORGANIZER'),
      ]),
      bleed: true,
    ),
    GalleryCase(
      'mes-equipes-vide',
      (GalleryData d) => _myTeams(d, const <TeamDetailDto>[]),
      bleed: true,
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────── agenda

Widget _agendaCard(GalleryData d, CalendarEventDto e) =>
    _scoped(d, AgendaCard(event: e));

final GallerySection _agenda = GallerySection(
  id: 'agenda',
  title: 'Agenda',
  cases: <GalleryCase>[
    GalleryCase(
      'agenda-sortie',
      (GalleryData d) => _agendaCard(
        d,
        d.event(id: 'e-sortie', title: kRideName, start: d.at(4, 9)),
      ),
    ),
    GalleryCase(
      'agenda-inscrite',
      (GalleryData d) => _agendaCard(
        d,
        d.event(
          id: 'e-inscrite',
          title: kRideName,
          start: d.at(4, 9, 30),
          registered: true,
          groupName: 'B',
          distance: 78000,
          elevationGain: 980,
        ),
      ),
    ),
    GalleryCase(
      'agenda-annulee',
      (GalleryData d) => _agendaCard(
        d,
        d.event(
          id: 'e-annulee',
          title: 'Tour du lac du Drennec',
          start: d.at(5, 9),
          entitySlug: 'tour-du-lac-du-drennec',
          status: 'CANCELLED',
          distance: 54000,
          elevationGain: 610,
        ),
      ),
    ),
    GalleryCase(
      'agenda-etape',
      (GalleryData d) => _agendaCard(d, d.stageEvent()),
    ),
    GalleryCase(
      'agenda-passee',
      (GalleryData d) => _agendaCard(
        d,
        d.event(
          id: 'e-passee',
          title: kRideName,
          start: d.at(-2, 9),
          entitySlug: 'boucle-terminee',
          finished: true,
        ),
      ),
    ),
  ],
);

// ────────────────────────────────────────────────────────────────── groupes

/// La section « Groupes » de la sortie, telle que son écran la monte.
Widget _groupsSection(GalleryData d, RideDto ride) {
  final RideKey key = RideKey(teamSlug: ride.team.slug, rideSlug: ride.slug);
  final RideGroupDto selected = ride.groups.firstWhere(
    (RideGroupDto g) => g.id == ride.registeredGroupId,
    orElse: () => ride.groups.first,
  );
  return _scoped(
    d,
    RideGroupsSection(
      rideKey: key,
      ride: ride,
      selectedRouteSlug: selected.routeSlug ?? ride.routeSlug,
      onSelect: (String _) {},
      weather: d.rideWeather(ride),
      onOpenGroup: (RideGroupDto _) {},
      onShowParticipants: (RideGroupDto _) {},
      onShowRideParticipants: _noop,
    ),
    <Override>[
      rideDetailProvider(key).overrideWith((Ref ref) async => ride),
      // Les tracés ne servent qu'au bouton « GPS » : rien à charger.
      rideRouteGeometriesProvider(key)
          .overrideWith((Ref ref) => RideRouteGeometriesController(ref, key)),
    ],
  );
}

/// Une carte de groupe seule, son action calculée comme la section le fait.
Widget _groupCard(GalleryData d, RideDto ride, RideGroupDto group) =>
    RideGroupCard(
      group: group,
      rideDateTime: ride.dateTime,
      timezone: ride.timezone,
      showDeparture: false,
      action: rideRegistrationControlAction(
        ride: ride,
        group: group,
        canRegister: ride.permissions.canRegister ?? false,
      ),
      trackColor: multiTrackColor(groupTrackColorIndex(ride, group)),
      units: UnitSystem.metric,
      currentUserId: GalleryData.camille.id,
      weatherLeg: null,
      onTap: _noop,
      onJoin: _noop,
      onShowParticipants: _noop,
    );

final GallerySection _groups = GallerySection(
  id: 'groupes',
  title: 'Groupes',
  cases: <GalleryCase>[
    GalleryCase(
      'groupes-inscrite-b',
      (GalleryData d) => _groupsSection(d, d.ride(registeredIn: 'B')),
    ),
    GalleryCase(
      'groupes-non-inscrite',
      (GalleryData d) => _groupsSection(d, d.ride(sameTime: true)),
    ),
    GalleryCase('groupe-sans-parcours', (GalleryData d) {
      final RideDto ride = d.ride(sameTime: true);
      return _groupCard(
        d,
        ride,
        d.group('B', sameTime: true, withRoute: false),
      );
    }),
    GalleryCase('groupe-sans-meteo', (GalleryData d) {
      final RideDto ride = d.ride(sameTime: true);
      return _groupCard(d, ride, ride.groups.first);
    }),
  ],
);

// ─────────────────────────────────────────────────────────────────── étapes

Widget _stage(
  GalleryData d,
  TripStageDto stage,
  RideWeatherSummaryDto? weather,
) => _scoped(
  d,
  StageCard(stage: stage, selected: false, onTap: _noop, weather: weather),
);

final GallerySection _stages = GallerySection(
  id: 'etapes',
  title: 'Étapes',
  cases: <GalleryCase>[
    GalleryCase(
      'etapes',
      (GalleryData d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final int i in <int>[1, 2, 3]) ...<Widget>[
            if (i > 1) const SizedBox(height: PdlSpacing.feedGap),
            _stage(d, d.stage(i), d.weather()),
          ],
        ],
      ),
    ),
    GalleryCase(
      'etape-sans-parcours',
      (GalleryData d) =>
          _stage(d, d.stage(2, withRoute: false, withSpeed: false), null),
    ),
    GalleryCase(
      'etape-alerte-pluie',
      (GalleryData d) => _stage(d, d.stage(1), d.weather(rainAlert: true)),
    ),
  ],
);

// ───────────────────────────────────────────────────────────────── parcours

final GallerySection _routes = GallerySection(
  id: 'parcours',
  title: 'Parcours',
  cases: <GalleryCase>[
    GalleryCase(
      'parcours',
      (GalleryData d) => _scoped(d, RouteCard(route: d.route())),
    ),
    GalleryCase(
      'parcours-sans-vignette',
      (GalleryData d) => _scoped(
        d,
        RouteCard(
          route: d.route(slug: 'parcours-sans-vignette', thumbnail: false),
        ),
      ),
    ),
    GalleryCase(
      'parcours-supprime',
      (GalleryData d) => _scoped(
        d,
        RouteCard(route: d.route(slug: 'parcours-supprime', deleted: true)),
      ),
    ),
    GalleryCase(
      'parcours-ligne',
      (GalleryData d) =>
          _scoped(d, CompactRouteRow(route: d.route(slug: 'parcours-ligne'))),
    ),
    GalleryCase('usages', (GalleryData d) {
      final RouteKey key = RouteKey(
        teamSlug: GalleryData.vcm.slug,
        routeSlug: kRouteSlug,
      );
      return _scoped(d, RouteUsagesSection(routeKey: key), <Override>[
        routeUsagesProvider(key).overrideWith(
          (Ref ref) async => <RouteUsageDto>[
            RouteUsageDto(
              type: 'RIDE',
              slug: kRideSlug,
              name: kRideName,
              dateTime: d.at(4, 9),
              timezone: kGalleryZone,
              teamSlug: GalleryData.vcm.slug,
              referencedDirectly: false,
              viaChildNames: const <String>['A'],
            ),
            RouteUsageDto(
              type: 'TRIP',
              slug: kTripSlug,
              name: kTripName,
              dateTime: d.at(10, 8, 30),
              endDate: d.at(12, 9),
              timezone: kGalleryZone,
              teamSlug: GalleryData.vcm.slug,
              referencedDirectly: false,
              viaChildNames: const <String>['Autun → Château-Chinon'],
            ),
          ],
        ),
      ]);
    }),
  ],
);

// ───────────────────────────────────────────────────────────────── annonces

final GallerySection _ads = GallerySection(
  id: 'annonces',
  title: 'Annonces',
  cases: <GalleryCase>[
    GalleryCase('annonce-vente', (GalleryData d) => AdCard(ad: d.ad('SALE'))),
    GalleryCase(
      'annonce-location',
      (GalleryData d) => AdCard(ad: d.ad('RENTAL')),
    ),
    GalleryCase(
      'annonce-recherche',
      (GalleryData d) => AdCard(ad: d.ad('WANTED')),
    ),
    GalleryCase(
      'annonce-brouillon',
      (GalleryData d) => AdCard(ad: d.ad('SALE', draft: true)),
    ),
  ],
);

// ────────────────────────────────────────────────────────────────── équipes

/// Le défilement d'une page montée dans la galerie : à elle seule, pour ne
/// pas s'accrocher à celui de la galerie.
class _OwnScroll extends StatefulWidget {
  const _OwnScroll({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  State<_OwnScroll> createState() => _OwnScrollState();
}

class _OwnScrollState extends State<_OwnScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: PrimaryScrollController(
      controller: _controller,
      child: widget.child,
    ),
  );
}

/// `_TeamCard` est privée à l'onglet Équipes : la galerie monte l'onglet
/// lui-même, avec une seule équipe, dans un cadre de hauteur fixe.
Widget _teamsTab(GalleryData d, String role) =>
    _scoped(d, const _OwnScroll(height: 180, child: TeamsPage()), <Override>[
      // Une valeur déjà là : l'onglet ne passe pas par son squelette de
      // chargement, trois cartes qui débordent du cadre.
      myTeamsProvider.overrideWithValue(
        AsyncData<List<TeamDetailDto>>(<TeamDetailDto>[
          d.teamDetail(clubDesMonts: true, role: role),
        ]),
      ),
      myInvitationsProvider.overrideWithValue(
        const AsyncData<List<MyInvitationDto>>(<MyInvitationDto>[]),
      ),
    ]);

/// `_MemberRow` est privée au trombinoscope : la galerie monte la page, avec
/// un seul membre, dans un cadre de hauteur fixe.
Widget _membersPage(GalleryData d, MemberDto member) => _scoped(
  d,
  _OwnScroll(
    height: 236,
    child: TeamMembersPage(teamSlug: GalleryData.vcm.slug, rolesShown: false),
  ),
  <Override>[
    teamRepositoryProvider.overrideWithValue(
      GalleryTeamRepository(<MemberDto>[member]),
    ),
  ],
);

final GallerySection _teams = GallerySection(
  id: 'equipes',
  title: 'Équipes',
  cases: <GalleryCase>[
    GalleryCase(
      'equipe',
      (GalleryData d) => _teamsTab(d, 'MEMBER'),
      bleed: true,
    ),
    GalleryCase(
      'equipe-admin',
      (GalleryData d) => _teamsTab(d, 'ADMIN'),
      bleed: true,
    ),
    GalleryCase(
      'equipe-decouverte',
      (GalleryData d) => TeamDiscoveryCard(
        team: d.teamDetail(clubDesMonts: false),
        onJoin: _noop,
      ),
    ),
    GalleryCase(
      'invitations',
      (GalleryData d) => _scoped(d, const PendingInvitationsCard(), <Override>[
        myInvitationsProvider.overrideWith(
          (Ref ref) async => <MyInvitationDto>[d.invitation],
        ),
      ]),
      bleed: true,
    ),
    GalleryCase(
      'membre',
      (GalleryData d) => _membersPage(
        d,
        d.member(GalleryData.noe, 'MEMBER', '2024-03-03T10:00:00Z'),
      ),
      bleed: true,
    ),
    GalleryCase(
      'membre-admin',
      (GalleryData d) => _membersPage(
        d,
        d.member(GalleryData.lea, 'ADMIN', '2021-03-01T10:00:00Z'),
      ),
      bleed: true,
    ),
    GalleryCase(
      'inscrits',
      (GalleryData d) => _scoped(
        d,
        ParticipantListView(
          source: RideParticipantSource(
            teamSlug: GalleryData.vcm.slug,
            rideSlug: kRideSlug,
            groupId: 'g-a',
          ),
          count: GalleryData.people.length,
          organizerId: GalleryData.lea.id,
          team: GalleryData.vcm,
        ),
        <Override>[
          participantRepositoryProvider.overrideWithValue(
            const GalleryParticipantRepository(GalleryData.people),
          ),
        ],
      ),
      bleed: true,
    ),
  ],
);

// ───────────────────────────────────────────────────────── tableau de bord

final GallerySection _dashboard = GallerySection(
  id: 'tableau',
  title: 'Tableau de bord',
  cases: <GalleryCase>[
    GalleryCase(
      'a-traiter',
      (GalleryData d) => DashboardTodo(
        teamSlug: GalleryData.vcm.slug,
        data: d.organizerDashboard,
      ),
    ),
    GalleryCase(
      'mes-sorties',
      (GalleryData d) => _scoped(
        d,
        DashboardMyUpcoming(
          list: d.list(<PublicationDto>[
            d.feedRide(registeredIn: 'B'),
            d.feedTrip(registered: true),
          ]),
          onViewAll: _noop,
        ),
      ),
    ),
    GalleryCase(
      'sortie-a-venir',
      (GalleryData d) =>
          _scoped(d, DashboardRideCard(ride: d.feedRide(), canEdit: false)),
    ),
    GalleryCase(
      'sortie-a-venir-inscrite',
      (GalleryData d) => _scoped(
        d,
        DashboardRideCard(ride: d.feedRide(registeredIn: 'B'), canEdit: false),
      ),
    ),
    GalleryCase(
      'sortie-a-venir-complet',
      (GalleryData d) => _scoped(
        d,
        DashboardRideCard(ride: d.feedRide(allFull: true), canEdit: false),
      ),
    ),
    GalleryCase(
      'sortie-a-venir-sans-parcours',
      (GalleryData d) => _scoped(
        d,
        DashboardRideCard(
          ride: d.feedRide(
            slug: 'sortie-recuperation',
            name: 'Sortie récupération',
            dateTime: d.at(1, 18, 30),
            withRoute: false,
          ),
          canEdit: false,
        ),
      ),
    ),
    GalleryCase(
      'dernieres-publications',
      (GalleryData d) => DashboardLatestPosts(
        list: d.list(<PublicationDto>[d.feedPost()]),
        onViewAll: _noop,
      ),
    ),
    GalleryCase(
      'nouveaux-parcours',
      (GalleryData d) => _scoped(
        d,
        DashboardNewRoutes(
          list: RouteListResponse(
            routes: <RouteDto>[
              d.route(),
              d.route(
                slug: 'monts-d-arree-b',
                name: 'Monts d’Arrée, parcours B',
                distance: 78000,
                elevationGain: 980,
                tags: const <TagDto>[],
              ),
            ],
            total: 2,
            page: 0,
            size: 5,
          ),
          onViewAll: _noop,
        ),
      ),
    ),
    GalleryCase(
      'annonces-tableau',
      (GalleryData d) => DashboardLatestAds(
        list: AdListResponse(
          ads: <AdDto>[d.ad('SALE'), d.ad('RENTAL'), d.ad('WANTED')],
          total: 3,
          page: 0,
          size: 5,
        ),
        onViewAll: _noop,
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────── divers

final GallerySection _misc = GallerySection(
  id: 'divers',
  title: 'Divers',
  cases: <GalleryCase>[
    GalleryCase(
      'notification-non-lue',
      (GalleryData d) => NotificationTile(
        notification: d.notification('unread'),
        onTap: _noop,
      ),
      bleed: true,
    ),
    GalleryCase(
      'notification-lue',
      (GalleryData d) =>
          NotificationTile(notification: d.notification('read'), onTap: _noop),
      bleed: true,
    ),
    GalleryCase(
      'notification-modification',
      (GalleryData d) => NotificationTile(
        notification: d.notification('updated'),
        onTap: _noop,
      ),
      bleed: true,
    ),
    GalleryCase(
      'modele',
      (GalleryData d) =>
          RideTemplateCard(template: d.template(), onTap: _noop, onMore: _noop),
    ),
    GalleryCase(
      'modele-brouillon',
      (GalleryData d) => RideTemplateCard(
        template: d.template(draft: true),
        onTap: _noop,
        onMore: _noop,
      ),
    ),
    GalleryCase(
      'appareils',
      (GalleryData d) => _scoped(d, const PairedDevicesCard(), <Override>[
        pairedDevicesProvider.overrideWith((Ref ref) async => d.pairedDevices),
      ]),
    ),
    GalleryCase('commentaires', (GalleryData d) {
      const CommentTarget target = CommentTarget(
        entity: CommentEntity.ride,
        teamSlug: 'velo-club-des-monts',
        slug: kRideSlug,
      );
      return _scoped(
        d,
        const CommentThread(target: target, canComment: false),
        <Override>[
          commentRepositoryProvider.overrideWithValue(
            GalleryCommentRepository(d.comments),
          ),
          myTeamsProvider.overrideWith(
            (Ref ref) async => <TeamDetailDto>[
              d.teamDetail(clubDesMonts: true, role: 'MEMBER'),
            ],
          ),
        ],
      );
    }),
  ],
);
