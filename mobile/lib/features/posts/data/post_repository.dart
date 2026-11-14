import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(postsClientProvider));
});

class PostRepository {
  final PostsClient _postsClient;

  PostRepository(this._postsClient);

  Future<PostDto> getPost(String teamSlug, String postSlug) {
    return _postsClient.getPost(teamSlug: teamSlug, postSlug: postSlug);
  }

  // --- Écriture (docs/LEDGER_*.md MOB-156).

  Future<PostDto> createPost(String teamSlug, PostRequest request) {
    return _postsClient.createPost(teamSlug: teamSlug, body: request);
  }

  Future<PostDto> updatePost(
    String teamSlug,
    String postSlug,
    PostRequest request,
  ) {
    return _postsClient.updatePost(
      teamSlug: teamSlug,
      postSlug: postSlug,
      body: request,
    );
  }

  /// Change le seul statut : un PUT recopié depuis un détail périmé pourrait
  /// renvoyer des tags supprimés entre-temps (`TAG_INVALID`).
  Future<PostDto> changeStatus(
    String teamSlug,
    String postSlug,
    Status status,
  ) {
    return _postsClient.changePostStatus(
      teamSlug: teamSlug,
      postSlug: postSlug,
      body: StatusChangeRequest(status: status.toJson()),
    );
  }

  /// Change l'adresse (le slug). Les liens vers l'ancienne ne mènent plus
  /// nulle part.
  Future<PostDto> changeSlug(String teamSlug, String postSlug, String slug) {
    return _postsClient.changePostSlug(
      teamSlug: teamSlug,
      postSlug: postSlug,
      body: SlugChangeRequest(slug: slug),
    );
  }

  Future<void> deletePost(String teamSlug, String postSlug) {
    return _postsClient.deletePost(teamSlug: teamSlug, postSlug: postSlug);
  }

  Future<PostDto> undeletePost(String teamSlug, String postSlug) {
    return _postsClient.undeletePost(teamSlug: teamSlug, postSlug: postSlug);
  }
}
