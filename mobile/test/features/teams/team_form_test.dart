import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/domain/team_form.dart';

import 'team_fixtures.dart';

/// Le formulaire d'équipe (ledger `MOB-165`) : les valeurs de départ du site,
/// la dépendance des modules aux parcours, la validité, et une requête
/// complète — le PUT des paramètres (ledger `MOB-166`) réécrit tout.
void main() {
  TeamForm initial() => TeamForm.initial(timezone: 'Europe/Paris');

  group('valeurs de départ', () {
    test('tous les modules, sauf le trombinoscope ; équipe privée ; '
        'publications au nom de l\'équipe', () {
      final TeamForm form = initial();

      expect(form.name, '');
      expect(form.media.markdown, '');
      expect(form.media.assets.images, isEmpty);
      expect(form.media.assets.attachments, isEmpty);
      expect(form.media.assets.logo, isNull);
      expect(form.visibility, Visibility.team);
      expect(form.timezone, 'Europe/Paris');
      expect(form.location, isNull);
      expect(form.enableRoutes, isTrue);
      expect(form.enableRides, isTrue);
      expect(form.enableTrips, isTrue);
      expect(form.enablePosts, isTrue);
      expect(form.enableAds, isTrue);
      expect(form.enableMemberDirectory, isFalse);
      expect(form.postsAsTeamByDefault, isTrue);
    });

    test('le fuseau est celui qu\'on lui donne', () {
      expect(
        TeamForm.initial(timezone: 'Pacific/Auckland').timezone,
        'Pacific/Auckland',
      );
    });
  });

  group('modules', () {
    test('couper les parcours coupe les sorties et les voyages', () {
      final TeamForm form = initial().withRoutes(false);

      expect(form.enableRoutes, isFalse);
      expect(form.enableRides, isFalse);
      expect(form.enableTrips, isFalse);
      // Le reste ne bouge pas.
      expect(form.enablePosts, isTrue);
      expect(form.enableAds, isTrue);
    });

    test('rétablir les parcours ne rallume ni les sorties ni les voyages', () {
      final TeamForm form = initial().withRoutes(false).withRoutes(true);

      expect(form.enableRoutes, isTrue);
      expect(form.enableRides, isFalse);
      expect(form.enableTrips, isFalse);
    });

    test('sans parcours, sorties et voyages ne s\'activent pas', () {
      final TeamForm form = initial()
          .withRoutes(false)
          .copyWith(enableRides: true, enableTrips: true);

      expect(form.enableRides, isFalse);
      expect(form.enableTrips, isFalse);
    });

    test('couper les publications garde le choix de signature', () {
      final TeamForm form = initial().copyWith(enablePosts: false);

      expect(form.enablePosts, isFalse);
      expect(form.postsAsTeamByDefault, isTrue);
    });
  });

  group('validité', () {
    test('le nom : 1 à 200 caractères, dont un non blanc', () {
      expect(initial().nameValid, isFalse);
      expect(initial().copyWith(name: '   ').nameValid, isFalse);
      expect(initial().copyWith(name: 'A').nameValid, isTrue);
      expect(initial().copyWith(name: 'A' * 200).nameValid, isTrue);
      expect(initial().copyWith(name: 'A' * 201).nameValid, isFalse);
    });

    test('la description au plus à la borne du contrat', () {
      TeamForm withText(int length) => initial().copyWith(
        name: 'Club',
        media: initial().media.copyWith(markdown: 'a' * length),
      );

      expect(withText(100000).isValid, isTrue);
      expect(withText(100001).markdownValid, isFalse);
      expect(withText(100001).isValid, isFalse);
    });

    test('un formulaire nommé est valide ; sans fuseau, non', () {
      expect(initial().isValid, isFalse);
      expect(initial().copyWith(name: 'Club').isValid, isTrue);
      expect(initial().copyWith(name: 'Club', timezone: ' ').isValid, isFalse);
    });
  });

  group('requête', () {
    test('une création par défaut : tout y est, sans position', () {
      final TeamRequest request = initial()
          .copyWith(name: '  Vélo Club du Lac  ')
          .toRequest();

      expect(request.name, 'Vélo Club du Lac');
      expect(request.media.markdown, '');
      expect(request.visibility, 'TEAM');
      expect(request.timezone, 'Europe/Paris');
      expect(request.geometry, isNull);
      expect(request.enableRoutes, isTrue);
      expect(request.enableRides, isTrue);
      expect(request.enableTrips, isTrue);
      expect(request.enablePosts, isTrue);
      expect(request.enableAds, isTrue);
      expect(request.enableMemberDirectory, isFalse);
      expect(request.postsAsTeamByDefault, isTrue);
    });

    test('la position part en point GeoJSON [longitude, latitude]', () {
      final TeamRequest request = initial()
          .copyWith(name: 'Club', location: () => <double>[4.8262, 45.7485])
          .toRequest();

      expect(request.geometry!.type, TeamRequestGeometryTypeType.point);
      expect(request.geometry!.coordinates, <double>[4.8262, 45.7485]);
      expect(request.toJson()['geometry'], <String, Object?>{
        'type': 'Point',
        'coordinates': <double>[4.8262, 45.7485],
      });
    });

    test('retirer la position l\'efface', () {
      final TeamForm form = initial()
          .copyWith(location: () => <double>[4.8, 45.7])
          .copyWith(location: () => null);

      expect(form.location, isNull);
      expect(form.toRequest().geometry, isNull);
    });
  });

  group('depuis une équipe (paramètres, MOB-166)', () {
    final TeamDetailDto team =
        fixtureTeam(
          slug: 'n-peloton',
          name: 'N-Peloton',
          visibility: 'PUBLIC',
          role: 'ADMIN',
        ).copyWith(
          about: const MediaDto(
            markdown: 'Le club du Nord.',
            assets: AssetsDto(
              logo: AssetDto(
                id: 'logo',
                fileName: 'logo.png',
                contentType: 'image/png',
                url: '/api/download/PUBLIC/logo',
              ),
              images: <AssetDto>[
                AssetDto(
                  id: 'img',
                  fileName: 'photo.jpg',
                  contentType: 'image/jpeg',
                  url: '/api/download/PUBLIC/img',
                ),
              ],
              attachments: <AssetDto>[
                AssetDto(
                  id: 'pdf',
                  fileName: 'statuts.pdf',
                  contentType: 'application/pdf',
                  url: '/api/download/PUBLIC/pdf',
                ),
              ],
            ),
          ),
          geometry: const TeamDetailDtoGeometry(
            type: TeamDetailDtoGeometryTypeType.point,
            coordinates: <double>[3.06, 50.63],
          ),
          timezone: 'Europe/Brussels',
          enableTrips: false,
          enableMemberDirectory: true,
          postsAsTeamByDefault: false,
        );

    test('la requête réécrit l\'équipe en entier, médias compris', () {
      final TeamRequest request = TeamForm.fromTeam(team).toRequest();

      expect(request.name, 'N-Peloton');
      expect(request.media, team.about);
      expect(request.media.assets.logo!.id, 'logo');
      expect(request.media.assets.images.single.id, 'img');
      expect(request.media.assets.attachments.single.id, 'pdf');
      expect(request.visibility, 'PUBLIC');
      expect(request.timezone, 'Europe/Brussels');
      expect(request.geometry!.coordinates, <double>[3.06, 50.63]);
      expect(request.enableRoutes, isTrue);
      expect(request.enableRides, isTrue);
      expect(request.enableTrips, isFalse);
      expect(request.enablePosts, isTrue);
      expect(request.enableAds, isTrue);
      expect(request.enableMemberDirectory, isTrue);
      expect(request.postsAsTeamByDefault, isFalse);
    });

    test('un formulaire intact se réécrit à l\'identique : sa requête ne '
        'dépend que de l\'équipe', () {
      final TeamForm form = TeamForm.fromTeam(team);

      // Aucune modification : la requête d'un formulaire relu est la même,
      // c'est ce que l'écran compare pour dire « modifié ».
      expect(form.toRequest(), TeamForm.fromTeam(team).toRequest());
      expect(form.copyWith().toRequest(), form.toRequest());
      expect(form.isValid, isTrue);
    });

    test('changer la visibilité ou le fuseau ne touche à rien d\'autre', () {
      final TeamForm form = TeamForm.fromTeam(team);
      final TeamRequest request = form
          .copyWith(visibility: Visibility.team, timezone: 'Pacific/Auckland')
          .toRequest();

      expect(request.visibility, 'TEAM');
      expect(request.timezone, 'Pacific/Auckland');
      expect(
        request.copyWith(visibility: 'PUBLIC', timezone: 'Europe/Brussels'),
        form.toRequest(),
      );
    });

    test('une position effacée part en `geometry: null`, clé présente : le '
        'PUT l\'efface', () {
      // `TeamService.updateTeam` fait `setGeometry(request.geometry())` : une
      // position nulle **ou absente** efface celle de l'équipe. Rien n'est
      // « laissé tel quel » par omission, d'où le PUT qui renvoie tout.
      final TeamRequest request = TeamForm.fromTeam(team)
          .copyWith(location: () => null)
          .toRequest();
      final Map<String, Object?> json = request.toJson();

      expect(json.containsKey('geometry'), isTrue);
      expect(json['geometry'], isNull);
      // Le reste de l'équipe est toujours là.
      expect(request.media, team.about);
      expect(request.timezone, 'Europe/Brussels');
    });

    test('une équipe sans position repart sans position', () {
      final TeamRequest request = TeamForm.fromTeam(
        team.copyWith(geometry: null),
      ).toRequest();

      expect(request.geometry, isNull);
    });
  });
}
