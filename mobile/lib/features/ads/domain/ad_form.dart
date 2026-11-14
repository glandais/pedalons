import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../api/generated/export.dart';
import '../../rides/domain/ride_form.dart' show kRideMarkdownMaxLength;

/// Bornes de `AdRequest` au contrat. La description (`MediaDto`) a celle de
/// la sortie : [kRideMarkdownMaxLength], le même DTO.
const int kAdNameMaxLength = 200;
const int kAdLocationDescriptionMaxLength = 200;
const int kAdMaxTags = 10;

/// Qui peut publier une annonce : **tout membre** de l'équipe — pas seulement
/// qui organise —, et l'admin de plateforme, module annonces actif (la règle
/// de `AdAccessChecker`, docs/LEDGER_*.md MOB-158). Un rôle que cette version
/// de l'app ne connaît pas n'ouvre rien, comme partout ailleurs. Modifier et
/// supprimer suivent, eux, le `permissions` de l'annonce : son auteur ou
/// l'administration de l'équipe.
bool canCreateTeamAds(
  TeamDetailDto team, {
  required TeamRole? teamRole,
  bool platformAdmin = false,
}) {
  return team.enableAds &&
      (platformAdmin || (teamRole != null && teamRole != TeamRole.$unknown));
}

/// Un prix saisi, lu avec la virgule comme le point. `valid` est faux pour un
/// texte qui n'est pas un nombre positif ; un champ vide est valide et vaut
/// `null` — « prix à négocier ».
({bool valid, num? value}) parseAdPrice(String text) {
  final String trimmed = text.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return (valid: true, value: null);
  final double? parsed = double.tryParse(trimmed);
  if (parsed == null || parsed < 0 || !parsed.isFinite) {
    return (valid: false, value: null);
  }
  // Au centime, comme le champ du site (`decimalScale={2}`).
  final double rounded = (parsed * 100).roundToDouble() / 100;
  return (
    valid: true,
    value: rounded == rounded.roundToDouble() ? rounded.toInt() : rounded,
  );
}

/// Le prix d'une annonce tel que le champ le montre : sans décimales
/// inutiles, avec le séparateur de la langue.
String adPriceText(num? price) =>
    price == null ? '' : NumberFormat('0.##').format(price);

/// Le formulaire d'une annonce : ce que `AdRequest` porte. Une annonce n'a
/// pas de visibilité à choisir : elle est réservée aux membres.
///
/// [location] est la position **telle que le serveur l'a donnée** tant que
/// l'écran n'en choisit pas une autre : pour qui modifie l'annonce d'une
/// autre personne, c'est le point flouté, et le renvoyer inchangé garde le
/// point exact enregistré (`AdEditDto.locationGeometry`).
@immutable
class AdForm {
  const AdForm({
    required this.name,
    required this.media,
    required this.status,
    required this.adType,
    this.price,
    this.rentalPeriod,
    this.locationDescription = '',
    this.location,
    this.tagIds = const <String>[],
  });

  /// Le formulaire vide du site (`CreateAdPage`) : une vente, en brouillon.
  factory AdForm.initial() => const AdForm(
    name: '',
    media: MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    status: Status.draft,
    adType: AdType.sale,
  );

  /// L'annonce telle que `GET …/edit` la donne, prête à être réécrite.
  factory AdForm.fromEdit(AdEditDto ad) {
    final String? period = ad.rentalPeriod;
    final AdEditDtoLocationGeometry? point = ad.locationGeometry;
    return AdForm(
      name: ad.name,
      media: ad.media,
      status: Status.fromJson(ad.status),
      adType: AdType.fromJson(ad.adType),
      price: ad.price,
      rentalPeriod: period == null ? null : RentalPeriod.fromJson(period),
      locationDescription: ad.locationDescription ?? '',
      location: point == null ? null : adLocationOf(point.coordinates),
      tagIds: <String>[for (final TagDto tag in ad.tags) tag.id],
    );
  }

  final String name;
  final MediaDto media;
  final Status status;
  final AdType adType;

  /// `null` : prix à négocier.
  final num? price;

  /// Lue seulement pour une location, où elle est requise.
  final RentalPeriod? rentalPeriod;
  final String locationDescription;

  /// GeoJSON : `[longitude, latitude]`.
  final AdRequestLocationGeometry? location;
  final List<String> tagIds;

  AdForm copyWith({
    String? name,
    MediaDto? media,
    Status? status,
    AdType? adType,
    num? Function()? price,
    RentalPeriod? Function()? rentalPeriod,
    String? locationDescription,
    AdRequestLocationGeometry? Function()? location,
    List<String>? tagIds,
  }) => AdForm(
    name: name ?? this.name,
    media: media ?? this.media,
    status: status ?? this.status,
    adType: adType ?? this.adType,
    price: price == null ? this.price : price(),
    rentalPeriod: rentalPeriod == null ? this.rentalPeriod : rentalPeriod(),
    locationDescription: locationDescription ?? this.locationDescription,
    location: location == null ? this.location : location(),
    tagIds: tagIds ?? this.tagIds,
  );

  /// La requête. La période ne part que pour une location ; un lieu vide part
  /// nul ; [tagIds] part toujours, `[]` compris, qui veut dire « plus aucun ».
  AdRequest toRequest() {
    final String place = locationDescription.trim();
    return AdRequest(
      name: name.trim(),
      media: media,
      status: status.toJson(),
      adType: adType.toJson(),
      price: price,
      rentalPeriod: adType == AdType.rental ? rentalPeriod?.toJson() : null,
      locationDescription: place.isEmpty ? null : place,
      locationGeometry: location,
      tagIds: tagIds,
    );
  }

  // --- Validation : les contraintes de `AdRequest`, lues avant d'envoyer.

  bool get nameValid {
    final int length = name.trim().length;
    return length >= 1 && length <= kAdNameMaxLength;
  }

  bool get markdownValid => media.markdown.length <= kRideMarkdownMaxLength;

  /// Une location dit sa période (jour, semaine, mois).
  bool get rentalPeriodValid =>
      adType != AdType.rental ||
      (rentalPeriod != null && rentalPeriod != RentalPeriod.$unknown);

  bool get priceValid => price == null || price! >= 0;

  bool get locationDescriptionValid =>
      locationDescription.trim().length <= kAdLocationDescriptionMaxLength;

  bool get tagsValid => tagIds.length <= kAdMaxTags;

  bool get isValid =>
      nameValid &&
      markdownValid &&
      rentalPeriodValid &&
      priceValid &&
      locationDescriptionValid &&
      tagsValid;
}

/// Le point GeoJSON d'une annonce depuis `[longitude, latitude]`.
AdRequestLocationGeometry adLocationOf(List<double> coordinates) =>
    AdRequestLocationGeometry(
      type: AdRequestLocationGeometryTypeType.point,
      coordinates: coordinates,
    );
