import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/ads/domain/ad_form.dart';
import 'package:pedalons/features/rides/domain/ride_form.dart'
    show kRideMarkdownMaxLength;

import '../../support/localization.dart';
import '../routes/route_fixtures.dart';
import 'ad_fixtures.dart';

/// Le formulaire d'une annonce (ledger `MOB-158`) : ce qui part au serveur,
/// qui réécrit l'annonce en entier — position comprise.
void main() {
  setUpAll(loadTestTranslations);

  group('AdForm.initial', () {
    test('une vente en brouillon, sans prix ni lieu', () {
      final AdRequest request = AdForm.initial()
          .copyWith(name: '  Vélo  ')
          .toRequest();

      expect(request.name, 'Vélo');
      expect(request.status, 'DRAFT');
      expect(request.adType, 'SALE');
      expect(request.price, isNull);
      expect(request.rentalPeriod, isNull);
      expect(request.locationDescription, isNull);
      expect(request.locationGeometry, isNull);
      expect(request.tagIds, isEmpty);
    });
  });

  group('AdForm.fromEdit', () {
    test('reprend tout, et la position repart telle que reçue', () {
      // Le point flouté rendu à qui n'est pas l'auteur : renvoyé inchangé, le
      // serveur garde le point exact enregistré.
      final AdRequest request = AdForm.fromEdit(
        fixtureAdEdit(
          adType: 'RENTAL',
          rentalPeriod: 'WEEK',
          price: 45.5,
          coordinates: const <double>[4.835, 45.755],
          tags: const <TagDto>[TagDto(id: 'g1', label: 'Route', color: 'blue')],
        ),
      ).toRequest();

      expect(request.name, 'Vélo à vendre');
      expect(request.media.markdown, 'Très bon état.');
      expect(request.status, 'PUBLISHED');
      expect(request.adType, 'RENTAL');
      expect(request.rentalPeriod, 'WEEK');
      expect(request.price, 45.5);
      expect(request.locationDescription, 'Lyon 7e');
      expect(request.locationGeometry!.coordinates, <double>[4.835, 45.755]);
      expect(request.tagIds, <String>['g1']);
    });

    test('la période ne part que pour une location', () {
      final AdForm rental = AdForm.fromEdit(
        fixtureAdEdit(adType: 'RENTAL', rentalPeriod: 'DAY'),
      );
      expect(rental.toRequest().rentalPeriod, 'DAY');
      expect(
        rental.copyWith(adType: AdType.sale).toRequest().rentalPeriod,
        isNull,
      );
    });

    test('un lieu vidé part nul, la position retirée aussi', () {
      final AdRequest request = AdForm.fromEdit(
        fixtureAdEdit(coordinates: const <double>[4.8, 45.7]),
      ).copyWith(locationDescription: '   ', location: () => null).toRequest();

      expect(request.locationDescription, isNull);
      expect(request.locationGeometry, isNull);
    });
  });

  group('validation', () {
    final AdForm valid = AdForm.initial().copyWith(name: 'Vélo');

    test('un titre est requis, 200 caractères au plus', () {
      expect(valid.isValid, isTrue);
      expect(valid.copyWith(name: '  ').isValid, isFalse);
      expect(valid.copyWith(name: 'a' * 201).isValid, isFalse);
    });

    test('une location dit sa période', () {
      final AdForm rental = valid.copyWith(adType: AdType.rental);
      expect(rental.rentalPeriodValid, isFalse);
      expect(rental.isValid, isFalse);
      expect(
        rental.copyWith(rentalPeriod: () => RentalPeriod.month).isValid,
        isTrue,
      );
    });

    test('description, lieu et tags ont leurs bornes', () {
      expect(
        valid
            .copyWith(
              media: valid.media.copyWith(
                markdown: 'a' * (kRideMarkdownMaxLength + 1),
              ),
            )
            .isValid,
        isFalse,
      );
      expect(valid.copyWith(locationDescription: 'a' * 201).isValid, isFalse);
      expect(
        valid
            .copyWith(tagIds: <String>[for (int i = 0; i < 11; i++) 'g$i'])
            .isValid,
        isFalse,
      );
    });
  });

  group('parseAdPrice', () {
    test('vide : valide, prix à négocier', () {
      expect(parseAdPrice('  '), (valid: true, value: null));
    });

    test('la virgule comme le point, au centime', () {
      expect(parseAdPrice('450'), (valid: true, value: 450));
      expect(parseAdPrice('12,5'), (valid: true, value: 12.5));
      expect(parseAdPrice('12.499'), (valid: true, value: 12.5));
      expect(parseAdPrice('0'), (valid: true, value: 0));
    });

    test('un texte illisible n\'est pas « à négocier »', () {
      expect(parseAdPrice('1.2.3').valid, isFalse);
      expect(parseAdPrice('-5').valid, isFalse);
      expect(parseAdPrice('abc').valid, isFalse);
    });

    test('le champ relit le prix sans décimales inutiles', () {
      expect(adPriceText(null), '');
      expect(adPriceText(1200), '1200');
      expect(adPriceText(12.5), '12,5');
    });
  });

  group('canCreateTeamAds', () {
    test('tout membre, module annonces actif', () {
      final TeamDetailDto team = fixtureRouteTeam();
      for (final TeamRole role in <TeamRole>[
        TeamRole.member,
        TeamRole.organizer,
        TeamRole.admin,
      ]) {
        expect(canCreateTeamAds(team, teamRole: role), isTrue);
      }
      expect(canCreateTeamAds(team, teamRole: null), isFalse);
      expect(canCreateTeamAds(team, teamRole: TeamRole.$unknown), isFalse);
      expect(
        canCreateTeamAds(team, teamRole: null, platformAdmin: true),
        isTrue,
      );
      expect(
        canCreateTeamAds(
          team.copyWith(enableAds: false),
          teamRole: TeamRole.admin,
        ),
        isFalse,
      );
    });
  });
}
