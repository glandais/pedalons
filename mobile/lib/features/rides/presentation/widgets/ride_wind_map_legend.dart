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
///
/// Elle porte aussi le crédit que la licence des prévisions demande
/// (« Prévisions : Open-Meteo.com », `RideWeatherDto.attribution`, ledger
/// `MOB-92`), en clair : la carte encastrée ne se manipule pas, et un lien de
/// 44 px n'a pas sa place dans une légende posée sur la carte. L'onglet Météo
/// le rend en lien.
class RideWindMapLegend extends StatelessWidget {
  /// La légende d'un leg : un groupe, une sortie solo, une étape.
  RideWindMapLegend({
    super.key,
    required WeatherLegDto leg,
    required this.units,
    this.attribution,
  }) : exposure = leg.windExposure,
       stale = _isStale(leg),
       defaultSpeed = leg.speedIsDefault ? leg.averageSpeed : null,
       scopeNote = null;

  /// La légende de **plusieurs** legs sur une même carte — les étapes d'un
  /// voyage, chacune colorée par son propre vent (ledger `MOB-94`) : les
  /// parts sont **additionnées** sur les [legs], et [scopeNote] dit sur
  /// lesquelles (« Parts additionnées des 3 étapes »). « Prévision
  /// ancienne » dès qu'un leg l'est ; la vitesse par défaut dès qu'un leg
  /// l'emploie — c'est la même pour tous, celle du serveur.
  RideWindMapLegend.combined({
    super.key,
    required List<WeatherLegDto> legs,
    required this.units,
    required this.scopeNote,
    this.attribution,
  }) : exposure = WindExposureDto(
         head: legs.fold(
           0,
           (double s, WeatherLegDto l) => s + l.windExposure.head,
         ),
         cross: legs.fold(
           0,
           (double s, WeatherLegDto l) => s + l.windExposure.cross,
         ),
         tail: legs.fold(
           0,
           (double s, WeatherLegDto l) => s + l.windExposure.tail,
         ),
       ),
       stale = legs.any(_isStale),
       defaultSpeed = legs
           .where((WeatherLegDto l) => l.speedIsDefault)
           .map((WeatherLegDto l) => l.averageSpeed)
           .firstOrNull;

  /// Les mètres de dos, de travers et de face, tels que le serveur les donne.
  final WindExposureDto exposure;

  /// « Prévision ancienne ».
  final bool stale;

  /// La vitesse des heures estimées quand c'est celle par défaut, `null`
  /// sinon.
  final double? defaultSpeed;

  /// Ce que les parts recouvrent, quand ce n'est pas un seul leg.
  final String? scopeNote;

  final UnitSystem units;

  /// Le crédit des prévisions, `null` tant que la réponse ne l'a pas apporté.
  final WeatherAttributionDto? attribution;

  static bool _isStale(WeatherLegDto leg) =>
      rideWeatherViewOf(leg.status, canSeeNoLocation: false) ==
      RideWeatherView.stale;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final List<(RelativeWind, double)> entries = <(RelativeWind, double)>[
      (RelativeWind.tail, exposure.tail),
      (RelativeWind.cross, exposure.cross),
      (RelativeWind.head, exposure.head),
    ].where(((RelativeWind, double) e) => e.$2 > 0).toList();
    final double? speed = defaultSpeed;

    final List<String> notes = <String>[
      ?scopeNote,
      if (stale) 'rides.weather.stale'.tr(),
      if (speed != null)
        'rides.weather.mapDefaultSpeed'.tr(
          namedArgs: <String, String>{
            'speed': AppFormatters.formatSpeed(speed, units),
          },
        ),
    ];
    final WeatherAttributionDto? credit = attribution;

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
        if (credit != null) weatherAttributionLabel(credit),
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
                if (credit != null)
                  Text(
                    weatherAttributionLabel(credit),
                    key: keys.rideGroup.windMapCredit,
                    style: t.xs.copyWith(color: c.textDimmed),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
