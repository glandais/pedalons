import 'backend_client.dart';

/// Reads for the ride template tests (ledger `MOB-78`): the template the app created, found by
/// its unique name, and its state after the organizer's gestures.
extension RideTemplatesSeed on BackendClient {
  /// The template named [name] in [teamSlug] as [who] reads it in the list, or `null` while the
  /// API doesn't list it. Reading templates is reserved to organizers and admins.
  Future<Json?> rideTemplateNamed(
    TestUser who,
    String teamSlug,
    String name,
  ) async {
    final list = await get(
      who,
      '/api/teams/$teamSlug/ride-templates',
      query: {'search': name, 'size': 20},
    );
    for (final t in (list['templates'] as List).cast<Json>()) {
      if (t['name'] == name) return t;
    }
    return null;
  }

  /// The template as [who] reads it, or `null` once it is gone. A deleted template answers
  /// **403**, not 404: `RideTemplateAccessChecker` refuses a read when the template no longer
  /// exists. 404 is accepted too, should the API one day tell them apart.
  Future<Json?> rideTemplateOrNull(
    TestUser who,
    String teamSlug,
    String slug,
  ) async {
    final path = '/api/teams/$teamSlug/ride-templates/$slug';
    final code = await status(who, 'GET', path);
    if (code == 403 || code == 404) return null;
    return get(who, path);
  }
}
