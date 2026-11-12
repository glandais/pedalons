import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../data/comment_repository.dart';

/// Le fil de commentaires de premier niveau, paginé.
///
/// **`itemTotal` et non `total`** alimente le compteur : `total` compte les
/// réponses, `itemTotal` les commentaires racine, et c'est bien « 3
/// commentaires » qu'on annonce au-dessus de trois fils.
final commentThreadProvider = StateNotifierProvider.autoDispose
    .family<CommentThreadNotifier, PagedListState<CommentDto>, CommentTarget>((
      Ref ref,
      CommentTarget target,
    ) {
      return CommentThreadNotifier(
        ref.watch(commentRepositoryProvider),
        target,
      );
    });

class CommentThreadNotifier extends PagedListNotifier<CommentDto> {
  CommentThreadNotifier(this._repository, this._target);

  final CommentRepository _repository;
  final CommentTarget _target;

  /// Réponses chargées à la demande, par identifiant de parent.
  ///
  /// Elles ne vivent pas dans la liste paginée : ce sont des enfants, pas des
  /// pages. Les y mêler ferait sauter la déduplication par `itemKey` et le
  /// compteur de pages.
  final Map<String, List<CommentDto>> _loadedReplies =
      <String, List<CommentDto>>{};

  @override
  Future<PageResult<CommentDto>> fetchPage(int page) async {
    final CommentListResponse response = await _repository.list(
      _target,
      page: page,
      size: pageSize,
      // Du plus ancien au plus récent, comme le site (règle RL5 des listes) :
      // une conversation se lit dans l'ordre. C'est le défaut du serveur,
      // demandé quand même pour ne pas en dépendre.
      sort: SortDirection.asc,
    );
    return PageResult<CommentDto>(
      items: response.items,
      total: response.itemTotal,
    );
  }

  @override
  Object? itemKey(CommentDto item) => item.id;

  /// Les réponses déjà connues d'un commentaire : celles embarquées dans la
  /// page, ou celles chargées ensuite.
  List<CommentDto> repliesOf(CommentDto comment) =>
      _loadedReplies[comment.id] ?? comment.replies;

  /// Reste-t-il des réponses à demander ?
  ///
  /// La page embarque un aperçu ; `replyCount` dit le vrai total. L'écart est
  /// exactement ce qui justifie un appel `parentId`.
  bool hasMoreReplies(CommentDto comment) =>
      comment.replyCount > repliesOf(comment).length;

  Future<void> loadReplies(CommentDto comment) async {
    if (!hasMoreReplies(comment)) return;
    final CommentListResponse response = await _repository.list(
      _target,
      parentId: comment.id,
      size: 100,
    );
    if (!mounted) return;
    _loadedReplies[comment.id] = response.items;
    // La liste ne change pas, mais son rendu si : on la republie à l'identique
    // pour que les abonnés relisent `repliesOf`.
    state = state.copyWith(items: List<CommentDto>.of(state.items));
  }

  Future<void> post({required String content, String? parentId}) async {
    await _repository.create(_target, content: content, parentId: parentId);
    // Publier renumérote la pagination : on repart de la page 0 plutôt que
    // d'insérer à l'aveugle un item dont on ignore la place dans le tri.
    _loadedReplies.clear();
    await loadFirstPage(refreshing: true);
  }

  Future<void> remove(CommentDto comment) async {
    await _repository.delete(_target, comment.id);
    _loadedReplies.clear();
    await loadFirstPage(refreshing: true);
  }
}
