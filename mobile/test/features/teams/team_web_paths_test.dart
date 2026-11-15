import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/features/teams/presentation/team_web_paths.dart';

/// Les pages du site qu'ouvre le tableau de bord viennent de
/// `contracts/routes.yaml` (docs/LEDGER_*.md MOB-54), dans la langue de l'app.
/// L'une d'elles porte en plus un état que le web passe en état de routeur,
/// qu'une URL ne transporte pas — le site lit donc ce paramètre
/// (`TeamMembersPage`). Créer et modifier une sortie se font dans l'app
/// depuis `MOB-80`, les modèles de sortie depuis `MOB-78` : ces pages ne sont
/// plus du site.
void main() {
  tearDown(() => setCurrentLocale('fr'));

  test('« Inviter » ouvre le dialogue d\'invitation', () {
    setCurrentLocale('en');
    expect(
      TeamWebPaths.adminMembersInvite('velo-club'),
      '/teams/velo-club/admin/members?invite=1',
    );
    setCurrentLocale('fr');
    expect(
      TeamWebPaths.adminMembersInvite('velo-club'),
      '/equipes/velo-club/admin/membres?invite=1',
    );
  });

  test('chaque page du tableau de bord est une page du site sans écran', () {
    // `appScreen: false` dans le contrat : le lien part dans le navigateur,
    // jamais sur le routeur de l'app.
    for (final String id in <String>[
      'teamAdminReports',
      'teamAdminMembers',
      // Ouvertes par le hub « Gestion de l'équipe » tant que leur écran
      // n'existe pas (MOB-165).
      'teamAdminPlaces',
      'teamAdminTags',
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

  test('les paramètres de l\'équipe sont un écran de l\'app (MOB-166)', () {
    expect(webOnlyRouteIds, isNot(contains('teamSettings')));
  });

  test('les pages que le hub ouvre sur le site sont dans la langue de '
      'l\'app', () {
    setCurrentLocale('fr');
    expect(TeamWebPaths.places('velo-club'), '/equipes/velo-club/admin/lieux');
    expect(TeamWebPaths.tags('velo-club'), '/equipes/velo-club/admin/tags');
    expect(TeamWebPaths.pages('velo-club'), '/equipes/velo-club/admin/pages');
    setCurrentLocale('en');
    expect(TeamWebPaths.places('velo-club'), '/teams/velo-club/admin/places');
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
