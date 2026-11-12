// Les données fixes de la galerie des listes — page de DEBUG.
//
// Ce sont celles de la galerie des cartes (`card_gallery/gallery_data.dart`),
// mêmes équipes, mêmes personnes, mêmes objets, étendues de ce qu'une liste
// demande en plus : trois éléments par liste au repos, un total plus grand
// que la page (cahier `audit-listes/galerie.md`, § Données).

import '../../api/generated/export.dart';
import '../card_gallery/gallery_data.dart';

/// Les totaux annoncés au repos : plus grands que la page de trois éléments,
/// pour que compteur et pied de liste soient visibles.
/// [teams] dans l'ordre que le serveur rend pour [sortBy] : par nom, ou par
/// nombre de membres, du plus grand au plus petit.
List<TeamDetailDto> sortedTeams(List<TeamDetailDto> teams, TeamSortBy sortBy) =>
    <TeamDetailDto>[...teams]..sort(
      (TeamDetailDto a, TeamDetailDto b) => sortBy == TeamSortBy.memberCount
          ? b.memberCount.compareTo(a.memberCount)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

abstract final class ListTotals {
  static const int feed = 47;
  static const int posts = 47;
  static const int agenda = 18;
  static const int past = 36;

  /// Le fil d'accueil en deux sections : « À venir », puis « Plus tôt »
  /// (règle RL15).
  static const int homeUpcoming = 12;
  static const int homeEarlier = 35;
  static const int routes = 47;
  static const int explore = 47;

  /// Plus de mille : vérifie le format des nombres (« 2 585 »).
  static const int ads = 2585;
  static const int myTeams = 5;
  static const int discover = 47;

  /// Les 24 membres du Vélo Club des Monts.
  static const int members = 24;

  /// Le groupe B : 11 personnes inscrites, dont 8 sur la première page.
  static const int participants = 11;
  static const int notifications = 47;
  static const int templates = 12;
}

extension ListGalleryData on GalleryData {
  // ─────────────────────────────────────────────────────────────── équipes

  /// Le Vélo Club des Monts vu de Camille : organisatrice par défaut, membre
  /// simple pour les cas `-lecture`.
  TeamDetailDto clubDesMonts({String role = 'ORGANIZER'}) =>
      teamDetail(clubDesMonts: true, role: role);

  /// Le Vélo Club des Monts au trombinoscope ouvert : les chips de rôle de la
  /// liste des membres ne s'offrent qu'à un admin ou à un annuaire ouvert.
  TeamDetailDto clubDesMontsDirectory() =>
      clubDesMonts().copyWith(enableMemberDirectory: true);

  /// Mes équipes : le Vélo Club des Monts (organisatrice), Gravel Bretagne
  /// (membre) et les Rouleurs du Léon (membre).
  List<TeamDetailDto> get myTeams => <TeamDetailDto>[
    clubDesMonts(),
    teamDetail(clubDesMonts: false, role: 'MEMBER'),
    _rouleurs(role: 'MEMBER'),
  ];

  /// L'annuaire, par nombre de membres : Gravel Bretagne, les Cyclos de
  /// Morlaix (pas membre), le Vélo Club des Monts.
  List<TeamDetailDto> get discoverTeams => <TeamDetailDto>[
    teamDetail(clubDesMonts: false, role: 'MEMBER'),
    _cyclosMorlaix(),
    clubDesMonts(),
  ];

  TeamDetailDto _rouleurs({String? role}) =>
      teamDetail(clubDesMonts: false, role: role).copyWith(
        id: 't-leon',
        name: 'Les Rouleurs du Léon',
        slug: 'rouleurs-du-leon',
        memberCount: 38,
        routeCount: 21,
        excerpt:
            'Route le dimanche matin, de Landerneau à la côte des Légendes.',
      );

  TeamDetailDto _cyclosMorlaix() => teamDetail(clubDesMonts: false).copyWith(
    id: 't-morlaix',
    name: 'Cyclos de Morlaix',
    slug: 'cyclos-de-morlaix',
    memberCount: 64,
    routeCount: 40,
    excerpt: 'Cyclotourisme en baie de Morlaix, trois allures chaque samedi.',
  );

  // ─────────────────────────────────────────────────────────────── fil

  /// Le fil d'accueil : une sortie, un voyage, une publication.
  List<PublicationDto> get feedItems => <PublicationDto>[
    feedRide(),
    feedTrip(),
    feedPost(),
  ];

  /// « À venir » au fil d'accueil : la sortie récupération (demain), la
  /// boucle des Monts d'Arrée, la Traversée du Morvan — du plus proche au plus
  /// lointain.
  List<PublicationDto> get homeUpcoming => <PublicationDto>[
    feedRide(
      slug: 'sortie-recuperation',
      name: 'Sortie récupération',
      dateTime: at(1, 18, 30),
      withRoute: false,
      commentCount: 0,
    ),
    feedRide(),
    feedTrip(),
  ];

  /// « Plus tôt » au fil d'accueil : la publication, puis une sortie finie —
  /// du plus récent au plus ancien.
  List<PublicationDto> get homeEarlier => <PublicationDto>[
    feedPost(),
    feedRide(
      slug: 'tour-du-lac-du-drennec',
      name: 'Tour du lac du Drennec',
      dateTime: at(-3, 9),
      finished: true,
    ),
  ];

  // ───────────────────────────────────────────────────────── publications

  static const List<TagWithUsageDto> postTags = <TagWithUsageDto>[
    TagWithUsageDto(
      id: 'tag-recit',
      label: 'Récit',
      color: 'grape',
      type: 'POST',
      usageCount: 9,
    ),
    TagWithUsageDto(
      id: 'tag-club',
      label: 'Vie du club',
      color: 'blue',
      type: 'POST',
      usageCount: 14,
    ),
  ];

  /// Trois publications de l'équipe, la plus récente d'abord. La deuxième,
  /// « Les Monts d'Arrée sous la neige », répond à la recherche « monts » et
  /// porte le tag « Récit » (cas `publications-filtre`).
  List<PublicationDto> get posts => <PublicationDto>[
    feedPost(),
    feedPost().copyWith(
      id: 'post-neige',
      slug: 'monts-d-arree-sous-la-neige',
      name: 'Les Monts d’Arrée sous la neige',
      dateTime: at(-6, 17),
      createdAt: at(-6, 17),
      createdBy: GalleryData.karim,
      commentCount: 7,
      thumbnailUrl: null,
      excerpt:
          'Récit de la sortie de dimanche : verglas au Roc’h Trévézel, '
          'demi-tour à Commana et chocolat chaud pour tout le monde.',
      tags: const <TagDto>[
        TagDto(id: 'tag-recit', label: 'Récit', color: 'grape'),
      ],
    ),
    feedPost().copyWith(
      id: 'post-ag',
      slug: 'assemblee-generale',
      name: 'Assemblée générale de décembre',
      dateTime: at(-9, 20),
      createdAt: at(-9, 20),
      createdBy: GalleryData.ines,
      commentCount: 0,
      thumbnailUrl: null,
      excerpt: 'Ordre du jour, procurations et calendrier de la saison.',
      tags: const <TagDto>[
        TagDto(id: 'tag-club', label: 'Vie du club', color: 'blue'),
      ],
    ),
  ];

  // ─────────────────────────────────────────────────────────────── agenda

  /// L'agenda à venir : la boucle des Monts d'Arrée (Camille au B), la
  /// sortie récupération, la Traversée du Morvan.
  List<PublicationDto> get agendaUpcoming => <PublicationDto>[
    feedRide(
      slug: 'sortie-recuperation',
      name: 'Sortie récupération',
      dateTime: at(1, 18, 30),
      withRoute: false,
      commentCount: 0,
    ),
    feedRide(registeredIn: 'B'),
    feedTrip(),
  ];

  /// L'agenda passé, le plus récent d'abord.
  List<PublicationDto> get agendaPast => <PublicationDto>[
    feedRide(
      slug: 'tour-du-lac-du-drennec',
      name: 'Tour du lac du Drennec',
      dateTime: at(-2, 9),
      finished: true,
    ),
    feedRide(
      slug: 'sortie-nocturne',
      name: 'Sortie nocturne de Huelgoat',
      dateTime: at(-9, 19),
      finished: true,
      commentCount: 5,
    ),
    feedTrip(finished: true),
  ];

  // ─────────────────────────────────────────────────────────── calendrier

  /// Les cinq événements du mois : ceux de « Cette semaine » (galerie des
  /// cartes), ramenés dans le mois en cours quand la semaine en déborde.
  List<CalendarEventDto> get monthEvents {
    final DateTime today = DateTime.parse(at(0, 12)).toUtc();
    final DateTime lastOfMonth = DateTime.utc(today.year, today.month + 1, 0);
    final bool spills = today.add(const Duration(days: 6)).isAfter(lastOfMonth);
    if (!spills) return weekEvents;
    // La semaine déborde sur le mois suivant : les mêmes cinq, une semaine
    // plus tôt.
    return <CalendarEventDto>[
      for (final CalendarEventDto e in weekEvents)
        e.copyWith(
          start: DateTime.parse(e.start)
              .subtract(const Duration(days: 7))
              .toUtc()
              .toIso8601String(),
          end: e.end == null
              ? null
              : DateTime.parse(e.end!)
                    .subtract(const Duration(days: 7))
                    .toUtc()
                    .toIso8601String(),
        ),
    ];
  }

  /// Les mêmes cinq événements, cinq semaines plus tard : le mois courant est
  /// vide, un mois suivant ne l'est pas (cas `calendrier-vide`).
  List<CalendarEventDto> get laterMonthEvents => <CalendarEventDto>[
    for (final CalendarEventDto e in monthEvents)
      e.copyWith(
        start: DateTime.parse(e.start)
            .add(const Duration(days: 35))
            .toUtc()
            .toIso8601String(),
        end: e.end == null
            ? null
            : DateTime.parse(e.end!)
                  .add(const Duration(days: 35))
                  .toUtc()
                  .toIso8601String(),
      ),
  ];

  /// Le mois où seul figure l'étape du voyage : le filtre « Sorties » n'y
  /// trouve rien.
  List<CalendarEventDto> get monthStagesOnly => <CalendarEventDto>[
    for (final CalendarEventDto e in monthEvents)
      if (e.type == 'TRIP_STAGE') e,
  ];

  // ─────────────────────────────────────────────────────────────── parcours

  static const List<TagWithUsageDto> routeTagVocabulary = <TagWithUsageDto>[
    TagWithUsageDto(
      id: 'tag-vallonne',
      label: 'vallonné',
      color: 'teal',
      type: 'ROUTE',
      usageCount: 11,
    ),
    TagWithUsageDto(
      id: 'tag-finistere',
      label: 'Finistère',
      color: 'blue',
      type: 'ROUTE',
      usageCount: 30,
    ),
  ];

  /// Trois parcours de l'équipe. Le filtre « 50–100 km, vallonné » retient
  /// les deux premiers.
  List<RouteDto> get teamRoutes => <RouteDto>[
    route(),
    route(
      slug: 'monts-d-arree-b',
      name: 'Monts d’Arrée, parcours B',
      distance: 78000,
      elevationGain: 980,
      tags: const <TagDto>[
        TagDto(id: 'tag-vallonne', label: 'vallonné', color: 'teal'),
      ],
    ),
    route(
      slug: 'tour-du-lac-du-drennec',
      name: 'Tour du lac du Drennec',
      distance: 54000,
      elevationGain: 610,
      thumbnail: false,
      tags: const <TagDto>[
        TagDto(id: 'tag-finistere', label: 'Finistère', color: 'blue'),
      ],
    ),
  ];

  /// Tous les parcours : deux du Vélo Club des Monts, un gravel de Gravel
  /// Bretagne. « Route » écarte ce dernier.
  List<RouteDto> get exploreRoutes => <RouteDto>[
    route(),
    route(
      slug: 'landes-du-cragou',
      name: 'Landes du Cragou',
      distance: 64000,
      elevationGain: 870,
      surfaceType: 'GRAVEL',
      tags: const <TagDto>[],
    ).copyWith(team: GalleryData.gravel),
    route(
      slug: 'tour-du-lac-du-drennec',
      name: 'Tour du lac du Drennec',
      distance: 54000,
      elevationGain: 610,
      thumbnail: false,
      tags: const <TagDto>[
        TagDto(id: 'tag-finistere', label: 'Finistère', color: 'blue'),
      ],
    ),
  ];

  // ─────────────────────────────────────────────────────────────── annonces

  /// Une vente, une location, une recherche.
  List<AdDto> get ads => <AdDto>[ad('SALE'), ad('RENTAL'), ad('WANTED')];

  // ─────────────────────────────────────────────────────────────── membres

  /// Léa (administratrice), Karim et Camille (organisation).
  List<MemberDto> get members => <MemberDto>[
    member(GalleryData.lea, 'ADMIN', '2021-03-01T10:00:00Z'),
    member(GalleryData.karim, 'ORGANIZER', '2022-04-12T10:00:00Z'),
    member(GalleryData.camille, 'ORGANIZER', '2023-09-03T10:00:00Z'),
  ];

  // ───────────────────────────────────────────────────────────── inscrits

  /// Les huit personnes de la première page du groupe B.
  List<PublicUserDto> get participants => GalleryData.people;

  /// Le groupe B de la boucle des Monts d'Arrée.
  RideGroupDto get groupB => group('B');

  // ───────────────────────────────────────────────────────── notifications

  /// Une non lue, une lue, une modification (non lue).
  List<NotificationDto> get notifications => <NotificationDto>[
    notification('update'),
    notification('unread'),
    notification('read'),
  ];

  // ───────────────────────────────────────────────────────────── modèles

  /// Le modèle du dimanche, celui d'hiver (brouillon) et un troisième qui
  /// répond à la recherche « monts ».
  List<RideTemplateDto> get templates => <RideTemplateDto>[
    template(),
    template().copyWith(
      id: 'tpl-monts',
      slug: 'monts-d-arree-trois-groupes',
      name: 'Monts d’Arrée en trois groupes',
      markdown: 'Le grand tour du Roc’h Trévézel, trois allures.',
      updatedAt: at(-12, 9),
      nextNumber: 4,
    ),
    template(draft: true),
  ];
}
