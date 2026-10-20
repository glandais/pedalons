import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../keys.dart';
import '../../domain/track_surfaces.dart';

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

/// Le revêtement le long du parcours, sur la fiche (`MOB-81`) : la bascule
/// Pente / Revêtement du profil et du tracé, la barre de répartition, sa
/// légende et l'attribution OpenStreetMap.
///
/// Ne rend rien sans revêtement ; une ligne d'attente tant qu'il se calcule.
class RouteSurfaceSection extends StatelessWidget {
  const RouteSurfaceSection({
    super.key,
    required this.tracks,
    required this.colorBy,
    required this.onColorByChanged,
  });

  final List<TrackDto> tracks;
  final RouteColorBy colorBy;
  final ValueChanged<RouteColorBy> onColorByChanged;

  /// Largeur de la bascule : `PdlSegmented` exige une largeur bornée.
  static const double _toggleWidth = 260;

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
        Semantics(
          label: 'routes.surfaceDetail.colorBy'.tr(),
          container: true,
          child: SizedBox(
            width: _toggleWidth,
            child: PdlSegmented<RouteColorBy>(
              key: keys.routeDetail.surfaceColorBy,
              value: colorBy,
              onChanged: onColorByChanged,
              segments: <PdlSegment<RouteColorBy>>[
                PdlSegment<RouteColorBy>(
                  value: RouteColorBy.grade,
                  label: 'routes.surfaceDetail.grade'.tr(),
                ),
                PdlSegment<RouteColorBy>(
                  value: RouteColorBy.surface,
                  label: 'routes.surfaceDetail.surface'.tr(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
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
