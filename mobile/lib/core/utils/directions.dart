import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../api/generated/models/place_detail_dto.dart';
import 'link_launcher.dart';

// L'itinéraire vers un lieu (ledger `MOB-132`, KIT §8 : « lieux de départ et
// d'arrivée : liens qui ouvrent l'itinéraire »).
//
// Un lien **https** de cartes, jamais un schéma d'application (`maps:`,
// `geo:`, `comgooglemaps:`) : rien à déclarer dans `Info.plist` ni dans le
// bloc `<queries>` Android, et le système l'ouvre dans Plans ou Google Maps
// quand ils sont installés, dans le navigateur sinon.
//
// * iOS : Plans — `https://maps.apple.com/?daddr=…` ;
// * ailleurs : Google Maps — `https://www.google.com/maps/dir/?api=1&destination=…`.
//
// La destination est **les coordonnées d'abord**, l'adresse sinon ; le nom
// seul ne suffit pas (« Place de la Mairie » existe dans mille communes).
// Ni l'une ni l'autre : pas d'itinéraire, [directionsUri] rend `null` et la
// ligne de lieu reste un texte simple.
//
// `PlaceDetailDto.link` (un lien libre saisi par l'organisateur) n'est **pas**
// employé ici : l'itinéraire vers le point est ce qu'on attend d'un tap sur
// un lieu de rendez-vous, et un lien libre peut mener n'importe où.

/// L'URL d'itinéraire, ou `null` s'il n'y a ni coordonnées ni adresse.
///
/// [platform] vaut [defaultTargetPlatform] ; il n'est passé que par les tests.
Uri? directionsUri({
  String? address,
  double? latitude,
  double? longitude,
  TargetPlatform? platform,
}) {
  final String? destination = (latitude != null && longitude != null)
      ? '$latitude,$longitude'
      : (address != null && address.trim().isNotEmpty ? address.trim() : null);
  if (destination == null) return null;

  final bool apple = switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
  return apple
      ? Uri.https('maps.apple.com', '/', <String, String>{'daddr': destination})
      : Uri.https('www.google.com', '/maps/dir/', <String, String>{
          'api': '1',
          'destination': destination,
        });
}

/// L'URL d'itinéraire d'un lieu du contrat. `GeoJsonPoint.coordinates` est
/// `[longitude, latitude]`.
Uri? placeDirectionsUri(PlaceDetailDto place, {TargetPlatform? platform}) {
  final List<double>? coordinates = place.geometry?.coordinates;
  final bool hasPoint = coordinates != null && coordinates.length >= 2;
  return directionsUri(
    address: place.address,
    latitude: hasPoint ? coordinates[1] : null,
    longitude: hasPoint ? coordinates[0] : null,
    platform: platform,
  );
}

/// Ouvre l'itinéraire par [openLink] — donc le bandeau « lien impossible à
/// ouvrir » si le système refuse, jamais un échec silencieux. `null` quand il
/// n'y a rien à ouvrir (l'appelant n'aurait pas dû rendre la ligne cliquable).
///
/// [name] n'entre pas dans l'URL ; il est accepté pour que l'appelant passe le
/// lieu entier sans trier.
Future<LinkOutcome?> openDirections(
  BuildContext context, {
  String? name,
  String? address,
  double? latitude,
  double? longitude,
}) async {
  final Uri? uri = directionsUri(
    address: address,
    latitude: latitude,
    longitude: longitude,
  );
  if (uri == null) return null;
  return openLink(context, uri.toString());
}

/// [openDirections] pour un lieu du contrat.
Future<LinkOutcome?> openPlaceDirections(
  BuildContext context,
  PlaceDetailDto place,
) async {
  final Uri? uri = placeDirectionsUri(place);
  if (uri == null) return null;
  return openLink(context, uri.toString());
}
