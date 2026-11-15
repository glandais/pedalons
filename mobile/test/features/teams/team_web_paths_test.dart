import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/features/teams/presentation/pages/team_admin_members_page.dart';
import 'package:pedalons/features/teams/presentation/team_web_paths.dart';

/// Les pages du site qu'ouvre le hub « Gestion de l'équipe » viennent de
/// `contracts/routes.yaml` (docs/LEDGER_*.md MOB-54), dans la langue de l'app.
/// Créer et modifier une sortie se font dans l'app depuis `MOB-80`, les
/// modèles de sortie depuis `MOB-78`, la gestion des membres depuis
/// `MOB-167` : ces pages ne sont plus du site.
void main() {
  tearDown(() => setCurrentLocale('fr'));

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

  test('la gestion des membres est un écran de l\'app (MOB-167)', () {
    expect(webOnlyRouteIds, isNot(contains('teamAdminMembers')));
  });

  test('la page d\'assistance du site s\'ouvre dans le navigateur : le lien '
      'de contact d\'une équipe pleine (MOB-167)', () {
    expect(webOnlyRouteIds, contains('support'));
    expect(Paths.support(), '/support');
  });

  test('la file de signalements est un écran de l\'app (MOB-168)', () {
    expect(webOnlyRouteIds, isNot(contains('teamAdminReports')));
  });

  test('chaque page que le hub ouvre encore sur le site est sans écran', () {
    // `appScreen: false` dans le contrat : le lien part dans le navigateur,
    // jamais sur le routeur de l'app.
    for (final String id in <String>[
      // Ouverte par le hub « Gestion de l'équipe » tant que son écran
      // n'existe pas (MOB-165).
      'teamAdminPages',
    ]) {
      expect(webOnlyRouteIds, contains(id));
    }
  });

  test('créer une équipe et le hub de gestion sont des écrans de l\'app '
      '(MOB-165)', () {
    expect(webOnlyRouteIds, isNot(contains('teamsNew')));
    expect(webOnlyRouteIds, isNot(contains('teamAdmin')));
  });

  test('les tags de l\'équipe sont un écran de l\'app (MOB-169)', () {
    expect(webOnlyRouteIds, isNot(contains('teamAdminTags')));
  });

  test('les paramètres de l\'équipe sont un écran de l\'app (MOB-166)', () {
    expect(webOnlyRouteIds, isNot(contains('teamSettings')));
  });

  test('les lieux de l\'équipe sont un écran de l\'app (MOB-168)', () {
    expect(webOnlyRouteIds, isNot(contains('teamAdminPlaces')));
  });

  test('les pages que le hub ouvre sur le site sont dans la langue de '
      'l\'app', () {
    setCurrentLocale('fr');
    expect(TeamWebPaths.pages('velo-club'), '/equipes/velo-club/admin/pages');
    setCurrentLocale('en');
    expect(TeamWebPaths.pages('velo-club'), '/teams/velo-club/admin/pages');
  });

  test('créer et modifier une sortie sont des écrans de l\'app (MOB-80)', () {
    expect(webOnlyRouteIds, isNot(contains('rideNew')));
    expect(webOnlyRouteIds, isNot(contains('rideEdit')));
  });

  test('créer et modifier un parcours sont des écrans de l\'app (MOB-79)', () {
    expect(webOnlyRouteIds, isNot(contains('routeNew')));
    expect(webOnlyRouteIds, isNot(contains('routeEdit')));
  });

  test('créer et modifier une publication sont des écrans de l\'app '
      '(MOB-164)', () {
    expect(webOnlyRouteIds, isNot(contains('postNew')));
    expect(webOnlyRouteIds, isNot(contains('postEdit')));
  });

  test('créer et modifier un voyage sont des écrans de l\'app (MOB-162)', () {
    expect(webOnlyRouteIds, isNot(contains('tripNew')));
    expect(webOnlyRouteIds, isNot(contains('tripEdit')));
  });

  test('les modèles de sortie sont des écrans de l\'app (MOB-78)', () {
    expect(webOnlyRouteIds, isNot(contains('rideTemplates')));
    expect(webOnlyRouteIds, isNot(contains('rideTemplateNew')));
    expect(webOnlyRouteIds, isNot(contains('rideTemplateEdit')));
  });
}
