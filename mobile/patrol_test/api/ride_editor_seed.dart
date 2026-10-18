import 'backend_client.dart';

/// Reads for the ride editor tests (ledger `MOB-80`): the ride the app created, found by its
/// unique name, and its state after the organizer's gestures.
extension RideEditorSeed on BackendClient {
  /// The slug of the ride named [name] in [teamSlug] — a draft, as the editor creates it unless
  /// told otherwise. `null` while the API doesn't list it.
  Future<String?> rideSlugNamed(
    TestUser who,
    String teamSlug,
    String name, {
    String status = 'DRAFT',
  }) async {
    final list = await get(
      who,
      '/api/teams/$teamSlug/publications',
      query: {'search': name, 'status': status, 'size': 20},
    );
    for (final p in (list['publications'] as List).cast<Json>()) {
      if (p['name'] == name) return p['slug'] as String;
    }
    return null;
  }

  /// The ride as [who] reads it, or `null` when the API answers 404 (a deleted ride may be
  /// either gone or flagged `deleted`, depending on who reads it).
  Future<Json?> rideOrNull(TestUser who, String teamSlug, String rideSlug) =>
      getOrNull(who, '/api/teams/$teamSlug/rides/$rideSlug');
}
