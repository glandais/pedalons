import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';
import '../../rides/domain/ride_form.dart'
    show instantToWallTime, kRideMarkdownMaxLength, parseWallTime, wallTimeOf;
import '../../rides/domain/ride_permissions.dart';
import '../../visibility/domain/content_visibility.dart';

/// Bornes de `PostRequest` au contrat. Le texte (`MediaDto`) a celle de la
/// sortie : [kRideMarkdownMaxLength], le même DTO.
const int kPostNameMaxLength = 200;
const int kPostMaxTags = 10;

/// Qui peut créer une publication : la règle de rôle des sorties
/// ([canManageRides] — `PostAccessChecker` demande `teamRole.isOrganizer()`)
/// et le seul module publications (docs/LEDGER_*.md MOB-156). Modifier et
/// supprimer suivent, eux, le `permissions` de la publication.
bool canManageTeamPosts(
  TeamDetailDto team, {
  required TeamRole? teamRole,
  bool platformAdmin = false,
}) {
  return team.enablePosts &&
      canManageRides(teamRole: teamRole, platformAdmin: platformAdmin);
}

/// Le formulaire d'une publication : ce que `PostRequest` porte.
///
/// Les dates sont des **heures murales du fuseau de la publication**, dans la
/// forme du contrat — celui de l'équipe à la création, `PostDto.timezone` à
/// la modification : une publication n'a pas de lieu (ledger `API-60`).
@immutable
class PostForm {
  const PostForm({
    required this.name,
    required this.media,
    required this.dateTime,
    required this.status,
    required this.visibility,
    required this.signedAsTeam,
    this.publishAt,
    this.tagIds = const <String>[],
  });

  /// Le formulaire vide du site (`CreatePostPage`) : maintenant dans le
  /// fuseau de l'équipe, la visibilité de départ que donne le backend,
  /// brouillon, signée comme l'équipe le veut par défaut (ledger `API-6`).
  factory PostForm.initial(TeamDetailDto team, {DateTime? now}) => PostForm(
    name: '',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    dateTime: wallTimeOf(
      AppFormatters.toZoneTime((now ?? DateTime.now()).toUtc(), team.timezone),
    ),
    status: Status.draft,
    visibility: defaultContentVisibilityOf(team),
    signedAsTeam: team.postsAsTeamByDefault,
  );

  /// La publication telle qu'elle est, prête à être réécrite — ce que
  /// `postToRequest` fait au site.
  factory PostForm.fromPost(PostDto post) => PostForm(
    name: post.name,
    media: post.media,
    dateTime: instantToWallTime(post.dateTime, post.timezone) ?? post.dateTime,
    status: Status.fromJson(post.status),
    visibility: Visibility.fromJson(post.visibility),
    signedAsTeam: post.signedAsTeam,
    publishAt: instantToWallTime(post.publishAt, post.timezone),
    tagIds: <String>[for (final TagDto tag in post.tags) tag.id],
  );

  final String name;
  final MediaDto media;

  /// Heure murale du fuseau de la publication, forme du contrat.
  final String dateTime;
  final Status status;
  final Visibility visibility;
  final bool signedAsTeam;

  /// Heure murale ; seulement lue par le serveur en brouillon.
  final String? publishAt;
  final List<String> tagIds;

  PostForm copyWith({
    String? name,
    MediaDto? media,
    String? dateTime,
    Status? status,
    Visibility? visibility,
    bool? signedAsTeam,
    String? Function()? publishAt,
    List<String>? tagIds,
  }) => PostForm(
    name: name ?? this.name,
    media: media ?? this.media,
    dateTime: dateTime ?? this.dateTime,
    status: status ?? this.status,
    visibility: visibility ?? this.visibility,
    signedAsTeam: signedAsTeam ?? this.signedAsTeam,
    publishAt: publishAt == null ? this.publishAt : publishAt(),
    tagIds: tagIds ?? this.tagIds,
  );

  /// La requête. [tagIds] part toujours, `[]` compris, qui veut dire « plus
  /// aucun » — nul, il laisserait les tags tels quels en modification.
  PostRequest toRequest() => PostRequest(
    name: name.trim(),
    media: media,
    dateTime: dateTime,
    status: status.toJson(),
    visibility: visibility.toJson(),
    publishAt: status == Status.draft ? publishAt : null,
    signedAsTeam: signedAsTeam,
    tagIds: tagIds,
  );

  // --- Validation : les contraintes de `PostRequest`, lues avant d'envoyer.

  bool get nameValid {
    final int length = name.trim().length;
    return length >= 1 && length <= kPostNameMaxLength;
  }

  bool get markdownValid => media.markdown.length <= kRideMarkdownMaxLength;

  bool get dateTimeValid => parseWallTime(dateTime) != null;

  bool get tagsValid => tagIds.length <= kPostMaxTags;

  /// En brouillon, une publication programmée doit être à venir — comparée
  /// dans le fuseau de la publication [zone], pas celui du lecteur.
  bool publishAtValid(String zone, {DateTime? now}) {
    if (status != Status.draft || publishAt == null) return true;
    final DateTime? wall = parseWallTime(publishAt);
    if (wall == null) return false;
    final DateTime nowWall = AppFormatters.toZoneTime(
      (now ?? DateTime.now()).toUtc(),
      zone,
    );
    return wall.isAfter(nowWall);
  }

  bool isValid(String zone, {DateTime? now}) =>
      nameValid &&
      markdownValid &&
      dateTimeValid &&
      tagsValid &&
      publishAtValid(zone, now: now);
}
