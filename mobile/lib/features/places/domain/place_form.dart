import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// Bornes de `PlaceRequest` au contrat : le nom de 1 à 200 caractères, dont
/// un non blanc ; l'adresse et le lien, s'ils sont donnés, de 3 à 200.
const int kPlaceTextMaxLength = 200;
const int kPlaceOptionalMinLength = 3;

/// Le formulaire d'un lieu de l'équipe : ce que `PlaceRequest` porte
/// (docs/LEDGER_*.md MOB-168).
///
/// **Le PUT réécrit tous les champs** : `PlaceService.updatePlaceFromRequest`
/// pose le nom, l'adresse, le lien, les deux usages et la position sans
/// condition — une adresse, un lien ou une position absents (ou nuls) sont
/// **effacés**. [PlaceForm.fromPlace] reprend donc le lieu entier, position
/// comprise, et [toRequest] construit une requête complète.
@immutable
class PlaceForm {
  const PlaceForm({
    required this.name,
    required this.address,
    required this.link,
    required this.startPlace,
    required this.endPlace,
    this.location,
  });

  /// Le formulaire vide du site (`PlaceList.newPlace`) : un lieu sert au
  /// départ comme à l'arrivée tant qu'on ne dit pas le contraire.
  factory PlaceForm.initial() => const PlaceForm(
    name: '',
    address: '',
    link: '',
    startPlace: true,
    endPlace: true,
  );

  /// Le lieu tel qu'il est, prêt à être réécrit.
  factory PlaceForm.fromPlace(PlaceDetailDto place) => PlaceForm(
    name: place.name,
    address: place.address ?? '',
    link: place.link ?? '',
    startPlace: place.startPlace,
    endPlace: place.endPlace,
    location: place.geometry?.coordinates,
  );

  final String name;

  /// Vide : aucune adresse.
  final String address;

  /// Vide : aucun lien.
  final String link;

  final bool startPlace;
  final bool endPlace;

  /// La position, dans l'ordre GeoJSON **`[longitude, latitude]`** ; `null`
  /// si le lieu n'en a pas.
  final List<double>? location;

  /// [location] prend une fonction : `() => null` efface la position, là où
  /// un `null` nu voudrait dire « inchangée ».
  PlaceForm copyWith({
    String? name,
    String? address,
    String? link,
    bool? startPlace,
    bool? endPlace,
    List<double>? Function()? location,
  }) => PlaceForm(
    name: name ?? this.name,
    address: address ?? this.address,
    link: link ?? this.link,
    startPlace: startPlace ?? this.startPlace,
    endPlace: endPlace ?? this.endPlace,
    location: location == null ? this.location : location(),
  );

  /// La requête, création comme modification. Une adresse ou un lien laissés
  /// vides partent **absents** (`null`), comme au site (`blankToUndefined`) :
  /// le contrat les borne à 3 caractères dès qu'ils sont présents.
  PlaceRequest toRequest() {
    final List<double>? point = location;
    return PlaceRequest(
      name: name.trim(),
      address: _blankToNull(address),
      link: _blankToNull(link),
      startPlace: startPlace,
      endPlace: endPlace,
      geometry: point == null
          ? null
          : PlaceRequestGeometry(
              type: PlaceRequestGeometryTypeType.point,
              coordinates: point,
            ),
    );
  }

  // --- Validation : les contraintes de `PlaceRequest`, lues avant d'envoyer.

  /// 1 à [kPlaceTextMaxLength] caractères, dont au moins un non blanc.
  bool get nameValid {
    final int length = name.trim().length;
    return length >= 1 && length <= kPlaceTextMaxLength;
  }

  /// Vide, ou de [kPlaceOptionalMinLength] à [kPlaceTextMaxLength] caractères.
  bool get addressValid => _optionalValid(address);

  /// Vide, ou de [kPlaceOptionalMinLength] à [kPlaceTextMaxLength] caractères.
  /// Que ce soit une adresse web, c'est le serveur qui le dit (`@URL`).
  bool get linkValid => _optionalValid(link);

  bool get isValid => nameValid && addressValid && linkValid;

  static String? _blankToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _optionalValid(String value) {
    final int length = value.trim().length;
    return length == 0 ||
        (length >= kPlaceOptionalMinLength && length <= kPlaceTextMaxLength);
  }
}
