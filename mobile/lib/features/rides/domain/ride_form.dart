import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';

/// Bornes de `RideRequest` et `GroupRequest` au contrat.
const int kRideNameMinLength = 3;
const int kRideNameMaxLength = 200;
const int kRideMarkdownMaxLength = 100000;
const int kRideGroupNameMaxLength = 200;
const int kRideMaxTags = 10;

/// Le dimanche, 8 h : la sortie que le site propose par défaut
/// (`nextWeekdayWallTime(7, 8, team.timezone)`).
const int kDefaultRideWeekday = DateTime.sunday;
const int kDefaultRideHour = 8;

final DateFormat _wallFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
final DateFormat _wallDateFormat = DateFormat('yyyy-MM-dd');

/// Une heure murale du contrat (`EventDateTime`, « 2026-10-11T08:00:00 »,
/// **sans** offset) depuis les champs d'un `DateTime` — qui doit être une
/// heure murale déjà convertie ([AppFormatters.toZoneTime]), jamais un
/// instant UTC.
String wallTimeOf(DateTime wall) => _wallFormat.format(wall);

/// L'inverse : les champs d'une heure murale du contrat, `null` si illisible.
/// Le résultat est un `DateTime` local **porteur des champs**, à ne comparer
/// à rien (ledger `API-60`) ; il sert aux pickers et aux formateurs.
DateTime? parseWallTime(String? wall) {
  if (wall == null || wall.isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(wall);
  if (parsed == null) return null;
  // Un `Z` ou un offset serait refusé par le serveur ; s'il en arrive un
  // (transition), on garde ses champs tels quels.
  return DateTime(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
}

/// L'instant [iso] du contrat réécrit en heure murale de [zone] — ce que le
/// PUT attend pour `dateTime` et `publishAt` (`instantToWallTime` au site).
String? instantToWallTime(String? iso, String zone) {
  final DateTime? wall = AppFormatters.tryParseZoneTime(iso, zone);
  return wall == null ? null : wallTimeOf(wall);
}

/// Le prochain [weekday] à [hour] h dans [zone], J+7 si c'est aujourd'hui :
/// le site fait pareil (`nextWeekdayWallTime`). [now] est un instant.
String nextWeekdayWallTime(
  int weekday,
  int hour,
  String zone, {
  DateTime? now,
}) {
  final DateTime today = AppFormatters.toZoneTime(
    (now ?? DateTime.now()).toUtc(),
    zone,
  );
  int days = (weekday - today.weekday + 7) % 7;
  if (days == 0) days = 7;
  // Sur les champs, pas sur un instant : un changement d'heure entre les
  // deux jours ne doit pas déplacer 08:00.
  final DateTime day = DateTime(today.year, today.month, today.day + days);
  return '${_wallDateFormat.format(day)}T${hour.toString().padLeft(2, '0')}:00:00';
}

/// Un groupe dans l'éditeur. [id] est nul pour un groupe créé ici ; un
/// groupe qui avait un id le garde, sinon le serveur le supprimerait et en
/// créerait un autre — avec ses inscriptions en moins.
@immutable
class RideGroupForm {
  const RideGroupForm({
    this.id,
    required this.name,
    this.time,
    this.averageSpeed,
    this.maxParticipants,
    this.routeSlug,
    this.leaderId,
  });

  factory RideGroupForm.fromDto(RideGroupDto group) => RideGroupForm(
    id: group.id,
    name: group.name,
    time: group.time,
    averageSpeed: group.averageSpeed,
    maxParticipants: group.maxParticipants,
    routeSlug: group.routeSlug,
    leaderId: group.leader?.id,
  );

  /// Depuis un modèle : un **nouveau** groupe, sans parcours — le modèle
  /// n'en porte pas, et le site les vide aussi (`templateForNewRide`).
  factory RideGroupForm.fromTemplate(RideTemplateGroupDto group) =>
      RideGroupForm(
        name: group.name,
        time: group.time,
        averageSpeed: group.averageSpeed,
        maxParticipants: group.maxParticipants,
      );

  final String? id;
  final String name;

  /// « HH:mm », heure murale du fuseau de la sortie.
  final String? time;

  /// En km/h, l'unité du contrat — l'écran convertit à l'affichage.
  final double? averageSpeed;
  final int? maxParticipants;
  final String? routeSlug;
  final String? leaderId;

  RideGroupForm copyWith({
    String? name,
    String? Function()? time,
    double? Function()? averageSpeed,
    int? Function()? maxParticipants,
    String? Function()? routeSlug,
    String? Function()? leaderId,
  }) => RideGroupForm(
    id: id,
    name: name ?? this.name,
    time: time == null ? this.time : time(),
    averageSpeed: averageSpeed == null ? this.averageSpeed : averageSpeed(),
    maxParticipants: maxParticipants == null
        ? this.maxParticipants
        : maxParticipants(),
    routeSlug: routeSlug == null ? this.routeSlug : routeSlug(),
    leaderId: leaderId == null ? this.leaderId : leaderId(),
  );

  GroupRequest toRequest() => GroupRequest(
    id: id,
    name: name.trim(),
    time: time,
    averageSpeed: averageSpeed,
    maxParticipants: maxParticipants,
    routeSlug: routeSlug,
    leaderId: leaderId,
  );

  bool get hasName => name.trim().isNotEmpty;
}

/// Le formulaire d'une sortie — la projection de `RideRequest` que l'éditeur
/// tient, avec ce que le DTO résout en objets et que la requête veut en
/// références (`leaderId`, `startPlaceId`).
///
/// Les dates sont des **heures murales du fuseau de la sortie**, dans la
/// forme du contrat (`EventDateTime`) ; le fuseau lui-même est tenu par
/// l'écran, qui le résout du lieu de départ, sinon du parcours, sinon de
/// l'équipe (ledger `API-60`).
@immutable
class RideForm {
  const RideForm({
    required this.name,
    required this.media,
    required this.dateTime,
    required this.status,
    required this.visibility,
    required this.groups,
    this.routeSlug,
    this.startPlaceId,
    this.endPlaceId,
    this.publishAt,
    this.tagIds = const <String>[],
    this.templateId,
  });

  /// Le formulaire vide du site (`CreateRidePage`) : dimanche prochain 8 h
  /// dans le fuseau de l'équipe, la visibilité de l'équipe, brouillon, un
  /// groupe « Groupe 1 ».
  factory RideForm.initial(
    TeamDetailDto team, {
    required String firstGroupName,
    DateTime? now,
  }) => RideForm(
    name: '',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    dateTime: nextWeekdayWallTime(
      kDefaultRideWeekday,
      kDefaultRideHour,
      team.timezone,
      now: now,
    ),
    status: Status.draft,
    visibility: Visibility.fromJson(team.visibility),
    groups: <RideGroupForm>[RideGroupForm(name: firstGroupName)],
  );

  /// La sortie telle qu'elle est, prête à être réécrite : chaque groupe avec
  /// son id et son meneur, les deux lieux, les dates en heure murale de
  /// `ride.timezone` — ce que `rideToRequest` fait au site.
  factory RideForm.fromRide(RideDto ride) => RideForm(
    name: ride.name,
    media: ride.media,
    dateTime: instantToWallTime(ride.dateTime, ride.timezone) ?? ride.dateTime,
    status: Status.fromJson(ride.status),
    visibility: Visibility.fromJson(ride.visibility),
    routeSlug: ride.routeSlug,
    startPlaceId: ride.startPlace?.id,
    endPlaceId: ride.endPlace?.id,
    publishAt: instantToWallTime(ride.publishAt, ride.timezone),
    groups: <RideGroupForm>[
      for (final RideGroupDto group in ride.groups)
        RideGroupForm.fromDto(group),
    ],
    tagIds: <String>[for (final TagDto tag in ride.tags) tag.id],
  );

  final String name;
  final MediaDto media;

  /// Heure murale du fuseau de la sortie, forme du contrat.
  final String dateTime;
  final Status status;
  final Visibility visibility;
  final List<RideGroupForm> groups;
  final String? routeSlug;
  final String? startPlaceId;
  final String? endPlaceId;

  /// Heure murale ; seulement lue par le serveur en brouillon.
  final String? publishAt;
  final List<String> tagIds;

  /// Le modèle d'où la sortie part, pour que le serveur avance son numéro.
  final String? templateId;

  RideForm copyWith({
    String? name,
    MediaDto? media,
    String? dateTime,
    Status? status,
    Visibility? visibility,
    List<RideGroupForm>? groups,
    String? Function()? routeSlug,
    String? Function()? startPlaceId,
    String? Function()? endPlaceId,
    String? Function()? publishAt,
    List<String>? tagIds,
    String? Function()? templateId,
  }) => RideForm(
    name: name ?? this.name,
    media: media ?? this.media,
    dateTime: dateTime ?? this.dateTime,
    status: status ?? this.status,
    visibility: visibility ?? this.visibility,
    groups: groups ?? this.groups,
    routeSlug: routeSlug == null ? this.routeSlug : routeSlug(),
    startPlaceId: startPlaceId == null ? this.startPlaceId : startPlaceId(),
    endPlaceId: endPlaceId == null ? this.endPlaceId : endPlaceId(),
    publishAt: publishAt == null ? this.publishAt : publishAt(),
    tagIds: tagIds ?? this.tagIds,
    templateId: templateId == null ? this.templateId : templateId(),
  );

  /// Le formulaire repris d'un modèle, comme « Charger un modèle » au site
  /// (`templateForNewRide`) : le nom numéroté « Nom #n » quand le modèle
  /// compte ses sorties (ledger `API-108`), la description, la visibilité, le
  /// statut, les tags, et des groupes **neufs** sans parcours. La date et les
  /// lieux restent ceux du formulaire.
  RideForm applyTemplate(RideTemplateDto template) => copyWith(
    name: template.nextNumber == null
        ? template.name
        : '${template.name} #${template.nextNumber}',
    media: media.copyWith(markdown: template.markdown),
    status: Status.fromJson(template.status),
    visibility: Visibility.fromJson(template.visibility),
    tagIds: <String>[for (final TagDto tag in template.tags) tag.id],
    groups: <RideGroupForm>[
      for (final RideTemplateGroupDto group in template.groups)
        RideGroupForm.fromTemplate(group),
    ],
    templateId: () => template.id,
  );

  /// La requête, groupes sans nom écartés (le site les filtre aussi) ;
  /// [tagIds] part toujours, `[]` compris, qui veut dire « plus aucun ».
  RideRequest toRequest() => RideRequest(
    name: name.trim(),
    media: media,
    dateTime: dateTime,
    status: status.toJson(),
    visibility: visibility.toJson(),
    routeSlug: routeSlug,
    startPlaceId: startPlaceId,
    endPlaceId: endPlaceId,
    publishAt: status == Status.draft ? publishAt : null,
    groups: <GroupRequest>[
      for (final RideGroupForm group in groups)
        if (group.hasName) group.toRequest(),
    ],
    tagIds: tagIds,
    templateId: templateId,
  );

  // --- Validation : les contraintes de `RideRequest`, lues avant d'envoyer.

  bool get nameValid {
    final int length = name.trim().length;
    return length >= kRideNameMinLength && length <= kRideNameMaxLength;
  }

  bool get markdownValid => media.markdown.length <= kRideMarkdownMaxLength;

  bool get dateTimeValid => parseWallTime(dateTime) != null;

  bool get groupsValid =>
      groups.every(
        (RideGroupForm g) =>
            g.name.trim().length <= kRideGroupNameMaxLength &&
            (g.averageSpeed == null || g.averageSpeed! > 0) &&
            (g.maxParticipants == null || g.maxParticipants! > 0),
      ) &&
      groups.any((RideGroupForm g) => g.hasName);

  bool get tagsValid => tagIds.length <= kRideMaxTags;

  /// En brouillon, une publication programmée doit être à venir — comparée
  /// dans le fuseau de la sortie [zone], pas celui du lecteur.
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
      groupsValid &&
      tagsValid &&
      publishAtValid(zone, now: now);
}
