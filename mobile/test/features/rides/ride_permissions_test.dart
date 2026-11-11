import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/ride_permissions.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_manage_menu.dart';

import 'ride_fixtures.dart';
import '../../support/content_permissions.dart';

/// La règle de `RideAccessChecker`, recopiée côté app (ledger `MOB-80`).
void main() {
  group('canManageRides', () {
    test('organisateur et administrateur seulement', () {
      expect(canManageRides(teamRole: TeamRole.organizer), isTrue);
      expect(canManageRides(teamRole: TeamRole.admin), isTrue);
      expect(canManageRides(teamRole: TeamRole.member), isFalse);
      expect(canManageRides(teamRole: null), isFalse);
      // Un rôle inconnu de cette version n'ouvre rien.
      expect(canManageRides(teamRole: TeamRole.$unknown), isFalse);
    });

    test('l\'admin de plateforme passe', () {
      expect(canManageRides(teamRole: null, platformAdmin: true), isTrue);
    });
  });

  group('canManageTeamRoutes (MOB-79)', () {
    TeamDetailDto team({bool routes = true, bool rides = true}) =>
        TeamDetailDto(
          allowedContentVisibilities: kAllContentVisibilities,
          defaultContentVisibility: 'PUBLIC',
          publicContentAllowed: false,
          timezone: 'Europe/Paris',
          id: 't1',
          slug: 'n-peloton',
          name: 'N-Peloton',
          about: const MediaDto(
            markdown: '',
            assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
          ),
          visibility: 'PUBLIC',
          enableTrips: true,
          enableAds: true,
          enablePosts: true,
          enableRides: rides,
          enableRoutes: routes,
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

    test('organisateur et administrateur, module parcours actif', () {
      expect(canManageTeamRoutes(team(), teamRole: TeamRole.organizer), isTrue);
      expect(canManageTeamRoutes(team(), teamRole: TeamRole.admin), isTrue);
      expect(canManageTeamRoutes(team(), teamRole: TeamRole.member), isFalse);
      expect(canManageTeamRoutes(team(), teamRole: null), isFalse);
      // Un rôle inconnu de cette version n'ouvre rien.
      expect(canManageTeamRoutes(team(), teamRole: TeamRole.$unknown), isFalse);
    });

    test(
      'seul le module parcours compte : les sorties coupées ne gênent pas',
      () {
        expect(
          canManageTeamRoutes(team(rides: false), teamRole: TeamRole.organizer),
          isTrue,
        );
        expect(
          canManageTeamRoutes(
            team(routes: false),
            teamRole: TeamRole.organizer,
          ),
          isFalse,
        );
      },
    );

    test("l'admin de plateforme passe, module parcours actif", () {
      expect(
        canManageTeamRoutes(team(), teamRole: null, platformAdmin: true),
        isTrue,
      );
      expect(
        canManageTeamRoutes(
          team(routes: false),
          teamRole: null,
          platformAdmin: true,
        ),
        isFalse,
      );
    });
  });

  group('rideManageActions', () {
    // Le droit vient de la sortie, calculé par le backend (docs/LEDGER_*.md
    // MOB-137) : un organisateur, puis un membre sans droit.
    final ContentPermissionsDto organizer = permissionsFor(
      member: true,
      role: 'ORGANIZER',
    );
    RideDto managed({String status = 'PUBLISHED'}) =>
        fixtureRide(status: status).copyWith(permissions: organizer);

    test('selon le statut, comme le menu du site', () {
      expect(rideManageActions(managed(status: 'DRAFT')), <RideManageAction>[
        RideManageAction.publish,
        RideManageAction.delete,
        RideManageAction.report,
      ]);
      expect(
        rideManageActions(managed(status: 'PUBLISHED')),
        <RideManageAction>[
          RideManageAction.unpublish,
          RideManageAction.cancel,
          RideManageAction.delete,
          RideManageAction.report,
        ],
      );
      expect(
        rideManageActions(managed(status: 'CANCELLED')),
        <RideManageAction>[
          RideManageAction.reinstate,
          RideManageAction.delete,
          RideManageAction.report,
        ],
      );
    });

    test('une sortie supprimée n\'offre que sa restauration', () {
      expect(
        rideManageActions(managed().copyWith(deleted: true)),
        <RideManageAction>[RideManageAction.restore],
      );
    });

    test('sans droit calculé, le signalement seul, quel que soit le rôle', () {
      final RideDto ride = fixtureRide().copyWith(
        permissions: permissionsFor(member: true),
      );
      expect(rideManageActions(ride), <RideManageAction>[
        RideManageAction.report,
      ]);
      expect(rideHasManageActions(ride), isFalse);
      expect(rideManageActions(ride.copyWith(deleted: true)), isEmpty);
    });

    test('canEdit sans canDelete : les statuts, pas la suppression', () {
      final RideDto ride = fixtureRide().copyWith(
        permissions: organizer.copyWith(canDelete: false),
      );
      expect(rideManageActions(ride), <RideManageAction>[
        RideManageAction.unpublish,
        RideManageAction.cancel,
        RideManageAction.report,
      ]);
    });
  });
}
