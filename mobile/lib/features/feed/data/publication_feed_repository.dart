import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../providers/publication_feed_provider.dart';

final publicationFeedRepositoryProvider = Provider<PublicationFeedRepository>(
  (Ref ref) => PublicationFeedRepository(ref.watch(publicationsClientProvider)),
);

/// Le seul endroit où le fil — accueil, Agenda, Publications d'une équipe —
/// interroge l'API.
///
/// [fetchPage] est **la** méthode qui envoie `when=UPCOMING_FIRST` (règle
/// RL15) : une liste à deux sections passe par elle, et par elle seule, sans
/// seconde requête. [count] ne sert qu'aux listes d'un seul tenant (le compteur
/// global laisse la place aux compteurs de section).
class PublicationFeedRepository {
  PublicationFeedRepository(this._client);

  final PublicationsClient _client;

  /// Une page du jeu de résultats [key].
  ///
  /// `key.datedOnly` (l'Agenda : sorties et voyages seulement) envoie
  /// `dated=true` : sans lui, une liste `UPCOMING_FIRST` sans type range les
  /// publications dans « Plus tôt ».
  Future<PageResult<PublicationDto>> fetchPage(
    PublicationFeedKey key, {
    required int page,
    required int size,
  }) async {
    final String? teamSlug = key.teamSlug;
    final PublicationListResponse response = teamSlug == null
        ? await _client.listAllPublications(
            page: page,
            size: size,
            type: key.type,
            search: _trimmed(key.search),
            minRole: key.minRole,
            whenField: key.when,
            participating: key.participating,
            dated: key.datedOnly ? true : null,
            // **Vue compacte.** Sans elle, chaque page embarque vingt corps
            // markdown complets pour rendre deux lignes d'extrait. `excerpt`
            // et `thumbnailUrl` sont présents dans les deux vues ; ce sont eux
            // que la carte lit.
            view: ListViewMode.compact,
          )
        : await _client.listPublications(
            teamSlug: teamSlug,
            page: page,
            size: size,
            type: key.type,
            search: _trimmed(key.search),
            tags: _tagList(key.tags),
            whenField: key.when,
            participating: key.participating,
            dated: key.datedOnly ? true : null,
            view: ListViewMode.compact,
          );
    return PageResult<PublicationDto>(
      items: response.publications,
      total: response.total,
      // Avec `when=UPCOMING_FIRST` : la taille de « À venir », la même sur
      // toutes les pages (`upcomingTotal`, contrat 14.8.0).
      firstSectionTotal: key.when == PublicationWhen.upcomingFirst
          ? response.upcomingTotal ?? 0
          : null,
    );
  }

  /// Combien de publications répondent à [key].
  Future<int> count(PublicationFeedKey key) async {
    final String? search = _trimmed(key.search);
    final CountResponse response = key.teamSlug == null
        ? await _client.countAllPublications(
            type: key.type,
            search: search,
            minRole: key.minRole,
            whenField: key.when,
            participating: key.participating,
            dated: key.datedOnly ? true : null,
          )
        : await _client.countPublications(
            teamSlug: key.teamSlug!,
            type: key.type,
            search: search,
            tags: _tagList(key.tags),
            whenField: key.when,
            participating: key.participating,
            dated: key.datedOnly ? true : null,
          );
    return response.total;
  }

  static String? _trimmed(String? value) {
    final String? v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static List<String>? _tagList(String? tags) =>
      tags == null || tags.isEmpty ? null : tags.split(',');
}
