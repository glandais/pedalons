import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../../teams/providers/team_providers.dart';

/// Ce qui identifie un jeu de résultats du fil : une portée et ses filtres.
///
/// **Tous les filtres font partie de la clé**, et c'est la propriété qui
/// compte : changer un filtre construit un notifier neuf plutôt que de muter
/// l'actuel, ce qui interdit à deux jeux de résultats de se mélanger dans la
/// même liste.
///
/// `tags` est la sélection de tags **jointe par des virgules** (`a,b`), et non
/// une liste : un record compare ses champs par `==`, et deux `List` égales
/// n'y sont pas égales — chaque reconstruction aurait créé un notifier neuf.
/// Le serveur accepte d'ailleurs `?tags=a,b` tel quel.
///
/// `when` et `participating` sont les filtres de date de l'Agenda d'une équipe
/// (ledger `MOB-60`, contrat 10.15.0) : « À venir » (`UPCOMING`), « Je
/// participe » (`UPCOMING` + `participating`) et « Passées » (`PAST`). Le
/// serveur en déduit le tri — le plus proche d'abord pour l'avenir, le plus
/// récent d'abord pour le passé — et en écarte les publications, qui n'ont pas
/// de fin. `null` et `false` ailleurs : le fil d'accueil et les Publications.
typedef PublicationFeedKey = ({
  String? teamSlug,
  PublicationType? type,
  String? search,
  MinRole? minRole,
  String? tags,
  PublicationWhen? when,
  bool participating,
});

/// Filtre de type courant, par portée. Le fil d'accueil et un fil d'équipe
/// gardent chacun leur sélection.
final publicationFeedTypeProvider = StateProvider.autoDispose
    .family<PublicationType?, String?>((ref, teamSlug) => null);

/// Tags choisis sur un fil d'équipe, par portée (ledger `MOB-39`).
///
/// N'a d'effet qu'avec un type choisi : un fil d'équipe filtré par type *est*
/// la liste dédiée de ce type, la seule où le serveur filtre par tag (plan des
/// tags, D13) — le fil mixte ne l'est pas. Les tags étant un jeu par type,
/// changer de type les lève (`PublicationFeedView`).
final publicationFeedTagsProvider = StateProvider.autoDispose
    .family<List<String>, String?>((ref, teamSlug) => const <String>[]);

/// La valeur `tags` d'une [PublicationFeedKey] : nulle hors d'une liste
/// dédiée d'équipe, ou sans sélection.
String? feedTagsKey({
  required String? teamSlug,
  required PublicationType? type,
  required List<String> tagIds,
}) {
  if (teamSlug == null || type == null || tagIds.isEmpty) return null;
  return tagIds.join(',');
}

List<String>? _tagList(String? tags) =>
    tags == null || tags.isEmpty ? null : tags.split(',');

/// Recherche plein texte du fil, par portée.
///
/// Le fil était le seul écran de liste sans champ de recherche alors que
/// `GET /api/publications` accepte `search` depuis toujours (F-DE-4). C'est
/// aussi ce qui donne au fil un **vide filtré** distinct de son vide absolu,
/// et donc une sortie de secours (« Effacer la recherche », F-DE-9).
final publicationFeedSearchProvider = StateProvider.autoDispose
    .family<String?, String?>((ref, teamSlug) => null);

/// Une portée **choisie** : `minRole` nul veut dire « toutes les équipes ».
typedef PublicationFeedScopeChoice = ({MinRole? minRole});

/// Portée choisie sur le fil d'accueil : toutes les équipes, ou seulement
/// celles où je tiens au moins tel rôle.
///
/// `null` signifie « pas encore choisi » — le fil suit alors
/// [homeFeedDefaultScopeProvider] —, à distinguer du choix explicite de
/// « toutes », qui doit survivre au chargement de mes équipes. Sans objet sur
/// un fil d'équipe, où la portée est l'écran lui-même.
final publicationFeedScopeProvider = StateProvider.autoDispose
    .family<PublicationFeedScopeChoice?, String?>((ref, teamSlug) => null);

/// La portée de départ du fil d'accueil, la même que sur le web
/// (`useMembershipDefault`) : « Membre », sauf pour qui n'a aucune équipe, à
/// qui elle ne montrerait qu'un fil vide. Optimiste pendant le chargement : la
/// plupart des personnes ont une équipe.
final homeFeedDefaultScopeProvider = Provider.autoDispose<MinRole?>((ref) {
  final List<TeamDetailDto>? teams = ref.watch(myTeamsProvider).value;
  return teams != null && teams.isEmpty ? null : MinRole.member;
});

/// Le fil paginé d'une portée et de ses filtres.
final publicationFeedProvider = StateNotifierProvider.autoDispose
    .family<
      PublicationFeedNotifier,
      PagedListState<PublicationDto>,
      PublicationFeedKey
    >((ref, key) {
      return PublicationFeedNotifier(
        ref.watch(publicationsClientProvider),
        key,
      );
    });

/// Combien de publications répondent à ces filtres.
///
/// Un appel séparé, parce que l'en-tête doit annoncer le total **avant** que
/// tout soit chargé : « 1 248 publications » se dit dès la première page.
final publicationFeedCountProvider = FutureProvider.autoDispose
    .family<int, PublicationFeedKey>((Ref ref, PublicationFeedKey key) async {
      final PublicationsClient client = ref.watch(publicationsClientProvider);
      final String? search = _trimmed(key.search);
      final CountResponse response = key.teamSlug == null
          ? await client.countAllPublications(
              type: key.type,
              search: search,
              minRole: key.minRole,
            )
          : await client.countPublications(
              teamSlug: key.teamSlug!,
              type: key.type,
              search: search,
              tags: _tagList(key.tags),
              whenField: key.when,
              participating: key.participating,
            );
      return response.total;
    });

String? _trimmed(String? value) {
  final String? v = value?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

class PublicationFeedNotifier extends PagedListNotifier<PublicationDto> {
  PublicationFeedNotifier(this._client, this._key);

  final PublicationsClient _client;
  final PublicationFeedKey _key;

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) async {
    final String? teamSlug = _key.teamSlug;
    final PublicationListResponse response = teamSlug == null
        ? await _client.listAllPublications(
            page: page,
            size: pageSize,
            type: _key.type,
            search: _trimmed(_key.search),
            minRole: _key.minRole,
            // **Vue compacte.** Sans elle, chaque page embarque vingt corps
            // markdown complets pour rendre deux lignes d'extrait. `excerpt`
            // et `thumbnailUrl` sont présents dans les deux vues ; ce sont eux
            // que la carte lit.
            view: ListViewMode.compact,
          )
        : await _client.listPublications(
            teamSlug: teamSlug,
            page: page,
            size: pageSize,
            type: _key.type,
            search: _trimmed(_key.search),
            tags: _tagList(_key.tags),
            whenField: _key.when,
            participating: _key.participating,
            view: ListViewMode.compact,
          );
    return PageResult<PublicationDto>(
      items: response.publications,
      total: response.total,
    );
  }

  @override
  Object? itemKey(PublicationDto item) => item.id;
}
