import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';

/// Hauteur de la carte de localisation d'une annonce.
const double _kMapHeight = 140;

/// Rayon **à l'écran** du secteur, en pixels logiques.
///
/// C'est lui qui fixe le zoom, et non l'inverse : on choisit d'abord la place
/// que le secteur doit occuper dans une carte de 140 px, puis on en déduit
/// l'échelle à laquelle 500 m mesurent exactement cela. La pastille dit donc
/// la même chose à Lille et à Marseille, où un pixel ne couvre pas la même
/// distance.
const double _kSectorRadiusPx = 44;

/// Rayon du secteur, en mètres.
///
/// `AdDto.locationGeometry` est le centre d'une cellule d'environ **1 km** —
/// valeur confirmée, pas une hypothèse : un rayon de 500 m est donc la
/// traduction exacte de l'imprécision, ni prudence ni approximation.
const double _kSectorRadiusMeters = 500;

/// La localisation approximative d'une annonce.
///
/// **Un secteur, jamais une punaise.** Une punaise posée sur un centre de
/// cellule prétendrait une précision que la donnée n'a pas : elle désignerait
/// un carrefour quand l'annonce est quelque part dans le quartier. Le rendu est
/// donc un disque flou de 500 m de rayon, sans point central, doublé d'une
/// légende qui dit la même chose en toutes lettres.
///
/// Le bloc entier **n'existe pas** quand `locationGeometry` est nul : une carte
/// centrée sur un repli serait un mensonge de plus.
class AdLocationMap extends ConsumerWidget {
  const AdLocationMap({super.key, required this.geometry});

  final AdDtoLocationGeometry geometry;

  /// `coordinates` est `[longitude, latitude]` — l'ordre GeoJSON, l'inverse de
  /// celui qu'on prononce.
  double get _lon => geometry.coordinates.first;
  double get _lat => geometry.coordinates[1];

  /// Le zoom auquel [_kSectorRadiusMeters] mesure [_kSectorRadiusPx].
  ///
  /// MapLibre compte ses tuiles en 512 px : à la latitude 0 et au zoom 0, un
  /// pixel couvre 78 271,5 m, et la couverture est divisée par deux à chaque
  /// niveau, puis rétrécie par le cosinus de la latitude — la projection de
  /// Mercator étire les hautes latitudes.
  double get _zoom {
    const double metersPerPixelAtZoom0 = 78271.516964020484;
    final double metersPerPixel = _kSectorRadiusMeters / _kSectorRadiusPx;
    final double atLatitude =
        metersPerPixelAtZoom0 * math.cos(_lat * math.pi / 180);
    return math.log(atLatitude / metersPerPixel) / math.ln2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final ResolvedMapStyle? style = ref
        .watch(mapStyleProvider(Theme.of(context).brightness))
        .value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Le lecteur d'écran n'a pas de carte : il a la même phrase que la
        // légende, qui est de toute façon l'information.
        Semantics(
          label: 'ads.detail.locationApproximate'.tr(),
          image: true,
          child: ClipRRect(
            borderRadius: PdlRadii.mdAll,
            child: SizedBox(
              height: _kMapHeight,
              child: style == null
                  ? const PdlSkeleton(
                      height: _kMapHeight,
                      borderRadius: PdlRadii.mdAll,
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        PdlMap(
                          key: keys.ad.locationMap,
                          styleUrl: style.url,
                          credit: servedMapCredit(style),
                          scale: servedMapScale(ref),
                          initialCenter: PdlMapPoint(lon: _lon, lat: _lat),
                          initialZoom: _zoom,
                          // La carte illustre, elle ne s'explore pas : la
                          // faire glisser ferait croire qu'on cherche
                          // l'adresse.
                          gestures: const MapGestures.none(),
                        ),
                        IgnorePointer(
                          key: keys.ad.locationSector,
                          child: const Center(child: _Sector()),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        ExcludeSemantics(
          child: Text(
            'ads.detail.locationApproximate'.tr(),
            key: keys.ad.locationCaption,
            style: t.xs,
          ),
        ),
      ],
    );
  }
}

/// Le disque de 500 m : bord fondu, aucun centre marqué.
///
/// Le fondu n'est pas décoratif. Un cercle à bord net se lit comme une limite —
/// « l'annonce est dans ce cercle et pas à un mètre de plus » —, alors que la
/// cellule d'origine est un carré dont ce cercle n'est qu'une approximation.
class _Sector extends StatelessWidget {
  const _Sector();

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    return Container(
      width: _kSectorRadiusPx * 2,
      height: _kSectorRadiusPx * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            c.primary.withValues(alpha: 0.28),
            c.primary.withValues(alpha: 0.22),
            c.primary.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.72, 1],
        ),
        border: Border.all(color: c.primary.withValues(alpha: 0.35)),
      ),
    );
  }
}
