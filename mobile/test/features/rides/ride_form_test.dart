import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/rides/domain/ride_form.dart';

import 'ride_fixtures.dart';

/// Le formulaire de l'éditeur de sortie (ledger `MOB-80`) : ce qu'il envoie
/// doit être ce que le site envoie (`rideToRequest`, `templateForNewRide`),
/// parce que le PUT applique **tous** les champs, absents compris.
void main() {
  setUpAll(() {
    // Charge la base des fuseaux : un fuseau inconnu retomberait sur celui
    // de la machine qui lance les tests.
    AppFormatters.timezoneNames();
  });

  TeamDetailDto team({String visibility = 'PUBLIC'}) => TeamDetailDto(
    timezone: 'Europe/Paris',
    id: 't1',
    slug: 'n-peloton',
    name: 'N-Peloton',
    about: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    visibility: visibility,
    enableTrips: true,
    enableAds: true,
    enablePosts: true,
    enableRides: true,
    enableRoutes: true,
    visibilityEditable: true,
    joinable: true,
    addMemberAllowed: true,
    enableMemberDirectory: false,
    postsAsTeamByDefault: true,
    enableRoutePlanner: false,
    memberCount: 40,
    upcomingRideCount: 3,
    routeCount: 12,
    upcomingTripCount: 0,
    recentPostCount: 0,
    createdAt: '2024-01-01T00:00:00Z',
  );

  group('heures murales', () {
    test('un instant UTC se réécrit dans le fuseau de la sortie', () {
      // 06:00 Z en octobre : 08:00 à Paris (UTC+2).
      expect(
        instantToWallTime('2026-10-11T06:00:00Z', 'Europe/Paris'),
        '2026-10-11T08:00:00',
      );
      expect(
        instantToWallTime('2026-10-11T06:00:00Z', 'Asia/Tokyo'),
        '2026-10-11T15:00:00',
      );
    });

    test('dimanche prochain 8 h, J+7 un dimanche, sur les champs', () {
      // Mercredi 14 octobre 2026, 10:00 Z.
      expect(
        nextWeekdayWallTime(
          DateTime.sunday,
          8,
          'Europe/Paris',
          now: DateTime.utc(2026, 10, 14, 10),
        ),
        '2026-10-18T08:00:00',
      );
      // Un dimanche : celui de la semaine suivante, comme au site.
      expect(
        nextWeekdayWallTime(
          DateTime.sunday,
          8,
          'Europe/Paris',
          now: DateTime.utc(2026, 10, 18, 10),
        ),
        '2026-10-25T08:00:00',
      );
    });

    test('l\'aller-retour des champs ne bouge pas l\'heure', () {
      final DateTime wall = parseWallTime('2026-10-25T08:30:00')!;
      expect(wallTimeOf(wall), '2026-10-25T08:30:00');
    });
  });

  group('RideForm.fromRide', () {
    test('garde chaque id de groupe, son meneur et les deux lieux', () {
      final RideDto ride =
          fixtureRide(
            // En 2026 : la base de fuseaux embarquée ne porte pas les heures
            // d'été d'après 2037.
            dateTime: '2026-07-29T19:30:00Z',
            groups: <RideGroupDto>[
              fixtureGroup(
                id: 'g1',
                leader: const PublicUserDto(id: 'u9', displayName: 'Léa'),
                routeSlug: 'boucle',
              ),
              fixtureGroup(id: 'g2', name: 'B'),
            ],
          ).copyWith(
            startPlace: const PlaceDetailDto(
              id: 'p1',
              name: 'Fonderies',
              startPlace: true,
              endPlace: false,
            ),
            endPlace: const PlaceDetailDto(
              id: 'p2',
              name: 'Gare',
              startPlace: false,
              endPlace: true,
            ),
            tags: const <TagDto>[
              TagDto(id: 'tag1', label: 'Gravel', color: 'teal'),
            ],
          );

      final RideRequest request = RideForm.fromRide(ride).toRequest();

      expect(request.startPlaceId, 'p1');
      expect(request.endPlaceId, 'p2');
      expect(request.groups.map((GroupRequest g) => g.id), <String>[
        'g1',
        'g2',
      ]);
      expect(request.groups.first.leaderId, 'u9');
      expect(request.groups.first.routeSlug, 'boucle');
      // Le meneur est celui du groupe, jamais le créateur de la sortie.
      expect(request.groups.last.leaderId, isNull);
      expect(request.tagIds, <String>['tag1']);
      // 19:30 Z en juillet : 21:30 à Paris, sans offset.
      expect(request.dateTime, '2026-07-29T21:30:00');
    });
  });

  group('RideForm.initial', () {
    test('brouillon, visibilité de l\'équipe, un groupe', () {
      final RideForm form = RideForm.initial(
        team(visibility: 'TEAM'),
        firstGroupName: 'Groupe 1',
        now: DateTime.utc(2026, 10, 14, 10),
      );
      expect(form.status, Status.draft);
      expect(form.visibility, Visibility.team);
      expect(form.dateTime, '2026-10-18T08:00:00');
      expect(form.groups.single.name, 'Groupe 1');
      expect(form.groups.single.id, isNull);
    });
  });

  group('applyTemplate', () {
    test('numérote le nom, vide les parcours, garde date et lieux', () {
      final RideForm start = RideForm.initial(
        team(),
        firstGroupName: 'Groupe 1',
        now: DateTime.utc(2026, 10, 14, 10),
      ).copyWith(startPlaceId: () => 'p1');
      const RideTemplateDto template = RideTemplateDto(
        team: TeamPublicationDto(
          id: 't1',
          slug: 'n-peloton',
          name: 'N-Peloton',
          visibility: 'PUBLIC',
        ),
        id: 'tpl1',
        slug: 'dimanche',
        name: 'Sortie du dimanche',
        markdown: 'Rendez-vous **8 h**',
        visibility: 'PUBLIC',
        status: 'PUBLISHED',
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
        groupCount: 2,
        groups: <RideTemplateGroupDto>[
          RideTemplateGroupDto(
            id: 'tg1',
            name: 'A',
            sortOrder: 0,
            time: '08:00',
            averageSpeed: 30,
          ),
          RideTemplateGroupDto(id: 'tg2', name: 'B', sortOrder: 1),
        ],
        tags: <TagDto>[],
        nextNumber: 42,
      );

      final RideForm form = start.applyTemplate(template);
      final RideRequest request = form.toRequest();

      expect(request.name, 'Sortie du dimanche #42');
      expect(request.media.markdown, 'Rendez-vous **8 h**');
      expect(request.status, 'PUBLISHED');
      expect(request.templateId, 'tpl1');
      expect(request.startPlaceId, 'p1');
      expect(request.dateTime, start.dateTime);
      // Des groupes neufs : pas l'id du modèle, pas de parcours.
      expect(request.groups.map((GroupRequest g) => g.id), <String?>[
        null,
        null,
      ]);
      expect(request.groups.first.time, '08:00');
      expect(request.groups.first.averageSpeed, 30);
    });
  });

  group('toRequest et validation', () {
    RideForm valid() => RideForm.initial(
      team(),
      firstGroupName: 'Groupe 1',
      now: DateTime.utc(2026, 10, 14, 10),
    ).copyWith(name: 'Sortie du dimanche');

    test('écarte les groupes sans nom', () {
      final RideForm form = valid().copyWith(
        groups: const <RideGroupForm>[
          RideGroupForm(name: 'A'),
          RideGroupForm(name: '   '),
        ],
      );
      expect(form.toRequest().groups.map((GroupRequest g) => g.name), <String>[
        'A',
      ]);
    });

    test('publishAt ne part qu\'en brouillon', () {
      final RideForm form = valid().copyWith(
        publishAt: () => '2099-01-01T08:00:00',
      );
      expect(form.toRequest().publishAt, '2099-01-01T08:00:00');
      expect(
        form.copyWith(status: Status.published).toRequest().publishAt,
        isNull,
      );
    });

    test('tagIds vide part vide : « plus aucun tag »', () {
      expect(valid().toRequest().tagIds, isEmpty);
    });

    test('nom de 3 à 200 caractères', () {
      expect(valid().copyWith(name: 'ab').nameValid, isFalse);
      expect(valid().copyWith(name: 'abc').nameValid, isTrue);
      expect(valid().copyWith(name: 'x' * 201).nameValid, isFalse);
    });

    test('au moins un groupe nommé, vitesse et places positives', () {
      expect(
        valid().copyWith(groups: const <RideGroupForm>[]).groupsValid,
        isFalse,
      );
      expect(
        valid()
            .copyWith(
              groups: const <RideGroupForm>[
                RideGroupForm(name: 'A', averageSpeed: 0),
              ],
            )
            .groupsValid,
        isFalse,
      );
      expect(
        valid()
            .copyWith(
              groups: const <RideGroupForm>[
                RideGroupForm(name: 'A', maxParticipants: 0),
              ],
            )
            .groupsValid,
        isFalse,
      );
    });

    test('publication programmée à venir, dans le fuseau de la sortie', () {
      final DateTime now = DateTime.utc(2026, 10, 14, 10); // 12:00 à Paris
      final RideForm past = valid().copyWith(
        publishAt: () => '2026-10-14T11:30:00',
      );
      final RideForm future = valid().copyWith(
        publishAt: () => '2026-10-14T12:30:00',
      );
      expect(past.publishAtValid('Europe/Paris', now: now), isFalse);
      expect(future.publishAtValid('Europe/Paris', now: now), isTrue);
      // À Londres (UTC+1), 11:30 est encore à venir à 10:00 Z.
      expect(past.publishAtValid('Europe/London', now: now), isTrue);
      // Publiée : la date programmée n'est pas lue.
      expect(
        past
            .copyWith(status: Status.published)
            .publishAtValid('Europe/Paris', now: now),
        isTrue,
      );
    });

    test('au plus 10 tags', () {
      expect(
        valid()
            .copyWith(tagIds: List<String>.generate(11, (int i) => '$i'))
            .tagsValid,
        isFalse,
      );
    });
  });
}
