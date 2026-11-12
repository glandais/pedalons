import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../../tags/presentation/content_tags.dart';
import 'route_card.dart';

/// La densité « compact » de la parcothèque — une ligne de 100 px : vignette
/// 80, nom, deux chiffres, deux badges, chevron.
///
/// Elle prend le pas d'office au-delà de [kRouteCompactThreshold] résultats
/// (§3.1) : à 2 585 parcours, une carte de 300 px par entrée transforme la
/// recherche d'un nom connu en quarante écrans de défilement.
class CompactRouteRow extends ConsumerWidget {
  const CompactRouteRow({super.key, required this.route, this.onTap});

  final RouteDto route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);

    return PdlCard(
      key: keys.routes.card(route.slug),
      padding: PdlCardPadding.tight,
      onTap:
          onTap ?? () => context.push(Paths.route(route.team.slug, route.slug)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // `PdlThumb` fait lui-même le choix clair/sombre sur le thème de
          // l'app — F-TH-8, et non la luminosité de la plateforme.
          PdlThumb(
            imageUrl:
                route.media.assets.thumbnailLight?.url ?? route.thumbnailUrl,
            darkImageUrl: route.media.assets.thumbnailDark?.url,
            size: PdlMetrics.thumbLg,
            fallbackIcon: PdlIcons.route,
          ),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.text),
                ),
                const SizedBox(height: 4),
                PdlStatRow(stats: routeStats(route, units)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: PdlSpacing.badgeGap,
                  runSpacing: PdlSpacing.badgeGap,
                  children: routeBadges(context, route),
                ),
                // Deux et non trois : la ligne compacte est faite pour
                // retrouver un nom, pas pour lire le contenu.
                if (route.tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  ContentTagRow(
                    key: keys.routes.cardTags(route.slug),
                    tags: route.tags,
                    maxVisible: 2,
                  ),
                ],
              ],
            ),
          ),
          Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
        ],
      ),
    );
  }
}
