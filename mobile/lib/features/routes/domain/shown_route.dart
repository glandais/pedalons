import '../../../api/generated/export.dart';
import '../../../core/pdl/elevation/elevation_samples.dart';
import 'route_elevation_builder.dart';

/// Un tracé tel que la carte et le profil le lisent, quelle que soit son
/// origine : un parcours d'équipe ([RouteDetailDto.shown]) ou un aperçu des
/// outils GPX ([GpxPreviewDto.shown], ledger `MOB-178`).
///
/// Seulement ce que `RouteMap`, `RouteSection` et les providers du profil
/// lisent ; ce qui n'appartient qu'à une origine (l'équipe, les pièces jointes,
/// le propriétaire d'un aperçu) reste sur son DTO.
///
/// **Toujours obtenu par `.shown`, jamais construit à la main hors de ce
/// fichier** : la valeur est mémorisée par DTO, et les mémoires des couleurs du
/// vent (`weather_map_layer.dart`) comparent le tracé par identité. Un
/// `ShownRoute` neuf à chaque `build` les viderait à chaque image.
class ShownRoute {
  const ShownRoute._({
    required this.id,
    required this.name,
    required this.distance,
    required this.elevationState,
    required this.tracks,
    required this.waypoints,
    this.start,
    this.end,
  });

  final String id;
  final String name;

  /// En mètres.
  final double distance;

  /// `PENDING`, `HD` ou `FAST` (`ElevationState` du contrat).
  final String elevationState;
  final List<TrackDto> tracks;
  final List<WaypointDto> waypoints;

  /// Départ et arrivée servis par le contrat ; absents d'un aperçu, la carte
  /// prend alors les extrémités du tracé.
  final GeoJsonPoint? start;
  final GeoJsonPoint? end;

  /// Les LineStrings, une par trace, dans l'ordre du serveur — celui des
  /// montées et du `PolylineIndex` du curseur.
  List<List<List<double>>> get lines => <List<List<double>>>[
    for (final TrackDto t in tracks) t.line.coordinates,
  ];

  bool get hasGeometry =>
      tracks.any((TrackDto t) => t.line.coordinates.isNotEmpty);

  ElevationSamples? elevationSamples({int targetBars = kElevationBarTarget}) =>
      elevationSamplesFromLines(lines, targetBars: targetBars);
}

final Expando<ShownRoute> _fromRoute = Expando<ShownRoute>('shownRoute');
final Expando<ShownRoute> _fromPreview = Expando<ShownRoute>('shownPreview');

extension RouteDetailShown on RouteDetailDto {
  /// Le tracé de ce parcours, le même objet pour le même DTO.
  ShownRoute get shown => _fromRoute[this] ??= ShownRoute._(
    id: id,
    name: name,
    distance: distance,
    elevationState: elevationState,
    tracks: tracks,
    waypoints: waypoints,
    start: start,
    end: end,
  );
}

extension GpxPreviewShown on GpxPreviewDto {
  /// Le tracé de cet aperçu, le même objet pour le même DTO.
  ShownRoute get shown => _fromPreview[this] ??= ShownRoute._(
    id: id,
    name: name,
    distance: distance,
    elevationState: elevationState,
    tracks: tracks,
    waypoints: waypoints,
  );
}
