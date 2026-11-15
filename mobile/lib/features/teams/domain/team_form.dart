import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../rides/domain/ride_form.dart' show kRideMarkdownMaxLength;

/// Borne de `TeamRequest.name` au contrat. La présentation (`MediaDto`) a
/// celle de tous les textes : [kRideMarkdownMaxLength], le même DTO.
const int kTeamNameMaxLength = 200;

/// Le fuseau qu'une équipe reçoit du serveur quand la création n'en donne
/// pas (ledger `API-60`) — et celui que l'écran propose faute de mieux.
const String kTeamDefaultTimezone = 'Europe/Paris';

const MediaDto _emptyMedia = MediaDto(
  markdown: '',
  assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
);

/// Le formulaire d'une équipe : ce que `TeamRequest` porte — création
/// (docs/LEDGER_*.md MOB-165) et paramètres (ledger `MOB-166`).
///
/// **Le PUT réécrit tous les champs** : [TeamForm.fromTeam] reprend donc la
/// présentation **entière** (texte, logo, images, pièces jointes), la
/// position, le fuseau, la visibilité et tous les interrupteurs, et
/// [toRequest] construit un `TeamRequest` propre.
@immutable
class TeamForm {
  const TeamForm({
    required this.name,
    required this.media,
    required this.visibility,
    required this.timezone,
    required this.enableRoutes,
    required this.enableRides,
    required this.enableTrips,
    required this.enablePosts,
    required this.enableAds,
    required this.enableMemberDirectory,
    required this.postsAsTeamByDefault,
    this.location,
  });

  /// Le formulaire vide du site (`CreateTeamPage`) : tous les modules actifs,
  /// sauf le trombinoscope — l'ouvrir à tous les membres est une décision, pas
  /// un défaut ; publications au nom de l'équipe ; visibilité `TEAM`, qui ne
  /// se choisit pas à la création. [timezone] est celui de la personne qui
  /// crée l'équipe.
  factory TeamForm.initial({required String timezone}) => TeamForm(
    name: '',
    media: _emptyMedia,
    visibility: Visibility.team,
    timezone: timezone,
    enableRoutes: true,
    enableRides: true,
    enableTrips: true,
    enablePosts: true,
    enableAds: true,
    enableMemberDirectory: false,
    postsAsTeamByDefault: true,
  );

  /// L'équipe telle qu'elle est, prête à être réécrite.
  factory TeamForm.fromTeam(TeamDetailDto team) => TeamForm(
    name: team.name,
    media: team.about,
    visibility: Visibility.fromJson(team.visibility),
    timezone: team.timezone,
    enableRoutes: team.enableRoutes,
    enableRides: team.enableRides,
    enableTrips: team.enableTrips,
    enablePosts: team.enablePosts,
    enableAds: team.enableAds,
    enableMemberDirectory: team.enableMemberDirectory,
    postsAsTeamByDefault: team.postsAsTeamByDefault,
    location: team.geometry?.coordinates,
  );

  final String name;

  /// La présentation : texte, logo, images et pièces jointes.
  final MediaDto media;
  final Visibility visibility;

  /// Nom IANA (« Europe/Paris »).
  final String timezone;

  final bool enableRoutes;

  /// Sans parcours, ni sorties ni voyages : voir [withRoutes].
  final bool enableRides;
  final bool enableTrips;
  final bool enablePosts;
  final bool enableAds;
  final bool enableMemberDirectory;

  /// Où démarre la case « au nom de l'équipe » d'une nouvelle publication
  /// (ledger `API-6`). Sans effet tant que les publications sont coupées ;
  /// la valeur est gardée, comme au site.
  final bool postsAsTeamByDefault;

  /// La position de l'équipe, dans l'ordre GeoJSON **`[longitude, latitude]`**,
  /// ou `null`.
  final List<double>? location;

  TeamForm copyWith({
    String? name,
    MediaDto? media,
    Visibility? visibility,
    String? timezone,
    bool? enableRides,
    bool? enableTrips,
    bool? enablePosts,
    bool? enableAds,
    bool? enableMemberDirectory,
    bool? postsAsTeamByDefault,
    List<double>? Function()? location,
  }) => TeamForm(
    name: name ?? this.name,
    media: media ?? this.media,
    visibility: visibility ?? this.visibility,
    timezone: timezone ?? this.timezone,
    enableRoutes: enableRoutes,
    // Une sortie et un voyage se créent sur un parcours.
    enableRides: enableRoutes && (enableRides ?? this.enableRides),
    enableTrips: enableRoutes && (enableTrips ?? this.enableTrips),
    enablePosts: enablePosts ?? this.enablePosts,
    enableAds: enableAds ?? this.enableAds,
    enableMemberDirectory: enableMemberDirectory ?? this.enableMemberDirectory,
    postsAsTeamByDefault: postsAsTeamByDefault ?? this.postsAsTeamByDefault,
    location: location == null ? this.location : location(),
  );

  /// Active ou coupe les parcours. Les couper coupe aussi les sorties et les
  /// voyages, comme au site ; les rétablir ne les rallume pas : c'est un
  /// choix à refaire.
  TeamForm withRoutes(bool enabled) => TeamForm(
    name: name,
    media: media,
    visibility: visibility,
    timezone: timezone,
    enableRoutes: enabled,
    enableRides: enabled && enableRides,
    enableTrips: enabled && enableTrips,
    enablePosts: enablePosts,
    enableAds: enableAds,
    enableMemberDirectory: enableMemberDirectory,
    postsAsTeamByDefault: postsAsTeamByDefault,
    location: location,
  );

  /// La requête, création comme modification.
  TeamRequest toRequest() {
    final List<double>? point = location;
    return TeamRequest(
      name: name.trim(),
      media: media,
      visibility: visibility.toJson(),
      enableTrips: enableTrips,
      enableAds: enableAds,
      enablePosts: enablePosts,
      enableRides: enableRides,
      enableRoutes: enableRoutes,
      enableMemberDirectory: enableMemberDirectory,
      postsAsTeamByDefault: postsAsTeamByDefault,
      geometry: point == null
          ? null
          : TeamRequestGeometry(
              type: TeamRequestGeometryTypeType.point,
              coordinates: point,
            ),
      timezone: timezone,
    );
  }

  // --- Validation : les contraintes de `TeamRequest`, lues avant d'envoyer.

  /// 1 à [kTeamNameMaxLength] caractères, dont au moins un non blanc.
  bool get nameValid {
    final int length = name.trim().length;
    return length >= 1 && length <= kTeamNameMaxLength;
  }

  bool get markdownValid => media.markdown.length <= kRideMarkdownMaxLength;

  bool get timezoneValid => timezone.trim().isNotEmpty;

  bool get isValid => nameValid && markdownValid && timezoneValid;
}
