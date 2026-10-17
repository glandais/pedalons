import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/ride_permissions.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_manage_menu.dart';

import 'ride_fixtures.dart';

/// La règle de `RideAccessChecker`, recopiée côté app (ledger `MOB-76`).
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

  group('rideManageActions', () {
    test('selon le statut, comme le menu du site', () {
      expect(
        rideManageActions(fixtureRide(status: 'DRAFT')),
        <RideManageAction>[
          RideManageAction.publish,
          RideManageAction.delete,
          RideManageAction.report,
        ],
      );
      expect(
        rideManageActions(fixtureRide(status: 'PUBLISHED')),
        <RideManageAction>[
          RideManageAction.unpublish,
          RideManageAction.cancel,
          RideManageAction.delete,
          RideManageAction.report,
        ],
      );
      expect(
        rideManageActions(fixtureRide(status: 'CANCELLED')),
        <RideManageAction>[
          RideManageAction.reinstate,
          RideManageAction.delete,
          RideManageAction.report,
        ],
      );
    });

    test('une sortie supprimée n\'offre que sa restauration', () {
      expect(
        rideManageActions(fixtureRide().copyWith(deleted: true)),
        <RideManageAction>[RideManageAction.restore],
      );
    });
  });
}
