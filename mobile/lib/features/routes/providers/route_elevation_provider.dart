import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/pdl/elevation/elevation_samples.dart';
import '../domain/route_elevation_builder.dart';
import '../domain/track_surfaces.dart';
import 'route_detail_provider.dart';

/// Le profil d'un parcours, **prêt à peindre**, dérivé de sa géométrie.
///
/// Un cran au-dessus de [routeDetailProvider], qui rend le DTO : ici
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
    Provider.family<AsyncValue<ElevationSamples?>, RouteKey>((
      Ref ref,
      RouteKey key,
    ) {
      return ref
          .watch(routeDetailProvider(key))
          .whenData((RouteDetailDto route) => route.elevationSamples());
    }, isAutoDispose: true);

/// La classe de revêtement de chaque barre du profil (`MOB-81`), **mémorisée**
/// avec le profil : `ElevationAreaPainter` compare ses couleurs par identité.
///
/// `null` sans revêtement prêt ou sans profil.
final routeSurfaceBarsProvider =
    Provider.family<AsyncValue<List<TrackSurface?>?>, RouteKey>((
      Ref ref,
      RouteKey key,
    ) {
      final AsyncValue<RouteDetailDto> detail = ref.watch(
        routeDetailProvider(key),
      );
      final AsyncValue<ElevationSamples?> samples = ref.watch(
        routeElevationSamplesProvider(key),
      );
      return detail.whenData((RouteDetailDto route) {
        final ElevationSamples? s = samples.value;
        if (s == null || !hasTrackSurfaces(route.tracks)) return null;
        return barSurfaces(s, route.tracks);
      });
    }, isAutoDispose: true);
