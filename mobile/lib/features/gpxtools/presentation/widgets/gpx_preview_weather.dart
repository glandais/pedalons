import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../keys.dart';
import '../../../rides/domain/ride_weather_display.dart';
import '../../../rides/presentation/widgets/weather_section.dart';

/// La section Météo d'un aperçu daté (docs/LEDGER_*.md MOB-178) : la
/// `WeatherSection` des fiches, sur l'unique leg du tracé, avec les trois cas
/// propres aux outils GPX du site (`GpxPreviewWeatherSection`) :
///
/// * la météo **arrive** (cache vide, la fenêtre de relecture est ouverte,
///   [waiting]) : « Récupération des prévisions en cours », pas
///   « indisponible » ;
/// * le départ est **passé** (`OUT_OF_RANGE`) : une phrase qui le dit, pour
///   ne pas le prendre pour une panne ;
/// * un échec de lecture se lit comme `UNAVAILABLE`, avec « Réessayer ».
///
/// Rien sans date de départ : l'écran ne pose pas la section.
class GpxPreviewWeather extends StatelessWidget {
  const GpxPreviewWeather({
    super.key,
    required this.preview,
    required this.weather,
    required this.waiting,
    required this.onRetry,
    this.collapsed = true,
  });

  final GpxPreviewDto preview;
  final AsyncValue<RideWeatherDto> weather;

  /// La fenêtre de relecture est ouverte (`WeatherArrivalPoller.waiting`).
  final bool waiting;
  final VoidCallback onRetry;

  /// La frise repliée : du contenu suit (les points du parcours).
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final String? zone = preview.departureTimezone;
    return KeyedSubtree(
      key: keys.gpxTools.previewWeather,
      child: weather.when(
        loading: () => const Padding(
          padding: EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.detailSectionGap,
            PdlSpacing.section,
            0,
          ),
          child: PdlSkeleton(height: 120, borderRadius: PdlRadii.cardAll),
        ),
        error: (Object _, StackTrace _) => WeatherSection(
          view: RideWeatherView.unavailable,
          timezone: zone,
          onRetry: onRetry,
        ),
        data: (RideWeatherDto dto) {
          final WeatherStatus status = WeatherStatus.fromJson(dto.status);
          if (status == WeatherStatus.outOfRange) {
            return WeatherSection(
              view: RideWeatherView.hidden,
              timezone: zone,
              emptyMessage: 'gpxTools.weather.departed'.tr(),
            );
          }
          if (status == WeatherStatus.unavailable && waiting) {
            return const _Pending();
          }
          return WeatherSection(
            view: rideWeatherViewOf(dto.status, canSeeNoLocation: false),
            timezone: zone,
            departure: dto.departure,
            departureAt: preview.departureTime,
            departureOf: WeatherDepartureOf.ride,
            leg: dto.legs.firstOrNull,
            attribution: dto.attribution,
            fetchedAt: dto.fetchedAt == null
                ? null
                : DateTime.tryParse(dto.fetchedAt!),
            availableFrom: dto.availableFrom == null
                ? null
                : DateTime.tryParse(dto.availableFrom!),
            collapsed: collapsed,
            speedDefaultKey: 'gpxTools.weather.timelineSpeedDefault',
            onRetry: onRetry,
          );
        },
      ),
    );
  }
}

/// « Météo », puis « Récupération des prévisions en cours… ».
class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return DetailSection(
      title: 'rides.weather.title'.tr(),
      child: Row(
        key: keys.gpxTools.previewWeatherPending,
        children: <Widget>[
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          Expanded(
            child: Text(
              'gpxTools.weather.pending'.tr(),
              style: t.sub.copyWith(color: c.textDimmed),
            ),
          ),
        ],
      ),
    );
  }
}
