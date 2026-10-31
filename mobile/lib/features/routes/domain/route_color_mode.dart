import 'track_surfaces.dart';

/// L'interrupteur **unique** Pente | Revêtement | Météo d'une carte de parcours
/// (ledger `MOB-105`), la logique de `useWindColorMode` au site
/// (`frontend/src/hooks/useWindColorMode.tsx`) : un choix partagé par la carte
/// encastrée, son plein écran et le profil.
///
/// * il ne propose que les modes disponibles — le revêtement quand une piste
///   l'a ([hasTrackSurfaces]), Météo quand le leg a une prévision à montrer ;
/// * Météo n'est jamais le mode par défaut : le choix part sur la pente ;
/// * un mode devenu indisponible (revêtement absent, prévision perdue) se lit
///   comme la pente ([resolveRouteColorBy]) ;
/// * le profil suit Pente | Revêtement, et reste sur la pente en Météo
///   ([profileColorBy]).

/// Les modes proposés, dans l'ordre de l'interrupteur.
List<RouteColorBy> routeColorModes({
  required bool surfaces,
  required bool wind,
}) => <RouteColorBy>[
  RouteColorBy.grade,
  if (surfaces) RouteColorBy.surface,
  if (wind) RouteColorBy.wind,
];

/// Le mode effectif : [chosen] s'il est proposé, la pente sinon.
RouteColorBy resolveRouteColorBy(
  RouteColorBy chosen,
  List<RouteColorBy> modes,
) => modes.contains(chosen) ? chosen : RouteColorBy.grade;

/// Ce que colore le profil : le revêtement en mode revêtement, la pente
/// sinon — Météo compris, comme au site.
RouteColorBy profileColorBy(RouteColorBy mode) =>
    mode == RouteColorBy.surface ? RouteColorBy.surface : RouteColorBy.grade;
