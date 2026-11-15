import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/features/teams/presentation/pages/team_admin_members_page.dart';

/// L'administration d'une équipe est entièrement dans l'app (ledgers
/// `MOB-165` à `MOB-169`) : plus aucune de ses pages n'est une page du site
/// que l'app ouvrirait dans le navigateur. Ce fichier remplace
/// `team_web_paths_test.dart`, disparu avec `team_web_paths.dart`.
void main() {
  tearDown(() => setCurrentLocale('fr'));

  test('les seules pages du site sans écran : les fonctionnalités et '
      'l\'assistance', () {
    // `appScreen: false` dans `contracts/routes.yaml`. L'assistance est ce
    // qu'ouvre le lien de contact d'une équipe pleine (MOB-167).
    expect(webOnlyRouteIds, <String>{'features', 'support'});
    expect(Paths.support(), '/support');
  });

  test('chaque écran de la gestion de l\'équipe a son chemin, dans la langue '
      'de l\'app', () {
    setCurrentLocale('fr');
    expect(Paths.teamAdmin('velo-club'), '/equipes/velo-club/admin');
    expect(
      Paths.teamAdminPlaces('velo-club'),
      '/equipes/velo-club/admin/lieux',
    );
    expect(Paths.teamAdminTags('velo-club'), '/equipes/velo-club/admin/tags');
    expect(Paths.teamAdminPages('velo-club'), '/equipes/velo-club/admin/pages');
    expect(
      Paths.teamAdminPageNew('velo-club'),
      '/equipes/velo-club/admin/pages/nouvelle',
    );
    expect(
      Paths.teamAdminPageEdit('velo-club', 'faq'),
      '/equipes/velo-club/admin/pages/faq/modifier',
    );
    expect(
      Paths.teamAdminMembers('velo-club'),
      '/equipes/velo-club/admin/membres',
    );
    expect(
      Paths.teamAdminReports('velo-club'),
      '/equipes/velo-club/admin/signalements',
    );
    expect(
      Paths.teamSettings('velo-club'),
      '/equipes/velo-club/admin/parametres',
    );

    setCurrentLocale('en');
    expect(Paths.teamAdminPages('velo-club'), '/teams/velo-club/admin/pages');
    expect(
      Paths.teamAdminPageEdit('velo-club', 'faq'),
      '/teams/velo-club/admin/pages/faq/edit',
    );
  });

  test('« Inviter » ouvre l\'écran des membres de l\'app, feuille '
      'd\'invitation ouverte (MOB-167)', () {
    setCurrentLocale('en');
    expect(
      teamAdminMembersInviteLocation('velo-club'),
      '/teams/velo-club/admin/members?invite=1',
    );
    setCurrentLocale('fr');
    expect(
      teamAdminMembersInviteLocation('velo-club'),
      '/equipes/velo-club/admin/membres?invite=1',
    );
  });
}
