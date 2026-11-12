import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../data/publication_feed_repository.dart';

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
/// `when` et `participating` disent quels événements datés la liste montre, et
/// dans quel ordre. `when=UPCOMING_FIRST` (contrat 14.8.0, règle RL15 des
/// listes) sert **une seule liste à deux sections** : « À venir », du plus
/// proche au plus lointain, puis « Plus tôt », du plus récent au plus ancien
/// — les publications y sont, à leur date de parution. C'est l'ordre de
/// l'Agenda d'une équipe et du fil d'accueil, sauf sous « Publications »
/// seules (`when` nul). `participating` : « Je participe ». `datedOnly` :
/// sorties et voyages seulement, sans publications — l'Agenda.
typedef PublicationFeedKey = ({
  String? teamSlug,
  PublicationType? type,
  String? search,
  MinRole? minRole,
  String? tags,
  PublicationWhen? when,
  bool participating,
  bool datedOnly,
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
/// `membershipDefaultScopeProvider` —, à distinguer du choix explicite de
/// « toutes », qui doit survivre au chargement de mes équipes. Sans objet sur
/// un fil d'équipe, où la portée est l'écran lui-même.
final publicationFeedScopeProvider = StateProvider.autoDispose
    .family<PublicationFeedScopeChoice?, String?>((ref, teamSlug) => null);

/// « Je participe » sur le fil d'accueil, par portée : la période « Tout / Je
/// participe » (règle RL3). L'Agenda d'une équipe tient la sienne lui-même.
final publicationFeedParticipatingProvider = StateProvider.autoDispose
    .family<bool, String?>((ref, scope) => false);

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
    .family<int, PublicationFeedKey>(
      (Ref ref, PublicationFeedKey key) =>
          ref.watch(publicationFeedRepositoryProvider).count(key),
    );

class PublicationFeedNotifier extends PagedListNotifier<PublicationDto> {
  PublicationFeedNotifier(PublicationsClient client, this._key)
    : _repository = PublicationFeedRepository(client);

  final PublicationFeedRepository _repository;
  final PublicationFeedKey _key;

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) =>
      _repository.fetchPage(_key, page: page, size: pageSize);

  @override
  Object? itemKey(PublicationDto item) => item.id;
}
