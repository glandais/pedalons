import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/posts/domain/post_form.dart';
import 'package:pedalons/features/rides/domain/ride_form.dart'
    show kRideMarkdownMaxLength;

import '../routes/route_fixtures.dart';
import 'post_fixtures.dart';

/// Le formulaire d'une publication (ledger `MOB-156`) : ce qui part au
/// serveur, qui réécrit la publication en entier.
void main() {
  // Charge la base des fuseaux : un fuseau inconnu retomberait sur celui de
  // la machine qui lance les tests.
  setUpAll(AppFormatters.timezoneNames);

  final DateTime now = DateTime.utc(2026, 11, 14, 10, 30);

  group('PostForm.initial', () {
    test('maintenant dans le fuseau de l\'équipe, brouillon, signature et '
        'visibilité de l\'équipe', () {
      final PostForm form = PostForm.initial(
        fixtureRouteTeam(visibility: 'TEAM'),
        now: now,
      );

      // 10:30 UTC, 11:30 à Paris en hiver.
      expect(form.dateTime, '2026-11-14T11:30:00');
      expect(form.status, Status.draft);
      expect(form.visibility, Visibility.team);
      expect(form.signedAsTeam, isTrue);
      expect(form.publishAt, isNull);
      expect(form.tagIds, isEmpty);
    });

    test('la signature suit le réglage de l\'équipe', () {
      final PostForm form = PostForm.initial(
        fixtureRouteTeam().copyWith(postsAsTeamByDefault: false),
        now: now,
      );
      expect(form.signedAsTeam, isFalse);
    });
  });

  group('PostForm.fromPost', () {
    test('les dates repassent en heure murale du fuseau de la publication', () {
      final PostForm form = PostForm.fromPost(
        fixturePost(
          status: 'DRAFT',
          publishAt: '2026-12-01T07:00:00Z',
          timezone: 'Asia/Tokyo',
          tags: const <TagDto>[TagDto(id: 'g1', label: 'Récit', color: 'blue')],
        ),
      );

      expect(form.name, 'Retour de sortie');
      expect(form.dateTime, '2026-05-03T18:00:00');
      expect(form.publishAt, '2026-12-01T16:00:00');
      expect(form.status, Status.draft);
      expect(form.visibility, Visibility.team);
      expect(form.signedAsTeam, isFalse);
      expect(form.tagIds, <String>['g1']);
    });
  });

  group('toRequest', () {
    test('le nom est rogné, les tags partent toujours, la signature aussi', () {
      final PostRequest request = PostForm.initial(
        fixtureRouteTeam(),
        now: now,
      ).copyWith(name: '  Un titre  ').toRequest();

      expect(request.name, 'Un titre');
      expect(request.status, 'DRAFT');
      expect(request.visibility, 'PUBLIC');
      expect(request.tagIds, isEmpty);
      expect(request.signedAsTeam, isTrue);
    });

    test('une publication programmée ne part qu\'en brouillon', () {
      final PostForm draft = PostForm.initial(
        fixtureRouteTeam(),
        now: now,
      ).copyWith(publishAt: () => '2026-12-01T08:00:00');

      expect(draft.toRequest().publishAt, '2026-12-01T08:00:00');
      expect(
        draft.copyWith(status: Status.published).toRequest().publishAt,
        isNull,
      );
    });
  });

  group('validation', () {
    final PostForm valid = PostForm.initial(
      fixtureRouteTeam(),
      now: now,
    ).copyWith(name: 'Titre');

    test('un titre d\'un caractère suffit, vide ou trop long non', () {
      expect(valid.copyWith(name: 'A').nameValid, isTrue);
      expect(valid.copyWith(name: '   ').nameValid, isFalse);
      expect(valid.copyWith(name: 'a' * 201).nameValid, isFalse);
    });

    test('texte trop long, trop de tags', () {
      expect(
        valid
            .copyWith(
              media: valid.media.copyWith(
                markdown: 'a' * (kRideMarkdownMaxLength + 1),
              ),
            )
            .isValid('Europe/Paris', now: now),
        isFalse,
      );
      expect(
        valid
            .copyWith(tagIds: <String>[for (int i = 0; i < 11; i++) 'g$i'])
            .isValid('Europe/Paris', now: now),
        isFalse,
      );
      expect(valid.isValid('Europe/Paris', now: now), isTrue);
    });

    test('la publication programmée se compare dans le fuseau de la '
        'publication', () {
      // 11:00 mural : passé à Paris (11:30), à venir à Los Angeles (02:30).
      final PostForm form = valid.copyWith(
        publishAt: () => '2026-11-14T11:00:00',
      );
      expect(form.publishAtValid('Europe/Paris', now: now), isFalse);
      expect(form.publishAtValid('America/Los_Angeles', now: now), isTrue);
      // Publiée : la date programmée n'est plus lue.
      expect(
        form
            .copyWith(status: Status.published)
            .publishAtValid('Europe/Paris', now: now),
        isTrue,
      );
    });
  });

  group('canManageTeamPosts', () {
    test('organisateur ou administrateur, module publications actif', () {
      final TeamDetailDto team = fixtureRouteTeam();
      expect(canManageTeamPosts(team, teamRole: TeamRole.organizer), isTrue);
      expect(canManageTeamPosts(team, teamRole: TeamRole.admin), isTrue);
      expect(canManageTeamPosts(team, teamRole: TeamRole.member), isFalse);
      expect(canManageTeamPosts(team, teamRole: null), isFalse);
      expect(
        canManageTeamPosts(team, teamRole: null, platformAdmin: true),
        isTrue,
      );
      expect(
        canManageTeamPosts(
          team.copyWith(enablePosts: false),
          teamRole: TeamRole.admin,
        ),
        isFalse,
      );
    });
  });
}
