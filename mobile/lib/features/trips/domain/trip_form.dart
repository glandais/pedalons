import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';
import '../../rides/domain/ride_form.dart';
import '../../rides/domain/ride_permissions.dart';
import '../../visibility/domain/content_visibility.dart';

/// Bornes de `TripRequest` et `StageRequest` au contrat.
const int kTripNameMaxLength = 200;
const int kTripStageNameMaxLength = 200;
const int kTripMarkdownMaxLength = 100000;
const int kTripMaxTags = 10;

/// Le samedi, 8 h : le voyage que le site propose par défaut
/// (`nextWeekdayWallTime(6, 8, team.timezone)`).
const int kDefaultTripWeekday = DateTime.saturday;
const int kDefaultTripHour = 8;

const MediaDto _emptyMedia = MediaDto(
  markdown: '',
  assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
);

/// Qui peut créer un voyage : la règle de `TripAccessChecker` — organisateur
/// ou administrateur, modules voyages **et** parcours actifs (un voyage se
/// crée sur des parcours). La modification, elle, lit `permissions.canEdit`
/// du voyage (docs/LEDGER_*.md MOB-137, MOB-162).
bool canManageTeamTrips(
  TeamDetailDto team, {
  required TeamRole? teamRole,
  bool platformAdmin = false,
}) {
  return team.enableTrips &&
      team.enableRoutes &&
      canManageRides(teamRole: teamRole, platformAdmin: platformAdmin);
}

/// [wall] décalée de [days] jours, **sur les champs** : ni un changement
/// d'heure ni le fuseau du téléphone ne déplacent l'heure (`addDaysToWallTime`
/// au site, ledgers `API-60`, `WEB-71`). `null` si [wall] est illisible.
String? addDaysToWallTime(String wall, int days) {
  final DateTime? parsed = parseWallTime(wall);
  if (parsed == null) return null;
  return wallTimeOf(
    DateTime(
      parsed.year,
      parsed.month,
      parsed.day + days,
      parsed.hour,
      parsed.minute,
      parsed.second,
    ),
  );
}

/// Une étape dans l'éditeur. [id] est nul pour une étape créée ici ; une
/// étape qui avait un id le garde, sinon le serveur la supprimerait et en
/// créerait une autre — avec ses commentaires en moins.
@immutable
class TripStageForm {
  const TripStageForm({
    this.id,
    required this.name,
    required this.dateTime,
    this.media = _emptyMedia,
    this.averageSpeed,
    this.routeSlug,
    this.startPlaceId,
    this.endPlaceId,
  });

  /// L'étape telle qu'elle est : le `TripStageDto` porte des objets résolus
  /// (`route`, `startPlace`, `endPlace`) là où la requête veut des références,
  /// et sa date se réécrit en heure murale de **son** fuseau — un voyage peut
  /// en traverser plusieurs (`tripToRequest` au site).
  factory TripStageForm.fromDto(TripStageDto stage) => TripStageForm(
    id: stage.id,
    name: stage.name,
    dateTime:
        instantToWallTime(stage.dateTime, stage.timezone) ?? stage.dateTime,
    media: stage.media,
    averageSpeed: stage.averageSpeed,
    routeSlug: stage.route?.slug,
    startPlaceId: stage.startPlace?.id,
    endPlaceId: stage.endPlace?.id,
  );

  final String? id;
  final String name;

  /// Heure murale du fuseau de l'étape, forme du contrat.
  final String dateTime;
  final MediaDto media;

  /// En km/h, l'unité du contrat — l'écran convertit à l'affichage.
  final double? averageSpeed;
  final String? routeSlug;
  final String? startPlaceId;
  final String? endPlaceId;

  TripStageForm copyWith({
    String? name,
    String? dateTime,
    MediaDto? media,
    double? Function()? averageSpeed,
    String? Function()? routeSlug,
    String? Function()? startPlaceId,
    String? Function()? endPlaceId,
  }) => TripStageForm(
    id: id,
    name: name ?? this.name,
    dateTime: dateTime ?? this.dateTime,
    media: media ?? this.media,
    averageSpeed: averageSpeed == null ? this.averageSpeed : averageSpeed(),
    routeSlug: routeSlug == null ? this.routeSlug : routeSlug(),
    startPlaceId: startPlaceId == null ? this.startPlaceId : startPlaceId(),
    endPlaceId: endPlaceId == null ? this.endPlaceId : endPlaceId(),
  );

  StageRequest toRequest() => StageRequest(
    id: id,
    name: name.trim(),
    dateTime: dateTime,
    media: media,
    averageSpeed: averageSpeed,
    routeSlug: routeSlug,
    startPlaceId: startPlaceId,
    endPlaceId: endPlaceId,
  );

  bool get nameValid {
    final int length = name.trim().length;
    return length >= 1 && length <= kTripStageNameMaxLength;
  }

  bool get valid =>
      nameValid &&
      parseWallTime(dateTime) != null &&
      media.markdown.length <= kTripMarkdownMaxLength &&
      (averageSpeed == null || averageSpeed! > 0);
}

/// Le formulaire d'un voyage — la projection de `TripRequest` que l'éditeur
/// tient (docs/LEDGER_*.md MOB-162).
///
/// Les dates sont des **heures murales**, dans la forme du contrat : celle du
/// voyage dans son fuseau (première étape, sinon parcours, sinon équipe),
/// celle de chaque étape dans le sien (ledger `API-60`).
@immutable
class TripForm {
  const TripForm({
    required this.name,
    required this.media,
    required this.dateTime,
    required this.status,
    required this.visibility,
    required this.stages,
    this.routeSlug,
    this.publishAt,
    this.tagIds = const <String>[],
  });

  /// Le formulaire vide du site (`CreateTripPage`) : samedi prochain 8 h dans
  /// le fuseau de l'équipe, la visibilité de départ que donne le backend,
  /// brouillon, une étape « Étape 1 » à la même heure.
  factory TripForm.initial(
    TeamDetailDto team, {
    required String firstStageName,
    DateTime? now,
  }) {
    final String start = nextWeekdayWallTime(
      kDefaultTripWeekday,
      kDefaultTripHour,
      team.timezone,
      now: now,
    );
    return TripForm(
      name: '',
      media: _emptyMedia,
      dateTime: start,
      status: Status.draft,
      visibility: defaultContentVisibilityOf(team),
      stages: <TripStageForm>[
        TripStageForm(name: firstStageName, dateTime: start),
      ],
    );
  }

  /// Le voyage tel qu'il est, prêt à être réécrit — ce que `tripToRequest`
  /// fait au site. Les étapes dans l'ordre d'affichage.
  factory TripForm.fromTrip(TripDto trip) {
    final List<TripStageDto> ordered = List<TripStageDto>.of(trip.stages)
      ..sort((TripStageDto a, TripStageDto b) {
        final int byIndex = a.stageIndex.compareTo(b.stageIndex);
        return byIndex != 0 ? byIndex : a.sortOrder.compareTo(b.sortOrder);
      });
    return TripForm(
      name: trip.name,
      media: trip.media,
      dateTime:
          instantToWallTime(trip.dateTime, trip.timezone) ?? trip.dateTime,
      status: Status.fromJson(trip.status),
      visibility: Visibility.fromJson(trip.visibility),
      routeSlug: trip.routeSlug,
      publishAt: instantToWallTime(trip.publishAt, trip.timezone),
      stages: <TripStageForm>[
        for (final TripStageDto stage in ordered) TripStageForm.fromDto(stage),
      ],
      tagIds: <String>[for (final TagDto tag in trip.tags) tag.id],
    );
  }

  final String name;
  final MediaDto media;

  /// Heure murale du fuseau du voyage, forme du contrat.
  final String dateTime;
  final Status status;
  final Visibility visibility;
  final List<TripStageForm> stages;
  final String? routeSlug;

  /// Heure murale ; seulement lue par le serveur en brouillon.
  final String? publishAt;
  final List<String> tagIds;

  TripForm copyWith({
    String? name,
    MediaDto? media,
    String? dateTime,
    Status? status,
    Visibility? visibility,
    List<TripStageForm>? stages,
    String? Function()? routeSlug,
    String? Function()? publishAt,
    List<String>? tagIds,
  }) => TripForm(
    name: name ?? this.name,
    media: media ?? this.media,
    dateTime: dateTime ?? this.dateTime,
    status: status ?? this.status,
    visibility: visibility ?? this.visibility,
    stages: stages ?? this.stages,
    routeSlug: routeSlug == null ? this.routeSlug : routeSlug(),
    publishAt: publishAt == null ? this.publishAt : publishAt(),
    tagIds: tagIds ?? this.tagIds,
  );

  /// La date d'une étape ajoutée : J+1 à la même heure murale que la
  /// dernière ; la première part avec le voyage (`handleAddStage` au site).
  String nextStageDateTime() {
    final String? previous = stages.lastOrNull?.dateTime;
    return previous == null
        ? dateTime
        : addDaysToWallTime(previous, 1) ?? dateTime;
  }

  /// La requête ; [tagIds] part toujours, `[]` compris, qui veut dire « plus
  /// aucun ». Le serveur applique **tous** les champs du PUT : chaque étape y
  /// va avec son id, son parcours et ses lieux, sinon ils sont effacés.
  TripRequest toRequest() => TripRequest(
    name: name.trim(),
    media: media,
    dateTime: dateTime,
    status: status.toJson(),
    visibility: visibility.toJson(),
    routeSlug: routeSlug,
    publishAt: status == Status.draft ? publishAt : null,
    stages: <StageRequest>[
      for (final TripStageForm stage in stages) stage.toRequest(),
    ],
    tagIds: tagIds,
  );

  // --- Validation : les contraintes de `TripRequest`, lues avant d'envoyer.

  bool get nameValid {
    final int length = name.trim().length;
    return length >= 1 && length <= kTripNameMaxLength;
  }

  bool get markdownValid => media.markdown.length <= kTripMarkdownMaxLength;

  bool get dateTimeValid => parseWallTime(dateTime) != null;

  bool get stagesValid => stages.every((TripStageForm s) => s.valid);

  bool get tagsValid => tagIds.length <= kTripMaxTags;

  /// En brouillon, une publication programmée doit être à venir — comparée
  /// dans le fuseau du voyage [zone], pas celui du lecteur.
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
      stagesValid &&
      tagsValid &&
      publishAtValid(zone, now: now);
}
