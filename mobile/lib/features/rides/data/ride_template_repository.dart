import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';

final rideTemplateRepositoryProvider = Provider<RideTemplateRepository>((ref) {
  return RideTemplateRepository(ref.watch(rideTemplatesClientProvider));
});

/// Les modèles de sortie d'une équipe, pour leur gestion : liste, lecture,
/// création, réécriture et suppression (docs/LEDGER_*.md MOB-78).
///
/// Le serveur réserve **tout** (lecture comprise) aux organisateurs et
/// administrateurs de l'équipe. `RideEditorRepository.searchTemplates`, lui,
/// reste le sélecteur de l'éditeur de sortie.
class RideTemplateRepository {
  RideTemplateRepository(this._client);

  final RideTemplatesClient _client;

  /// Une page de modèles, filtrée par [search] (vide ou blanc : pas de filtre).
  Future<PageResult<RideTemplateDto>> list(
    String teamSlug, {
    String? search,
    required int page,
    required int size,
  }) async {
    final String? query = search?.trim();
    final RideTemplateListResponse response = await _client.listTemplates(
      teamSlug: teamSlug,
      search: query == null || query.isEmpty ? null : query,
      page: page,
      size: size,
    );
    return PageResult<RideTemplateDto>(
      items: response.templates,
      total: response.total,
    );
  }

  Future<RideTemplateDto> get(String teamSlug, String templateSlug) =>
      _client.getTemplate(teamSlug: teamSlug, templateSlug: templateSlug);

  Future<RideTemplateDto> create(
    String teamSlug,
    RideTemplateRequest request,
  ) => _client.createTemplate(teamSlug: teamSlug, body: request);

  Future<RideTemplateDto> update(
    String teamSlug,
    String templateSlug,
    RideTemplateRequest request,
  ) => _client.updateTemplate(
    teamSlug: teamSlug,
    templateSlug: templateSlug,
    body: request,
  );

  Future<void> delete(String teamSlug, String templateSlug) =>
      _client.deleteTemplate(teamSlug: teamSlug, templateSlug: templateSlug);
}
