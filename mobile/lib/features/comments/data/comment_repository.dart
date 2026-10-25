import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

/// Ce sur quoi on commente.
///
/// Les cinq clients générés ont la même forme mais aucune interface commune :
/// `listRideComments`, `listPostComments`, `listRouteComments`,
/// `listTripComments`, `listTripStageComments`. L'aiguillage tient dans ce
/// `switch`, une fois, plutôt que dans chaque écran qui affiche un fil.
///
/// Une étape (`stage`) a son propre fil, distinct de celui du voyage ; son slug
/// est unique dans l'équipe, le voyage n'entre donc pas dans la cible.
enum CommentEntity { ride, post, route, trip, stage }

/// L'objet commenté : son type, son équipe, son slug.
@immutable
class CommentTarget {
  const CommentTarget({
    required this.entity,
    required this.teamSlug,
    required this.slug,
  });

  final CommentEntity entity;
  final String teamSlug;
  final String slug;

  @override
  bool operator ==(Object other) =>
      other is CommentTarget &&
      other.entity == entity &&
      other.teamSlug == teamSlug &&
      other.slug == slug;

  @override
  int get hashCode => Object.hash(entity, teamSlug, slug);

  @override
  String toString() => 'CommentTarget(${entity.name} $teamSlug/$slug)';
}

final commentRepositoryProvider = Provider<CommentRepository>((Ref ref) {
  return CommentRepository(
    rides: ref.watch(rideCommentsClientProvider),
    posts: ref.watch(postCommentsClientProvider),
    routes: ref.watch(routeCommentsClientProvider),
    trips: ref.watch(tripCommentsClientProvider),
    stages: ref.watch(tripStageCommentsClientProvider),
  );
});

/// Le seul accès aux commentaires, quel que soit l'objet commenté.
class CommentRepository {
  CommentRepository({
    required this._rides,
    required this._posts,
    required this._routes,
    required this._trips,
    required this._stages,
  });

  final RideCommentsClient _rides;
  final PostCommentsClient _posts;
  final RouteCommentsClient _routes;
  final TripCommentsClient _trips;
  final TripStageCommentsClient _stages;

  /// Une page de commentaires.
  ///
  /// [parentId] nul rend les commentaires de **premier niveau** ; renseigné, il
  /// rend les réponses d'un fil. C'est ce qui permet de ne charger les réponses
  /// qu'à la demande, quand `replyCount` dépasse ce que la page a embarqué.
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) => switch (target.entity) {
    CommentEntity.ride => _rides.listRideComments(
      teamSlug: target.teamSlug,
      entitySlug: target.slug,
      page: page,
      size: size,
      parentId: parentId,
      sort: sort,
    ),
    CommentEntity.post => _posts.listPostComments(
      teamSlug: target.teamSlug,
      entitySlug: target.slug,
      page: page,
      size: size,
      parentId: parentId,
      sort: sort,
    ),
    CommentEntity.route => _routes.listRouteComments(
      teamSlug: target.teamSlug,
      entitySlug: target.slug,
      page: page,
      size: size,
      parentId: parentId,
      sort: sort,
    ),
    CommentEntity.trip => _trips.listTripComments(
      teamSlug: target.teamSlug,
      entitySlug: target.slug,
      page: page,
      size: size,
      parentId: parentId,
      sort: sort,
    ),
    CommentEntity.stage => _stages.listTripStageComments(
      teamSlug: target.teamSlug,
      entitySlug: target.slug,
      page: page,
      size: size,
      parentId: parentId,
      sort: sort,
    ),
  };

  Future<CommentDto> create(
    CommentTarget target, {
    required String content,
    String? parentId,
  }) {
    final CommentRequest body = CommentRequest(
      content: content,
      parentId: parentId,
    );
    return switch (target.entity) {
      CommentEntity.ride => _rides.createRideComment(
        teamSlug: target.teamSlug,
        entitySlug: target.slug,
        body: body,
      ),
      CommentEntity.post => _posts.createPostComment(
        teamSlug: target.teamSlug,
        entitySlug: target.slug,
        body: body,
      ),
      CommentEntity.route => _routes.createRouteComment(
        teamSlug: target.teamSlug,
        entitySlug: target.slug,
        body: body,
      ),
      CommentEntity.trip => _trips.createTripComment(
        teamSlug: target.teamSlug,
        entitySlug: target.slug,
        body: body,
      ),
      CommentEntity.stage => _stages.createTripStageComment(
        teamSlug: target.teamSlug,
        entitySlug: target.slug,
        body: body,
      ),
    };
  }

  Future<void> delete(CommentTarget target, String commentId) =>
      switch (target.entity) {
        CommentEntity.ride => _rides.deleteRideComment(
          teamSlug: target.teamSlug,
          entitySlug: target.slug,
          commentId: commentId,
        ),
        CommentEntity.post => _posts.deletePostComment(
          teamSlug: target.teamSlug,
          entitySlug: target.slug,
          commentId: commentId,
        ),
        CommentEntity.route => _routes.deleteRouteComment(
          teamSlug: target.teamSlug,
          entitySlug: target.slug,
          commentId: commentId,
        ),
        CommentEntity.trip => _trips.deleteTripComment(
          teamSlug: target.teamSlug,
          entitySlug: target.slug,
          commentId: commentId,
        ),
        CommentEntity.stage => _stages.deleteTripStageComment(
          teamSlug: target.teamSlug,
          entitySlug: target.slug,
          commentId: commentId,
        ),
      };
}
