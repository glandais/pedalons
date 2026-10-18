import 'api/routes_seed.dart';
import 'common.dart';

/// Web counterpart: `CreateRoutePage` / `EditRoutePage` are organizers' pages. In the app (ledger
/// `MOB-79`), a plain member reads the team's routes with no « Ajouter », a route with no pencil,
/// and the creation and edition links opened by hand show the organizers-only refusal rather than
/// a form that would end in a 403.
///
/// **Written, not yet run** (ledger `MOB-77`).
void main() {
  testApp(
    'A plain member gets no Add button, no pencil, and a refusal from the editor links',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Parcours refus owner');
      final member = await backend.newUser('Parcours refus membre');
      final team = await backend.newTeam(owner, 'Equipe parcours refus');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);
      final name = unique('Boucle gardee');
      final route = await backend.newRoute(owner, teamSlug, name);
      final routeSlug = route['slug'] as String;

      await openAppSignedIn($, member);
      await openLink($, Paths.routes(teamSlug));
      await modules.routeEditor.waitUntilTeamRoutesShown();
      expect(modules.routeEditor.offersAdd, isFalse);

      await openLink($, Paths.route(teamSlug, routeSlug));
      await modules.routeEditor.waitUntilRouteTitleIs(name);
      expect(modules.routeEditor.offersEdit, isFalse);

      await openLink($, Paths.routeNew(teamSlug));
      expect(await modules.routeEditor.showsForbidden(), isTrue);

      await openLink($, Paths.routeEdit(teamSlug, routeSlug));
      expect(await modules.routeEditor.showsForbidden(), isTrue);
    },
  );
}
