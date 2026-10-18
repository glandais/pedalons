import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../rides/domain/ride_form.dart' show kRideMarkdownMaxLength;

/// Bornes de `RouteRequest` au contrat. La description (`MediaDto`) a celle de
/// la sortie : [kRideMarkdownMaxLength], le même DTO.
const int kRouteNameMinLength = 3;
const int kRouteNameMaxLength = 200;
const int kRouteMaxTags = 10;

/// Le formulaire d'un parcours : ce que `RouteRequest` porte, hors `points`
/// (le planificateur reste au site, docs/LEDGER_*.md MOB-79). Le tracé, lui,
/// part à part, en fichier GPX.
@immutable
class RouteForm {
  const RouteForm({
    required this.name,
    required this.media,
    required this.surfaceType,
    required this.visibility,
    this.tagIds = const <String>[],
  });

  /// Un parcours vierge : visibilité de l'équipe, surface route, sans tag.
  factory RouteForm.initial(TeamDetailDto team) => RouteForm(
    name: '',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    surfaceType: SurfaceType.road,
    visibility: Visibility.fromJson(team.visibility),
  );

  /// Le parcours tel qu'il est, prêt à être réécrit. Une surface que cette
  /// version de l'app ne connaît pas retombe sur « route », comme au site
  /// (`route.surfaceType || ROAD`).
  factory RouteForm.fromRoute(RouteDetailDto route) {
    final SurfaceType surface = SurfaceType.fromJson(route.surfaceType);
    return RouteForm(
      name: route.name,
      media: route.media,
      surfaceType: surface == SurfaceType.$unknown ? SurfaceType.road : surface,
      visibility: Visibility.fromJson(route.visibility),
      tagIds: <String>[for (final TagDto tag in route.tags) tag.id],
    );
  }

  final String name;
  final MediaDto media;
  final SurfaceType surfaceType;
  final Visibility visibility;
  final List<String> tagIds;

  RouteForm copyWith({
    String? name,
    MediaDto? media,
    SurfaceType? surfaceType,
    Visibility? visibility,
    List<String>? tagIds,
  }) => RouteForm(
    name: name ?? this.name,
    media: media ?? this.media,
    surfaceType: surfaceType ?? this.surfaceType,
    visibility: visibility ?? this.visibility,
    tagIds: tagIds ?? this.tagIds,
  );

  /// La requête. `points` reste nul : pas de routage, le tracé vient du GPX.
  /// [tagIds] part toujours, `[]` compris, qui veut dire « plus aucun » —
  /// nul, il laisserait les tags tels quels en modification.
  RouteRequest toRequest() => RouteRequest(
    name: name.trim(),
    media: media,
    surfaceType: surfaceType.toJson(),
    visibility: visibility.toJson(),
    points: null,
    tagIds: tagIds,
  );

  // --- Validation : les contraintes de `RouteRequest`, lues avant d'envoyer.

  bool get nameValid {
    final int length = name.trim().length;
    return length >= kRouteNameMinLength && length <= kRouteNameMaxLength;
  }

  bool get markdownValid => media.markdown.length <= kRideMarkdownMaxLength;

  bool get tagsValid => tagIds.length <= kRouteMaxTags;

  bool get isValid => nameValid && markdownValid && tagsValid;
}
