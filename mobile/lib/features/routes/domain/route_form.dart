import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../rides/domain/ride_form.dart' show kRideMarkdownMaxLength;
import '../../visibility/domain/content_visibility.dart';
import 'planner_result.dart';

/// Bornes de `RouteRequest` au contrat. La description (`MediaDto`) a celle de
/// la sortie : [kRideMarkdownMaxLength], le même DTO.
const int kRouteNameMinLength = 3;
const int kRouteNameMaxLength = 200;
const int kRouteMaxTags = 10;

/// Le formulaire d'un parcours : ce que `RouteRequest` porte, hors tracé
/// (docs/LEDGER_*.md MOB-79). Le tracé part à part : en fichier GPX, ou dans
/// le fragment que rend le planificateur embarqué ([PlannerResult], ledger
/// `MOB-170`), que [toRequest] fusionne.
@immutable
class RouteForm {
  const RouteForm({
    required this.name,
    required this.media,
    required this.surfaceType,
    required this.visibility,
    this.tagIds = const <String>[],
    this.excludedFromGenerator,
  });

  /// Un parcours vierge : la visibilité de départ que donne le backend
  /// (`defaultContentVisibility`, docs/LEDGER_*.md MOB-137), surface route,
  /// sans tag. « Ne pas utiliser pour générer des parcours » n'existe que là
  /// où le planificateur est ouvert (comme au site) : ailleurs il reste nul,
  /// et n'est pas envoyé.
  factory RouteForm.initial(TeamDetailDto team) => RouteForm(
    excludedFromGenerator: team.enableRoutePlanner ? false : null,
    name: '',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    surfaceType: SurfaceType.road,
    visibility: defaultContentVisibilityOf(team),
  );

  /// Le parcours tel qu'il est, prêt à être réécrit. Une surface que cette
  /// version de l'app ne connaît pas retombe sur « route », comme au site
  /// (`route.surfaceType || ROAD`). [planner] : le planificateur est ouvert à
  /// l'équipe (`TeamDetailDto.enableRoutePlanner`) — la case d'exclusion du
  /// générateur part alors de la valeur du parcours ; sinon elle reste nulle,
  /// et le serveur garde la sienne.
  factory RouteForm.fromRoute(RouteDetailDto route, {bool planner = false}) {
    final SurfaceType surface = SurfaceType.fromJson(route.surfaceType);
    return RouteForm(
      name: route.name,
      media: route.media,
      surfaceType: surface == SurfaceType.$unknown ? SurfaceType.road : surface,
      visibility: Visibility.fromJson(route.visibility),
      tagIds: <String>[for (final TagDto tag in route.tags) tag.id],
      excludedFromGenerator: planner
          ? (route.excludedFromGenerator ?? false)
          : null,
    );
  }

  final String name;
  final MediaDto media;
  final SurfaceType surfaceType;
  final Visibility visibility;
  final List<String> tagIds;

  /// « Ne pas utiliser pour générer des parcours ». Nul : la case n'est pas
  /// proposée (planificateur fermé à l'équipe), rien n'est envoyé.
  final bool? excludedFromGenerator;

  RouteForm copyWith({
    String? name,
    MediaDto? media,
    SurfaceType? surfaceType,
    Visibility? visibility,
    List<String>? tagIds,
    bool? excludedFromGenerator,
  }) => RouteForm(
    name: name ?? this.name,
    media: media ?? this.media,
    surfaceType: surfaceType ?? this.surfaceType,
    visibility: visibility ?? this.visibility,
    tagIds: tagIds ?? this.tagIds,
    excludedFromGenerator: excludedFromGenerator ?? this.excludedFromGenerator,
  );

  /// La requête. [tagIds] part toujours, `[]` compris, qui veut dire « plus
  /// aucun » — nul, il laisserait les tags tels quels en modification.
  ///
  /// Sans [planner] (tracé par fichier GPX, ou laissé tel quel), ni `points`
  /// ni `plannerState` ni `waypoints` : la requête de `MOB-79`. Avec, le
  /// fragment du planificateur est recopié **tel que la page l'a décidé** :
  /// `plannerState` ou `points`, jamais les deux (l'état gagne), `waypoints`
  /// seulement s'il est là. Un résultat `file` ou vide n'ajoute rien ici : le
  /// fichier part à part, et « rien » laisse le tracé au serveur.
  RouteRequest toRequest({PlannerResult? planner}) => RouteRequest(
    name: name.trim(),
    media: media,
    surfaceType: surfaceType.toJson(),
    visibility: visibility.toJson(),
    points: planner?.plannerState == null ? planner?.points : null,
    tagIds: tagIds,
    plannerState: planner?.plannerState,
    waypoints: planner?.waypoints,
    excludedFromGenerator: excludedFromGenerator,
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
