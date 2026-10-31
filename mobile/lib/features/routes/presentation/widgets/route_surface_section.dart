import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../keys.dart';
import '../../domain/track_slope_colors.dart';
import '../../domain/track_surfaces.dart';
import '../../domain/track_wind_bars.dart';
import '../../../rides/domain/ride_weather_display.dart';

/// Le libellé d'une classe de revêtement (`MOB-81`) — ceux du site.
String trackSurfaceLabel(TrackSurface surface) => switch (surface) {
  TrackSurface.paved => 'routes.surfaceDetail.class.paved'.tr(),
  TrackSurface.pavedRough => 'routes.surfaceDetail.class.pavedRough'.tr(),
  TrackSurface.gravel => 'routes.surfaceDetail.class.gravel'.tr(),
  TrackSurface.dirt => 'routes.surfaceDetail.class.dirt'.tr(),
  TrackSurface.path => 'routes.surfaceDetail.class.path'.tr(),
  TrackSurface.offNetwork => 'routes.surfaceDetail.class.offNetwork'.tr(),
  TrackSurface.unknown ||
  TrackSurface.$unknown => 'routes.surfaceDetail.class.unknown'.tr(),
};

/// La part d'une classe, arrondie à l'unité, « < 1 % » sous 0,5 % (règle du
/// site).
String trackSurfaceShareLabel(double share) {
  final double percent = share * 100;
  if (percent < 0.5) return 'routes.surfaceDetail.shareBelowOne'.tr();
  return 'routes.surfaceDetail.share'.tr(
    namedArgs: <String, String>{'share': percent.round().toString()},
  );
}

/// La classe de revêtement sous le réticule (mode revêtement), à la place de
/// la pente — dans l'infobulle du profil.
String? trackSurfaceTip(
  ElevationSamples samples,
  List<TrackSurface?> bars,
  double distance,
) {
  final ElevationBar? bar = samples.barAt(distance);
  if (bar == null) return null;
  final int index = samples.bars.indexOf(bar);
  final TrackSurface? surface = index >= 0 && index < bars.length
      ? bars[index]
      : null;
  return surface == null ? null : trackSurfaceLabel(surface);
}

/// La pente de l'infobulle du profil en mode « Pente » (ledger `MOB-105`) :
/// celle de la montée sous le réticule, rien hors montée — comme au site.
/// Sans les montées (pas encore mémorisées), la pente de la barre.
String? climbGradeTipLabel(
  ElevationSamples samples,
  ClimbBars? climbs,
  ElevationReading reading,
) {
  final double? grade = climbs == null
      ? reading.grade
      : climbGradeTip(samples, climbs, reading.distance);
  return grade == null ? null : AppFormatters.formatGrade(grade);
}

/// Le vent de l'infobulle du profil en mode Météo (ledger `MOB-106`) : celui
/// de la barre sous le réticule, « Vent de face »…, ou « Vent inconnu » —
/// toujours écrit, jamais seulement en couleur.
String windTipLabel(ElevationSamples samples, WindBars bars, double at) {
  final RelativeWind? wind = windTip(samples, bars, at);
  return wind == null
      ? 'rides.weather.relativeWindUnknown'.tr()
      : wind.labelKey.tr();
}

/// Les couleurs des barres du profil en mode revêtement, mémorisées : le
/// painter les compare par identité, il repeindrait sinon à chaque `build`.
class TrackSurfaceBarColors {
  List<TrackSurface?>? _bars;
  PdlColors? _colors;
  List<Color?>? _barColors;

  /// Recalculées seulement si les classes ou le thème changent.
  List<Color?> of(List<TrackSurface?> bars, PdlColors c) {
    if (identical(bars, _bars) && c == _colors) return _barColors!;
    _bars = bars;
    _colors = c;
    return _barColors = <Color?>[
      for (final TrackSurface? s in bars) s?.stroke(c),
    ];
  }
}

/// Le revêtement le long du parcours, sur la fiche et la fiche embarquée
/// d'une étape (`MOB-81`, `MOB-82`) : la barre de répartition, sa légende et
/// l'attribution OpenStreetMap. La bascule Pente / Revêtement n'est plus ici :
/// c'est l'interrupteur unique sous la carte (`RouteColorModeSwitch`, ledger
/// `MOB-105`).
///
/// Ne rend rien sans revêtement ; une ligne d'attente tant qu'il se calcule.
class RouteSurfaceSection extends StatelessWidget {
  const RouteSurfaceSection({super.key, required this.tracks});

  final List<TrackDto> tracks;

  static const String _copyright = 'https://www.openstreetmap.org/copyright';

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    if (!hasTrackSurfaces(tracks)) {
      if (!trackSurfacesPending(tracks)) return const SizedBox.shrink();
      return Text(
        'routes.surfaceDetail.pending'.tr(),
        key: keys.routeDetail.surfacePending,
        style: t.xs.copyWith(color: c.textDimmed),
      );
    }

    final List<TrackSurfaceShare> shares = surfaceShares(tracks);
    final List<String> labels = <String>[
      for (final TrackSurfaceShare s in shares)
        '${trackSurfaceLabel(s.surface)} ${trackSurfaceShareLabel(s.share)}',
    ];

    return Column(
      key: keys.routeDetail.surfaceSection,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: PdlSegmentBar(
            key: keys.routeDetail.surfaceBar,
            semanticLabel: labels.join(', '),
            entries: <PdlSegmentBarEntry>[
              for (final TrackSurfaceShare s in shares)
                PdlSegmentBarEntry(
                  extent: s.length,
                  color: s.surface.stroke(c),
                ),
            ],
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlLegendRow(
          padding: EdgeInsets.zero,
          entries: <PdlLegendEntry>[
            for (int i = 0; i < shares.length; i++)
              PdlLegendEntry(
                color: shares[i].surface.stroke(c),
                label: labels[i],
              ),
          ],
        ),
        Semantics(
          link: true,
          child: InkWell(
            key: keys.routeDetail.surfaceAttribution,
            onTap: () => openLink(context, _copyright),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: PdlMetrics.tapTarget,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'routes.surfaceDetail.attribution'.tr(),
                  style: t.xs.copyWith(color: c.textDimmed),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
