import 'package:dio/dio.dart';

import '../../../api/generated/export.dart';
import '../../../core/logging/app_log.dart';
import '../domain/route_generator.dart';
import 'planner_bridge.dart';

/// « Me localiser » dans le planificateur embarqué (`load.locate`). Éteint :
/// l'app ne déclare lire la position que pour trier par distance
/// (`NSLocationWhenInUseUsageDescription`, `store-metadata/data-safety.md`
/// n° 10). L'allumer demande de mettre ces déclarations à jour d'abord
/// (docs/LEDGER_*.md MOB-170, MOB-131).
const bool kPlannerLocate = false;

/// Un style servi par notre API (`/api/map/styles/*`) : la page, d'origine
/// `null`, ne peut pas le lire (aucun en-tête CORS) — l'app lit le document
/// et le lui passe. Les styles d'un CDN tiers restent des adresses.
bool isApiStyleUrl(String url, String apiBaseUrl) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !uri.path.startsWith('/api/')) return false;
  return !uri.hasAuthority || uri.host == Uri.parse(apiBaseUrl).host;
}

/// Les fonds de carte de `ConfigDto.mapStyles` comme `load.styles` les veut :
/// pour un style de notre API, `url` devient `style` (le document), et
/// `darkVariant` devient `darkStyle`. Un document illisible retire son
/// adresse : la page saute un fond sans document ni adresse, plutôt que de
/// buter sur le CORS.
Future<List<Map<String, dynamic>>> plannerMapStyles(
  List<MapStyleDto> styles, {
  required Dio dio,
  required String apiBaseUrl,
}) {
  Future<void> inline(
    Map<String, dynamic> style,
    String urlKey,
    String documentKey,
  ) async {
    final Object? url = style[urlKey];
    if (url is! String || !isApiStyleUrl(url, apiBaseUrl)) return;
    style.remove(urlKey);
    try {
      final Response<dynamic> document = await dio.get<dynamic>(
        Uri.parse(apiBaseUrl).resolve(url).toString(),
      );
      if (document.data != null) style[documentKey] = document.data;
    } on DioException catch (error) {
      AppLog.instance.warn('planner', 'style ${style['id']}: ${error.type}');
    }
  }

  return Future.wait(<Future<Map<String, dynamic>>>[
    for (final MapStyleDto dto in styles)
      () async {
        final Map<String, dynamic> style = dto.toJson()
          ..removeWhere((String _, Object? value) => value == null);
        await Future.wait(<Future<void>>[
          inline(style, 'url', 'style'),
          inline(style, 'darkVariant', 'darkStyle'),
        ]);
        return style;
      }(),
  ]);
}

/// Le tracé à une trace qu'ouvre le planificateur : celui d'un parcours
/// d'équipe ([plannerTrackOfRoute]) ou d'un aperçu des outils GPX
/// (docs/LEDGER_*.md MOB-178).
typedef PlannerTrack = ({
  List<List<double>> line,
  double ascend,
  List<WaypointDto> waypoints,
  double distance,
});

PlannerTrack plannerTrackOfRoute(RouteDetailDto route) => (
  line: route.tracks.single.line.coordinates,
  ascend: route.elevationGain,
  waypoints: route.waypoints,
  distance: route.distance,
);

/// L'argument de `window.pedalonsPlanner.load`, tiré des données de l'app
/// (docs/LEDGER_*.md MOB-170 ; champs : README du planificateur embarqué).
///
/// [route] nul : création, la page s'ouvre vide et tout le tracé partira
/// (`create: true`, **toujours explicite**). Sinon le tracé à une trace
/// s'ouvre sur son état d'édition enregistré, lu par [readState] juste
/// maintenant — jamais d'un cache — ; si la lecture échoue, il s'ouvre sur sa
/// trace, comme un import, et [PlannerLoad.stateReadFailed] le dit.
///
/// [generated] : une proposition du générateur, que la page importe à
/// l'ouverture (`load.generated`) — à la création (docs/LEDGER_*.md MOB-154),
/// ou sur un parcours existant dont elle remplace la trace sans question
/// (une retouche, MOB-185).
///
/// [team] nul : un aperçu des outils GPX, qui n'est d'aucune équipe — ni
/// `teamSlug` (le quota est alors le quota personnel), ni position d'équipe
/// (la carte s'ouvre sur `defaultCenter`).
Future<PlannerLoad> buildPlannerLoad({
  required TeamDetailDto? team,
  required PlannerTrack? route,
  required String routeName,
  required ConfigDto config,
  required Dio dio,
  required String apiBaseUrl,
  required Future<PlannerState?> Function() readState,
  required bool dark,
  required String locale,
  required UnitSystem units,
  GeneratedHandoff? generated,
}) async {
  PlannerState? state;
  bool stateReadFailed = false;
  final Future<List<Map<String, dynamic>>> styles = plannerMapStyles(
    config.mapStyles,
    dio: dio,
    apiBaseUrl: apiBaseUrl,
  );
  if (route != null) {
    try {
      state = await readState();
    } on Object catch (error) {
      AppLog.instance.warn('planner', 'planner-state: $error');
      stateReadFailed = true;
    }
  }
  final List<double>? location = team?.geometry?.coordinates;
  final MapTerrainDto? terrain = config.terrain;
  final String name = routeName.trim();
  // Les DTO générés écrivent `null` pour un champ absent ; l'API, elle, ne
  // l'écrit pas, et c'est ce que le planificateur du site a toujours lu.
  final Map<String, dynamic> input = withoutNulls(<String, dynamic>{
    'state': ?state?.toJson(),
    if (route != null) ...<String, dynamic>{
      'track': route.line,
      'ascend': route.ascend,
      'waypoints': <Map<String, dynamic>>[
        for (final WaypointDto waypoint in route.waypoints) waypoint.toJson(),
      ],
      'waypointsTotal': route.distance,
    },
    if (name.isNotEmpty) 'routeName': name,
    'teamSlug': ?team?.slug,
    if (location != null && location.length >= 2)
      'teamLocation': <double>[location[0], location[1]],
    'create': route == null,
    if (generated != null)
      'generated': <String, dynamic>{
        'polyline': generated.polyline,
        'name': generated.name,
      },
    'terrain': ?terrain?.toJson(),
    'defaultCenter': config.defaultCenter.toJson(),
    'theme': dark ? 'dark' : 'light',
    'locale': locale,
    'units': units == UnitSystem.imperial ? 'IMPERIAL' : 'METRIC',
    if (kPlannerLocate) 'locate': true,
  });
  // Les documents de style, eux, passent tels que lus.
  input['styles'] = await styles;
  return PlannerLoad(input, stateReadFailed: stateReadFailed);
}

/// [json] sans ses clés de valeur `null`, à toute profondeur.
Map<String, dynamic> withoutNulls(Map<String, dynamic> json) {
  Object? clean(Object? value) => switch (value) {
    final Map<String, dynamic> map => withoutNulls(map),
    final List<dynamic> list => <Object?>[
      for (final Object? v in list) clean(v),
    ],
    _ => value,
  };
  return <String, dynamic>{
    for (final MapEntry<String, dynamic> entry in json.entries)
      if (entry.value != null) entry.key: clean(entry.value),
  };
}

/// Le planificateur n'ouvre qu'un parcours à **une** trace : un parcours à
/// plusieurs traces ne se modifie que par fichier GPX, comme au site.
bool isSingleTrack(RouteDetailDto route) => route.tracks.length == 1;
