import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/domain/team_page_form.dart';

import '../../support/content_permissions.dart';
import 'team_fixtures.dart';

/// Le formulaire d'une page d'équipe, et l'ordre envoyé par « monter » et
/// « descendre » (ledger `MOB-169`).
void main() {
  TeamPageSummaryDto summary(String id, {bool deleted = false}) =>
      TeamPageSummaryDto(
        id: id,
        title: 'Page $id',
        slug: id,
        visibility: 'TEAM',
        order: 0,
        deleted: deleted,
      );

  const AssetDto image = AssetDto(
    id: 'img1',
    fileName: 'col.jpg',
    contentType: 'image/jpeg',
    size: 1200,
    url: '/api/download/team/img1',
  );
  const AssetDto attachment = AssetDto(
    id: 'att1',
    fileName: 'reglement.pdf',
    contentType: 'application/pdf',
    size: 4200,
    url: '/api/download/team/att1',
  );

  TeamPageDto page({String visibility = 'PUBLIC'}) => TeamPageDto(
    team: kMemberTeam,
    id: 'pg1',
    title: 'Règlement',
    slug: 'reglement',
    media: const MediaDto(
      markdown: 'Le texte ::asset{id="img1"}',
      assets: AssetsDto(
        images: <AssetDto>[image],
        attachments: <AssetDto>[attachment],
        logo: image,
      ),
    ),
    visibility: visibility,
    order: 1,
    deleted: false,
    permissions: permissionsFor(member: true, role: 'ADMIN'),
  );

  group('TeamPageForm', () {
    test('vide : « Équipe » quelle que soit l\'équipe, titre à saisir', () {
      final TeamPageForm form = TeamPageForm.initial(fixtureTeam());
      expect(form.visibility, Visibility.team);
      expect(form.title, '');
      expect(form.media.markdown, '');
      expect(form.titleValid, isFalse);
      expect(form.isValid, isFalse);
    });

    test('vide, pour une équipe privée : « Équipe », la seule valeur que le '
        'backend permet', () {
      final TeamPageForm form = TeamPageForm.initial(
        fixtureTeam(visibility: 'TEAM'),
      );
      expect(form.visibility, Visibility.team);
    });

    test('vide, si le backend ne permet plus « Équipe » : la première valeur '
        'qu\'il donne — jamais déduite du rôle ni de l\'équipe', () {
      final TeamDetailDto team = fixtureTeam().copyWith(
        allowedContentVisibilities: kAllContentVisibilities.copyWith(
          teamPage: <Visibility>[Visibility.publicUnlisted, Visibility.public],
        ),
      );
      expect(TeamPageForm.initial(team).visibility, Visibility.publicUnlisted);
    });

    test('le titre : 1 à 100 caractères, dont un qui n\'est pas un blanc', () {
      final TeamPageForm form = TeamPageForm.initial(fixtureTeam());
      expect(form.copyWith(title: '   ').titleValid, isFalse);
      expect(form.copyWith(title: 'F').titleValid, isTrue);
      expect(form.copyWith(title: 'a' * 100).titleValid, isTrue);
      expect(form.copyWith(title: 'a' * 101).titleValid, isFalse);
    });

    test('la requête de création : titre rogné, médias, visibilité', () {
      final TeamPageForm form = TeamPageForm.initial(fixtureTeam())
          .copyWith(title: '  FAQ ', visibility: Visibility.public);
      expect(form.toRequest().toJson(), <String, Object?>{
        'title': 'FAQ',
        'media': kEmptyMedia.toJson(),
        'visibility': 'PUBLIC',
      });
    });

    test('un formulaire intact renvoie la page entière : le PUT réécrit le '
        'titre, la visibilité et tous les médias — logo, images, pièces '
        'jointes', () {
      final TeamPageDto source = page();
      final TeamPageRequest request = TeamPageForm.fromPage(source).toRequest();
      expect(request.title, 'Règlement');
      expect(request.visibility, 'PUBLIC');
      expect(request.media, source.media);
      expect(request.media.assets.logo, image);
      expect(request.media.assets.images, <AssetDto>[image]);
      expect(request.media.assets.attachments, <AssetDto>[attachment]);
    });
  });

  group('ordre des pages', () {
    final List<TeamPageSummaryDto> pages = <TeamPageSummaryDto>[
      summary('a'),
      summary('b', deleted: true),
      summary('c'),
    ];

    test('descendre et monter échangent deux voisines, liste complète '
        'envoyée — pages supprimées comprises', () {
      expect(movedTeamPageIds(pages, 0, up: false), <String>['b', 'a', 'c']);
      expect(movedTeamPageIds(pages, 2, up: true), <String>['a', 'c', 'b']);
      expect(movedTeamPageIds(pages, 1, up: true), <String>['b', 'a', 'c']);
    });

    test('la première ne monte pas, la dernière ne descend pas', () {
      expect(movedTeamPageIds(pages, 0, up: true), isNull);
      expect(movedTeamPageIds(pages, 2, up: false), isNull);
      expect(movedTeamPageIds(pages, 5, up: true), isNull);
    });

    test('seules les pages qui ne sont pas à la corbeille comptent dans la '
        'limite', () {
      expect(liveTeamPageCount(pages), 2);
      expect(liveTeamPageCount(const <TeamPageSummaryDto>[]), 0);
    });
  });
}
