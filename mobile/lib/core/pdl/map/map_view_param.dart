import 'pdl_map_camera.dart';

/// La caméra d'une carte d'exploration dans son adresse : `?map=<zoom>/<lat>/<lon>`,
/// la forme du `#map=` d'OpenStreetMap. Le site l'écrit à chaque déplacement
/// (`frontend/src/lib/mapViewParam.ts`) ; l'app la lit à l'ouverture d'un lien,
/// pour s'ouvrir là où la carte partagée était. Changer le format des deux
/// côtés, ou les liens du site cessent de s'ouvrir au bon endroit.
const String kMapViewParam = 'map';

const double _kMaxZoom = 22;

/// La caméra de `?map=` parmi [query], ou `null` quand elle manque ou est
/// malformée — la carte se cadre alors comme avant.
PdlMapCamera? mapViewFromQuery(Map<String, String> query) =>
    parseMapView(query[kMapViewParam]);

/// `zoom/lat/lon`, ou `null`.
PdlMapCamera? parseMapView(String? value) {
  if (value == null || value.isEmpty) return null;
  final List<String> parts = value.split('/');
  if (parts.length != 3) return null;
  final List<double?> numbers = parts.map(double.tryParse).toList();
  if (numbers.any((double? n) => n == null || !n.isFinite)) return null;
  final double zoom = numbers[0]!;
  final double lat = numbers[1]!;
  final double lon = numbers[2]!;
  if (zoom < 0 || zoom > _kMaxZoom) return null;
  if (lat.abs() > kWebMercatorMaxLat || lon.abs() > 180) return null;
  return PdlMapCamera(lon: lon, lat: lat, zoom: zoom);
}
