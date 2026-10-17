import '../../../config/paths.dart';

/// L'adresse de l'éditeur de sortie en création, partant au besoin du modèle
/// [templateSlug] — que `RideEditorPage` lit dans `?template=`, la même
/// adresse que le site (docs/LEDGER_*.md MOB-76, `WEB-63`).
String rideNewLocation(String teamSlug, {String? templateSlug}) =>
    templateSlug == null
    ? Paths.rideNew(teamSlug)
    : '${Paths.rideNew(teamSlug)}'
          '?template=${Uri.encodeQueryComponent(templateSlug)}';
