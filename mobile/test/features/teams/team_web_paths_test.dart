import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/features/teams/presentation/team_web_paths.dart';

/// Les pages du site qu'ouvre le tableau de bord viennent de
/// `contracts/routes.yaml` (docs/LEDGER_*.md MOB-54), dans la langue de l'app.
/// L'une d'elles porte en plus un état que le web passe en état de routeur,
/// qu'une URL ne transporte pas — le site lit donc ce paramètre
/// (`TeamMembersPage`). Créer et modifier une sortie se font dans l'app
/// depuis `MOB-76`, les modèles de sortie depuis `MOB-78` : ces pages ne sont
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
      'postNew',
      'postEdit',
      'tripEdit',
      'teamAdminReports',
      'teamAdminMembers',
      'teamSettings',
    ]) {
      expect(webOnlyRouteIds, contains(id));
    }
  });

  test('créer et modifier une sortie sont des écrans de l\'app (MOB-76)', () {
    expect(webOnlyRouteIds, isNot(contains('rideNew')));
    expect(webOnlyRouteIds, isNot(contains('rideEdit')));
  });

  test('les modèles de sortie sont des écrans de l\'app (MOB-78)', () {
    expect(webOnlyRouteIds, isNot(contains('rideTemplates')));
    expect(webOnlyRouteIds, isNot(contains('rideTemplateNew')));
    expect(webOnlyRouteIds, isNot(contains('rideTemplateEdit')));
  });
}
