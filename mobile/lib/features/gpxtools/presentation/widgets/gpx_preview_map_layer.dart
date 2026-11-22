import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../keys.dart';
import '../../../rides/domain/ride_weather_map.dart';
import '../../../rides/presentation/widgets/ride_weather_map_markers.dart';
import '../../../rides/presentation/widgets/ride_wind_map_legend.dart';
import '../../../rides/presentation/widgets/weather_map_layer.dart';
import '../../../routes/domain/route_color_mode.dart';
import '../../../routes/domain/shown_route.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/widgets/route_color_mode_switch.dart';
import '../../../routes/presentation/widgets/route_map.dart';
import '../../providers/gpx_preview_provider.dart';

/// Ce qui colore le tracé d'un aperçu — Pente, Revêtement ou Météo —,
/// partagé par la fiche et sa carte plein écran (le `?color=` du site) : le
/// choix fait dans l'une se retrouve dans l'autre.
final gpxPreviewColorModeProvider = StateProvider.family<RouteColorBy, String>(
  (Ref ref, String previewId) => RouteColorBy.grade,
);

/// Le leg dont le vent peut colorer le tracé d'un aperçu daté, `null` sans
/// prévision exploitable — la règle des cartes de sortie (`showsWindOnMap`).
WeatherLegDto? watchGpxPreviewWindLeg(WidgetRef ref, GpxPreviewDto preview) {
  if (preview.departureTime == null) return null;
  final WeatherLegDto? leg = ref
      .watch(gpxPreviewWeatherProvider(preview.id))
      .value
      ?.legs
      .firstOrNull;
  return showsWindOnMap(leg) ? leg : null;
}

/// Les modes qu'offre l'interrupteur d'un aperçu, et celui qui vaut.
({List<RouteColorBy> modes, RouteColorBy colorBy, WeatherLegDto? windLeg})
watchGpxPreviewColorMode(WidgetRef ref, GpxPreviewDto preview) {
  final WeatherLegDto? leg = watchGpxPreviewWindLeg(ref, preview);
  final List<RouteColorBy> modes = routeColorModes(
    surfaces: hasTrackSurfaces(preview.tracks),
    wind: leg != null,
  );
  final RouteColorBy colorBy = resolveRouteColorBy(
    ref.watch(gpxPreviewColorModeProvider(preview.id)),
    modes,
  );
  return (
    modes: modes,
    colorBy: colorBy,
    windLeg: colorBy == RouteColorBy.wind ? leg : null,
  );
}

/// La couche de la carte d'un aperçu (docs/LEDGER_*.md MOB-178), comme celle
/// d'une étape (`StageDetailPage._mapLayer`) : en mode Météo, le tracé coloré
/// par le vent, les pastilles et la goutte à l'heure du fuseau du départ, la
/// légende et son crédit ; en plein écran, l'interrupteur de mode dans la
/// carte du bas. Encastrée, une pastille touchée ouvre le plein écran.
RouteMapLayerBuilder gpxPreviewMapLayer(GpxPreviewDto preview) =>
    (
      BuildContext context,
      WidgetRef ref,
      ShownRoute route, {
      required bool fullscreen,
    }) {
      final mode = watchGpxPreviewColorMode(ref, preview);
      final WeatherLegDto? windLeg = mode.windLeg;
      final UnitSystem units = ref.watch(unitSystemProvider);
      final String? zone = preview.departureTimezone;
      final RideWeatherDto? weather = preview.departureTime == null
          ? null
          : ref.watch(gpxPreviewWeatherProvider(preview.id)).value;
      return RouteMapLayer(
        colorBy: mode.colorBy,
        segmentColors: windLeg == null
            ? null
            : weatherTrackColors(route, windLeg),
        markers: windLeg == null
            ? const <PdlMapMarker>[]
            : weatherMarkersOnRoute(
                route,
                windLeg,
                units: units,
                timezone: zone,
              ),
        onMarkerTapped: windLeg == null
            ? null
            : fullscreen
            ? (BuildContext context, String id) => openWeatherMapMarker(
                context,
                id,
                leg: windLeg,
                units: units,
                timezone: zone,
              )
            : (BuildContext context, String _) =>
                  PdlMapHero.openFullscreen(context),
        bottomLayer: routeMapBottomLayer(
          modeSwitch: fullscreen && mode.modes.length > 1
              ? RouteColorModeSwitch(
                  key: keys.routeDetail.fullscreenColorBy,
                  modes: mode.modes,
                  value: mode.colorBy,
                  overMap: true,
                  onChanged: (RouteColorBy v) =>
                      ref
                              .read(
                                gpxPreviewColorModeProvider(preview.id)
                                    .notifier,
                              )
                              .state =
                          v,
                )
              : null,
          legend: windLeg == null
              ? null
              : RideWindMapLegend(
                  leg: windLeg,
                  units: units,
                  attribution: weather?.attribution,
                ),
        ),
      );
    };
