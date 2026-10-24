import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../domain/ride_weather_display.dart';
import 'ride_weather_widgets.dart';

/// La légende du vent posée sur la carte d'un groupe en mode « Météo »
/// (ledger `MOB-91`) : **en mots**, avec les parts du parcours —
/// « Dos 32 km · Travers 18 km · Face 40 km » —, puis « Prévision ancienne »
/// en `STALE` et « Heures estimées à 25 km/h » quand la vitesse est celle par
/// défaut.
///
/// La couleur n'est jamais seule : chaque trait porte son libellé, et un
/// lecteur d'écran entend le résumé de l'exposition. Les parts viennent du
/// serveur (`WeatherLegDto.windExposure`) : l'app ne recalcule rien.
class RideWindMapLegend extends StatelessWidget {
  const RideWindMapLegend({super.key, required this.leg, required this.units});

  final WeatherLegDto leg;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final WindExposureDto exposure = leg.windExposure;
    final List<(RelativeWind, double)> entries = <(RelativeWind, double)>[
      (RelativeWind.tail, exposure.tail),
      (RelativeWind.cross, exposure.cross),
      (RelativeWind.head, exposure.head),
    ].where(((RelativeWind, double) e) => e.$2 > 0).toList();
    final bool stale =
        rideWeatherViewOf(leg.status, canSeeNoLocation: false) ==
        RideWeatherView.stale;

    final List<String> notes = <String>[
      if (stale) 'rides.weather.stale'.tr(),
      if (leg.speedIsDefault)
        'rides.weather.mapDefaultSpeed'.tr(
          namedArgs: <String, String>{
            'speed': AppFormatters.formatSpeed(leg.averageSpeed, units),
          },
        ),
    ];

    return Semantics(
      key: keys.rideGroup.windMapLegend,
      container: true,
      label: <String>[
        'rides.weather.segmentsSemantics'.tr(
          namedArgs: <String, String>{
            'summary': exposureSummary(exposure, units),
          },
        ),
        ...notes,
      ].join('. '),
      child: ExcludeSemantics(
        child: PdlBlurSurface(
          sigma: PdlMotion.blurOverlayButton,
          color: c.overlaySolid,
          borderRadius: PdlRadii.mdAll,
          border: Border.all(color: c.borderSubtle),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PdlSpacing.chipGap,
              vertical: PdlSpacing.badgeGap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: PdlSpacing.chipGap,
                  runSpacing: PdlSpacing.badgeGap,
                  children: <Widget>[
                    for (final (RelativeWind wind, double meters) in entries)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PdlColorTrack(
                            color: wind.stroke,
                            shape: PdlColorTrackShape.legend,
                          ),
                          const SizedBox(width: PdlSpacing.badgeGap),
                          Text(
                            'rides.weather.exposure.${wind.name}'.tr(
                              namedArgs: <String, String>{
                                'distance': AppFormatters.formatDistance(
                                  meters,
                                  units,
                                ),
                              },
                            ),
                            style: t.xs.copyWith(color: c.text),
                          ),
                        ],
                      ),
                  ],
                ),
                for (final String note in notes)
                  Text(note, style: t.xs.copyWith(color: c.textDimmed)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
