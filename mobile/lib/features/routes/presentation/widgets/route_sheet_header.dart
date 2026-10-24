import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/push_location.dart';

/// En dessous de ce cran, l'en-tête bascule en composition compacte.
const double kRouteSheetCompactBelow = 0.34;

/// L'en-tête de la feuille de la fiche parcours, en **deux compositions**.
///
/// Au cran bas (0.18), la feuille ne montre qu'une bande : titre en 16 px,
/// badge de revêtement seul, trois statistiques compactes. Au-delà, elle
/// déploie le titre 20 px, la pile de badges et les trois statistiques en
/// grande taille.
///
/// Les deux compositions sont **isolées dans ce widget**, et lui seul est
/// reconstruit par le `ValueListenableBuilder` de la feuille : englober le
/// corps ferait repeindre le profil altimétrique à chaque pixel de glissement.
class RouteSheetHeader extends ConsumerWidget {
  const RouteSheetHeader({
    super.key,
    required this.route,
    required this.extent,
  });

  final RouteDetailDto route;

  /// La fraction de hauteur occupée par la feuille, entre `minChildSize` et
  /// `maxChildSize`.
  final double extent;

  bool get _compact => extent < kRouteSheetCompactBelow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: _compact
          ? _compactBody(context, units)
          : _fullBody(context, units),
    );
  }

  // ── Cran 0.18 ───────────────────────────────────────────────────────────
  Widget _compactBody(BuildContext context, UnitSystem units) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                route.name,
                style: t.cardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            PdlBadge(
              label: AppFormatters.surfaceName(route.surfaceType),
              tone: SurfaceType.fromJson(route.surfaceType).tone(c),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PdlStatRow(stats: _stats(units, big: false), nowrap: true),
      ],
    );
  }

  // ── Crans 0.5 et 0.92 ───────────────────────────────────────────────────
  Widget _fullBody(BuildContext context, UnitSystem units) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // L'équipe au-dessus du titre, comme sur les autres détails (ledger
        // `MOB-90`) ; la bande du cran bas ne la porte pas.
        PdlTeamLine(
          label: route.team.name,
          imageUrl: route.team.logoUrl,
          onTap: () => pushLocation(context, Paths.team(route.team.slug)),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                route.name,
                style: t.screenTitle.copyWith(fontSize: 20),
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            PdlBadgeStack(
              badges: <Widget>[
                PdlBadge(
                  label: AppFormatters.surfaceName(route.surfaceType),
                  tone: SurfaceType.fromJson(route.surfaceType).tone(c),
                ),
                PdlBadge(
                  label: 'visibility.${route.visibility.toLowerCase()}'.tr(),
                  tone: Visibility.fromJson(route.visibility).tone(c),
                  icon: _visibilityIcon(route.visibility),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _stats(units, big: true),
        ),
      ],
    );
  }

  /// Distance · D+ (vert) · D− (rouge, **affiché négatif**).
  ///
  /// Le serveur rend `elevationLoss` **négatif** (toutes les lignes en base) ;
  /// on affiche sa valeur absolue derrière notre propre « − », sans quoi il
  /// sortait « −-1108 m ». `abs()` tient aussi si le signe change un jour.
  List<PdlStat> _stats(UnitSystem units, {required bool big}) => <PdlStat>[
    PdlStat(
      value: AppFormatters.formatDistance(route.distance, units),
      icon: PdlIcons.distance,
      label: big ? 'routes.distance'.tr() : null,
      big: big,
    ),
    PdlStat(
      value: AppFormatters.formatElevation(route.elevationGain, units),
      icon: PdlIcons.elevationUp,
      label: big ? 'units.elevationGainLong'.tr() : null,
      big: big,
      trend: PdlStatTrend.up,
    ),
    PdlStat(
      value:
          '−${AppFormatters.formatElevation(route.elevationLoss.abs(), units)}',
      icon: PdlIcons.elevationDown,
      label: big ? 'units.elevationLossLong'.tr() : null,
      big: big,
      trend: PdlStatTrend.down,
    ),
  ];

  IconData _visibilityIcon(String visibility) => switch (visibility) {
    'PUBLIC' => PdlIcons.visibilityPublic,
    'PUBLIC_UNLISTED' => PdlIcons.visibilityUnlisted,
    _ => PdlIcons.visibilityTeam,
  };
}
