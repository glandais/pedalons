import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/trips/domain/trip_form.dart';

import '../../support/content_permissions.dart';
import 'trip_fixtures.dart';

/// Le formulaire d'un voyage (ledger `MOB-162`) : ce que l'éditeur tient, et
/// surtout **ce qui part** — le serveur applique chaque champ du PUT.
TeamDetailDto _team({
  bool enableTrips = true,
  bool enableRoutes = true,
  String timezone = 'Europe/Paris',
}) => TeamDetailDto(
  allowedContentVisibilities: kAllContentVisibilities,
  defaultContentVisibility: 'PUBLIC_UNLISTED',
  publicContentAllowed: false,
  tier: 'FREE',
  timezone: timezone,
  role: 'ORGANIZER',
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  about: kEmptyMedia,
  visibility: 'PUBLIC',
  enableTrips: enableTrips,
  enableAds: true,
  enablePosts: true,
  enableRides: true,
  enableRoutes: enableRoutes,
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

void main() {
  group('TripForm.initial', () {
    test('samedi prochain 8 h, brouillon, une étape à la même heure', () {
      // Un mercredi.
      final TripForm form = TripForm.initial(
        _team(),
        firstStageName: 'Étape 1',
        now: DateTime.utc(2026, 11, 18, 12),
      );

      expect(form.dateTime, '2026-11-21T08:00:00');
      expect(form.status, Status.draft);
      expect(form.visibility, Visibility.publicUnlisted);
      expect(form.stages.single.name, 'Étape 1');
      expect(form.stages.single.dateTime, form.dateTime);
      expect(form.stages.single.id, isNull);
    });
  });

  group('TripForm.fromTrip', () {
    test('chaque étape garde son id, son parcours et ses lieux, et sa date '
        'se lit dans son fuseau', () {
      final TripDto trip = fixtureTrip(
        dateTime: '2026-08-12T07:00:00Z',
        stages: <TripStageDto>[
          fixtureStage(
            index: 2,
            timezone: 'Asia/Tokyo',
            dateTime: '2026-08-13T07:00:00Z',
          ),
          fixtureStage(
            index: 1,
            dateTime: '2026-08-12T07:00:00Z',
            route: fixtureStageRoute(),
            startPlaceName: 'Clermont',
            endPlaceName: 'Volvic',
          ),
        ],
      );

      final TripRequest request = TripForm.fromTrip(trip).toRequest();

      // Dans l'ordre d'affichage, pas celui de la liste reçue.
      expect(request.stages.map((StageRequest s) => s.id), <String>[
        's1',
        's2',
      ]);
      expect(request.stages.first.routeSlug, 'gtmc-j1');
      expect(request.stages.first.startPlaceId, 'p-start-1');
      expect(request.stages.first.endPlaceId, 'p-end-1');
      // Paris en été : UTC+2 ; Tokyo : UTC+9. Sans offset.
      expect(request.stages.first.dateTime, '2026-08-12T09:00:00');
      expect(request.stages.last.dateTime, '2026-08-13T16:00:00');
      expect(request.dateTime, '2026-08-12T09:00:00');
      expect(request.tagIds, isEmpty);
    });
  });

  group('toRequest', () {
    test('la publication programmée ne part qu\'en brouillon', () {
      final TripForm form = TripForm.initial(
        _team(),
        firstStageName: 'Étape 1',
      ).copyWith(name: ' GTMC ', publishAt: () => '2099-01-01T10:00:00');

      expect(form.toRequest().name, 'GTMC');
      expect(form.toRequest().publishAt, '2099-01-01T10:00:00');
      expect(
        form.copyWith(status: Status.published).toRequest().publishAt,
        isNull,
      );
    });
  });

  group('nextStageDateTime', () {
    test('J+1 à la même heure murale, changement d\'heure compris', () {
      final TripForm form = TripForm.initial(_team(), firstStageName: 'Étape 1')
          .copyWith(
            stages: <TripStageForm>[
              // La nuit du 24 au 25 octobre 2026, la France recule d'une heure.
              const TripStageForm(name: 'J1', dateTime: '2026-10-24T08:00:00'),
            ],
          );

      expect(form.nextStageDateTime(), '2026-10-25T08:00:00');
    });

    test('sans étape, la première part avec le voyage', () {
      final TripForm form = TripForm.initial(
        _team(),
        firstStageName: 'Étape 1',
      ).copyWith(stages: const <TripStageForm>[]);

      expect(form.nextStageDateTime(), form.dateTime);
    });

    test('la fin de mois passe au mois suivant', () {
      expect(
        addDaysToWallTime('2026-01-31T07:30:00', 1),
        '2026-02-01T07:30:00',
      );
    });
  });

  group('validation', () {
    final TripForm valid = TripForm.initial(
      _team(),
      firstStageName: 'Étape 1',
    ).copyWith(name: 'GTMC');

    test('un nom et des étapes nommées suffisent', () {
      expect(valid.isValid('Europe/Paris'), isTrue);
      // Un voyage sans étape est accepté par le contrat.
      expect(
        valid.copyWith(stages: const <TripStageForm>[]).isValid('Europe/Paris'),
        isTrue,
      );
    });

    test('sans nom, ou avec une étape sans nom : refusé', () {
      expect(valid.copyWith(name: '  ').isValid('Europe/Paris'), isFalse);
      expect(
        valid
            .copyWith(
              stages: <TripStageForm>[valid.stages.single.copyWith(name: '')],
            )
            .isValid('Europe/Paris'),
        isFalse,
      );
    });

    test('une vitesse nulle ou négative : refusé', () {
      expect(
        valid
            .copyWith(
              stages: <TripStageForm>[
                valid.stages.single.copyWith(averageSpeed: () => 0),
              ],
            )
            .isValid('Europe/Paris'),
        isFalse,
      );
    });

    test('une publication programmée dans le passé : refusé, en brouillon '
        'seulement', () {
      final TripForm past = valid.copyWith(
        publishAt: () => '2020-01-01T10:00:00',
      );
      expect(past.isValid('Europe/Paris'), isFalse);
      expect(
        past.copyWith(status: Status.published).isValid('Europe/Paris'),
        isTrue,
      );
    });
  });

  group('canManageTeamTrips', () {
    test('organisation, modules voyages et parcours actifs', () {
      expect(canManageTeamTrips(_team(), teamRole: TeamRole.organizer), isTrue);
      expect(canManageTeamTrips(_team(), teamRole: TeamRole.admin), isTrue);
      expect(canManageTeamTrips(_team(), teamRole: TeamRole.member), isFalse);
      expect(canManageTeamTrips(_team(), teamRole: null), isFalse);
      expect(
        canManageTeamTrips(
          _team(enableTrips: false),
          teamRole: TeamRole.organizer,
        ),
        isFalse,
      );
      expect(
        canManageTeamTrips(
          _team(enableRoutes: false),
          teamRole: TeamRole.organizer,
        ),
        isFalse,
      );
    });
  });
}
