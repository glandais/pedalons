import 'api/ride_templates_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-rides.e2e.ts` › ride templates (`RideTemplateListPage`,
/// `Create/EditRideTemplatePage`). In the app since ledger `MOB-78`: the dashboard's « Gérer les
/// modèles », the list, the form and the menu behind `⋯`. What leaves the app is checked through
/// the API — the PUT rewrites every field, and a ride started from the template advances its
/// `nextNumber`.
///
/// Written, not yet run (ledger `MOB-77`).
void main() {
  testApp('An organizer creates, edits, uses and deletes a ride template', (
    $,
    modules,
    apiClients,
  ) async {
    final backend = apiClients.backend;
    final owner = await backend.newUser('Modele owner');
    final organizer = await backend.newUser('Modele orga');
    final team = await backend.newTeam(owner, 'Equipe modele');
    final teamSlug = team['slug'] as String;
    await backend.addMember(teamSlug, organizer, role: 'ORGANIZER');

    // Le tableau de bord → « Gérer les modèles » → la liste, vide.
    await openAppSignedIn($, organizer);
    await openLink($, Paths.team(teamSlug));
    await modules.rideTemplates.openFromDashboard();
    await modules.rideTemplates.showsEmpty();

    // Création : un nom, le numéro 41, le groupe renommé, 12 places.
    final name = unique('Modele dimanche');
    await modules.rideTemplates.startNew();
    await modules.rideTemplates.enterName(name);
    await modules.rideTemplates.enterNextNumber('41');
    await modules.rideTemplates.enterGroupName(0, 'Rapides');
    await modules.rideTemplates.enterGroupMax(0, '12');
    await modules.rideTemplates.save();
    await modules.rideTemplates.waitUntilListShown();

    final created = await eventually(
      () => backend.rideTemplateNamed(organizer, teamSlug, name),
      until: (template) => template != null,
      description: 'the created template listed',
      timeout: const Duration(seconds: 15),
    );
    final templateSlug = created!['slug'] as String;
    expect(created['nextNumber'], 41);
    final groups = (created['groups'] as List).cast<Json>();
    expect(groups.length, 1);
    expect(groups.single['name'], 'Rapides');
    expect(groups.single['maxParticipants'], 12);
    final groupId = groups.single['id'] as String;
    await modules.rideTemplates.cardShows(templateSlug, 'prochaine sortie #41');

    // Modification, depuis le menu : le numéro passe à 50, le groupe reste le même.
    await modules.rideTemplates.editFromMenu(templateSlug);
    await modules.rideTemplates.enterNextNumber('50');
    await modules.rideTemplates.save();
    await modules.rideTemplates.cardShows(templateSlug, 'prochaine sortie #50');
    final edited = await backend.rideTemplateOrNull(
      organizer,
      teamSlug,
      templateSlug,
    );
    expect(edited!['nextNumber'], 50);
    expect((edited['groups'] as List).cast<Json>().map((g) => g['id']), [
      groupId,
    ]);

    // Créer une sortie depuis le modèle : titrée « <nom> #50 », et le numéro avance.
    await modules.rideTemplates.createRideFromMenu(templateSlug);
    await modules.rideEditor.waitUntilNameReads('$name #50');
    await modules.rideEditor.save();
    await modules.rideEditor.waitUntilRideTitleIs('$name #50');
    await eventually(
      () => backend.rideTemplateOrNull(organizer, teamSlug, templateSlug),
      until: (template) => template != null && template['nextNumber'] == 51,
      description: 'the template advanced to #51',
      timeout: const Duration(seconds: 15),
    );

    // Supprimer, après confirmation : la liste est vide, le modèle n'existe plus.
    await openLink($, Paths.rideTemplates(teamSlug));
    await modules.rideTemplates.waitUntilListShown();
    await modules.rideTemplates.deleteFromMenu(templateSlug);
    await modules.rideTemplates.showsEmpty();
    await eventually(
      () => backend.rideTemplateOrNull(organizer, teamSlug, templateSlug),
      until: (template) => template == null,
      description: 'the template deleted',
      timeout: const Duration(seconds: 15),
    );
  });
}
