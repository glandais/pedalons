import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/geo/polyline_index.dart';
import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../domain/planner_result.dart';

/// L'aperçu d'un tracé dessiné dans le planificateur, de retour dans le
/// formulaire (docs/LEDGER_*.md MOB-170) : la forme du tracé, sa distance, son
/// dénivelé et son nombre de points de contrôle.
///
/// La vignette est un simple trait ([_TrackPainter]) tiré de `done.stats.line`
/// — pas de carte native : le tracé n'existe encore que dans la page, et
/// aucune tuile n'aide à le reconnaître à cette taille.
class PlannerPreviewCard extends ConsumerWidget {
  const PlannerPreviewCard({super.key, required this.stats});

  final PlannerStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final String points = 'routes.editor.trackPoints'.plural(stats.pointCount);
    return Column(
      key: keys.routeEditor.plannerPreview,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: 'routes.editor.trackDrawn'.tr(),
          image: true,
          child: Container(
            height: PdlMetrics.media120,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: PdlRadii.mdAll,
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.all(PdlSpacing.cardTight),
            child: CustomPaint(
              painter: _TrackPainter(stats.line, c.primary),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlStatRow(
          stats: <PdlStat>[
            PdlStat(
              icon: PdlIcons.distance,
              value: AppFormatters.formatDistance(stats.distance, units),
            ),
            PdlStat(
              icon: PdlIcons.elevationUp,
              value: AppFormatters.formatElevationGain(stats.ascend, units),
            ),
          ],
        ),
        const SizedBox(height: PdlSpacing.badgeGap),
        Text(points, style: t.sub.copyWith(color: c.textDimmed)),
      ],
    );
  }
}

/// Le tracé, ramené à la boîte : projection de Mercator (la forme d'un
/// parcours long en latitude ne s'écrase pas), échelle unique sur les deux
/// axes, centré.
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.line, this.color);

  final List<LngLat> line;
  final Color color;

  static double _y(double lat) {
    final double clamped = lat.clamp(-85.0, 85.0) * math.pi / 180;
    return -math.log(math.tan(math.pi / 4 + clamped / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (line.length < 2 || size.isEmpty) return;
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;
    final List<Offset> projected = <Offset>[
      for (final LngLat p in line) Offset(p.lng * math.pi / 180, _y(p.lat)),
    ];
    for (final Offset p in projected) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final double width = maxX - minX;
    final double height = maxY - minY;
    final double scale = math.min(
      width > 0 ? size.width / width : double.infinity,
      height > 0 ? size.height / height : double.infinity,
    );
    if (!scale.isFinite) return;
    final double dx = (size.width - width * scale) / 2;
    final double dy = (size.height - height * scale) / 2;
    final Path path = Path();
    for (final (int i, Offset p) in projected.indexed) {
      final double x = dx + (p.dx - minX) * scale;
      final double y = dy + (p.dy - minY) * scale;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = PdlMetrics.segmentBar / 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      !identical(old.line, line) || old.color != color;
}
