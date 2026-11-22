import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/pdl/elevation/elevation_samples.dart';
import '../../gpxtools/providers/gpx_preview_provider.dart';
import '../domain/shown_route.dart';
import '../domain/track_slope_colors.dart';
import '../domain/track_surfaces.dart';
import '../domain/track_wind_bars.dart';
import 'route_detail_provider.dart';

/// Le tracé que montre [key] : le détail d'un parcours d'équipe, ou un aperçu
/// des outils GPX (ledger `MOB-178`). Même requête, même cache que
/// [routeDetailProvider] et [gpxPreviewProvider] : rien n'est relu deux fois.
final shownRouteProvider = Provider.family<AsyncValue<ShownRoute>, TrackKey>((
  Ref ref,
  TrackKey key,
) {
  return switch (key) {
    RouteKey() =>
      ref
          .watch(routeDetailProvider(key))
          .whenData((RouteDetailDto route) => route.shown),
    GpxPreviewKey(:final String previewId) =>
      ref
          .watch(gpxPreviewProvider(previewId))
          .whenData((GpxPreviewDto preview) => preview.shown),
  };
}, isAutoDispose: true);

/// Relit le tracé de [key] à sa source — le « Réessayer » d'une carte ou d'un
/// profil en échec.
void invalidateShownRoute(WidgetRef ref, TrackKey key) {
  switch (key) {
    case RouteKey():
      ref.invalidate(routeDetailProvider(key));
    case GpxPreviewKey(:final String previewId):
      ref.invalidate(gpxPreviewProvider(previewId));
  }
}

/// Le profil d'un parcours, **prêt à peindre**, dérivé de sa géométrie.
///
/// Un cran au-dessus de [shownRouteProvider], qui rend le tracé : ici
/// l'agrégation vers ~76 barres est faite une fois et **mémorisée avec la
/// réponse**. Sans ce palier, chaque `build` reconstruirait un
/// [ElevationSamples] neuf, que le painter comparerait par identité et jugerait
/// donc toujours différent — le profil se repeindrait à chaque frame de
/// glissement du réticule, ce que toute l'architecture à deux couches cherche
/// précisément à éviter.
///
/// La donnée vient du **même appel** que le tracé : plus de clé portant un
/// nombre d'échantillons, plus de requête séparée, et un axe des distances
/// rigoureusement identique à celui du curseur de la carte.
///
/// La valeur est `null` quand le parcours n'a pas d'altitude exploitable —
/// l'écran ne rend alors pas de profil, plutôt qu'un profil plat.
final routeElevationSamplesProvider =
    Provider.family<AsyncValue<ElevationSamples?>, TrackKey>((
      Ref ref,
      TrackKey key,
    ) {
      return ref
          .watch(shownRouteProvider(key))
          .whenData((ShownRoute route) => route.elevationSamples());
    }, isAutoDispose: true);

/// La classe de revêtement de chaque barre du profil (`MOB-81`), **mémorisée**
/// avec le profil : `ElevationAreaPainter` compare ses couleurs par identité.
///
/// `null` sans revêtement prêt ou sans profil.
final routeSurfaceBarsProvider =
    Provider.family<AsyncValue<List<TrackSurface?>?>, TrackKey>((
      Ref ref,
      TrackKey key,
    ) {
      final AsyncValue<ShownRoute> detail = ref.watch(shownRouteProvider(key));
      final AsyncValue<ElevationSamples?> samples = ref.watch(
        routeElevationSamplesProvider(key),
      );
      return detail.whenData((ShownRoute route) {
        final ElevationSamples? s = samples.value;
        if (s == null || !hasTrackSurfaces(route.tracks)) return null;
        return barSurfaces(s, route.tracks);
      });
    }, isAutoDispose: true);

/// La pente des montées sous chaque barre du profil et sa couleur (ledger
/// `MOB-105`), **mémorisées** avec le profil : `ElevationAreaPainter` compare
/// ses couleurs par identité.
///
/// `null` sans profil.
final routeClimbBarsProvider =
    Provider.family<AsyncValue<ClimbBars?>, TrackKey>((Ref ref, TrackKey key) {
      final AsyncValue<ShownRoute> detail = ref.watch(shownRouteProvider(key));
      final AsyncValue<ElevationSamples?> samples = ref.watch(
        routeElevationSamplesProvider(key),
      );
      return detail.whenData((ShownRoute route) {
        final ElevationSamples? s = samples.value;
        return s == null ? null : climbBars(s, route.tracks);
      });
    }, isAutoDispose: true);

/// Le vent de [WindBarsKey.leg] sous chaque barre du profil et sa couleur
/// (ledger `MOB-106`), **mémorisés** avec le profil : `ElevationBandPainter`
/// compare ses couleurs par identité.
///
/// `null` sans profil.
final routeWindBarsProvider =
    Provider.family<AsyncValue<WindBars?>, WindBarsKey<TrackKey>>((
      Ref ref,
      WindBarsKey<TrackKey> key,
    ) {
      final AsyncValue<ShownRoute> detail = ref.watch(
        shownRouteProvider(key.route),
      );
      final AsyncValue<ElevationSamples?> samples = ref.watch(
        routeElevationSamplesProvider(key.route),
      );
      return detail.whenData((ShownRoute route) {
        final ElevationSamples? s = samples.value;
        return s == null ? null : windBars(s, route.tracks, key.leg);
      });
    }, isAutoDispose: true);
