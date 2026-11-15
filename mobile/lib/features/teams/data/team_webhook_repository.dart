import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final teamWebhookRepositoryProvider = Provider<TeamWebhookRepository>((ref) {
  return TeamWebhookRepository(ref.watch(teamWebhookClientProvider));
});

/// Borne de `TeamWebhookRequest.url` au contrat.
const int kTeamWebhookUrlMaxLength = 1000;

/// Le webhook sortant d'une équipe (`/api/teams/{teamSlug}/webhook`,
/// administrateurs seulement — docs/LEDGER_*.md MOB-166) : ses annonces
/// publiées dans Slack, Discord, Mattermost ou sur une adresse https.
///
/// **L'URL est un secret** : l'API ne la rend jamais que masquée
/// (`TeamWebhookDto.maskedUrl`), et l'app n'en garde aucune copie.
class TeamWebhookRepository {
  TeamWebhookRepository(this._client);

  final TeamWebhookClient _client;

  /// L'état du webhook ; `configured` faux quand l'équipe n'en a pas.
  Future<TeamWebhookDto> get(String teamSlug) {
    return _client.getTeamWebhook(teamSlug: teamSlug);
  }

  /// Enregistre le webhook. [url] nul **garde l'adresse actuelle** : le champ
  /// est alors absent de la requête. Il est requis pour une première
  /// configuration. `WEBHOOK_URL_INVALID` si l'adresse n'est pas une adresse
  /// https publique.
  Future<TeamWebhookDto> save(
    String teamSlug, {
    String? url,
    required String language,
    required bool enabled,
  }) {
    return _client.saveTeamWebhook(
      teamSlug: teamSlug,
      body: TeamWebhookRequest(url: url, language: language, enabled: enabled),
    );
  }

  /// Envoie un message de test au webhook **enregistré**, pas à ce qui est
  /// saisi.
  Future<TeamWebhookTestDto> test(String teamSlug) {
    return _client.testTeamWebhook(teamSlug: teamSlug);
  }

  Future<void> delete(String teamSlug) {
    return _client.deleteTeamWebhook(teamSlug: teamSlug);
  }
}
