import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/deleted_badge.dart';
import '../../../../core/widgets/team_banner.dart';
import '../../../../keys.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../../visibility/presentation/visibility_badge.dart';

/// La densité « vignettes » de la parcothèque — un bandeau média de 208 px,
/// l'équipe, le nom, son extrait sur deux lignes, deux chiffres, deux badges.
///
/// C'est la densité par défaut sous [kRouteCompactThreshold] résultats : quand
/// on parcourt, la miniature du tracé en dit plus qu'un nom.
///
/// **`hilliness` n'est volontairement pas rendu ici** : `RouteDto` ne le porte
/// pas (§3.1, « Limites »). C'est un filtre serveur sans restitution possible,
/// et afficher un relief déduit de la pente moyenne serait inventer une donnée.
class RouteCard extends ConsumerWidget {
  const RouteCard({super.key, required this.route, this.onTap});

  final RouteDto route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final String? thumbnail =
        (dark
            ? route.media.assets.thumbnailDark?.url
            : route.media.assets.thumbnailLight?.url) ??
        route.thumbnailUrl;

    return PdlCard(
      key: keys.routes.card(route.slug),
      padding: PdlCardPadding.none,
      onTap: onTap ?? () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Hero(
            tag: 'route-thumbnail-${route.slug}',
            child: PdlCardMedia(
              tone: PdlMediaTone.ride,
              icon: PdlIcons.route,
              imageUrl: thumbnail,
              height: PdlMetrics.media16x9,
              borderRadius: const BorderRadius.vertical(top: PdlRadii.card),
              semanticLabel: route.name,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(PdlSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Pas de logo : `TeamPublicationDto` n'en porte pas (§5.2-2),
                // et `PdlTeamLine` retombe alors sur son icône.
                PdlTeamLine(
                  label: route.team.name,
                  imageUrl: route.team.logoUrl,
                  onTap: teamLinkOf(context, route.team),
                ),
                const SizedBox(height: 4),
                Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.text),
                ),
                // L'extrait sur deux lignes, sous le nom (règle R12, KIT §9,
                // BRANDING §7.2) ; pas sur la ligne compacte.
                if (route.excerpt case final String excerpt
                    when excerpt.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    excerpt.trim(),
                    key: keys.routes.cardExcerpt(route.slug),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.sub,
                  ),
                ],
                const SizedBox(height: 8),
                PdlStatRow(stats: routeStats(route, units)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: PdlSpacing.badgeGap,
                  runSpacing: PdlSpacing.badgeGap,
                  children: routeBadges(context, route),
                ),
                if (route.tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ContentTagRow(
                    key: keys.routes.cardTags(route.slug),
                    tags: route.tags,
                    maxVisible: kCardTagLimit,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context) =>
      context.push(Paths.route(route.team.slug, route.slug));
}

/// Les deux chiffres d'un parcours, dans le système d'unités de
/// l'utilisateur. Partagés par les deux densités et par la carte flottante de
/// la vue Carte, pour qu'un même parcours ne s'écrive jamais de deux façons.
List<PdlStat> routeStats(RouteDto route, UnitSystem units) => <PdlStat>[
  PdlStat(
    icon: PdlIcons.distance,
    value: AppFormatters.formatDistance(route.distance, units),
  ),
  PdlStat(
    icon: PdlIcons.elevationUp,
    value: AppFormatters.formatElevation(route.elevationGain, units),
  ),
];

/// Revêtement puis visibilité, dans l'ordre du §1.2 (type → statut →
/// visibilité) — précédés du badge « Supprimé » quand il y a lieu. La
/// visibilité seulement quand elle diffère de celle de l'équipe (règle R1,
/// KIT §9) : un parcours public d'une équipe privée la porte, un parcours
/// « Équipe uniquement » de la même équipe non.
List<Widget> routeBadges(BuildContext context, RouteDto route) {
  final SurfaceType surface = SurfaceType.fromJson(route.surfaceType);
  return <Widget>[
    ...deletedBadgeFirst(route.deleted),
    PdlBadge(
      label: 'routes.surfaceType.${route.surfaceType.toLowerCase()}'.tr(),
      tone: surface.tone(context.pdl),
    ),
    ...cardVisibilityBadges(
      route.visibility,
      reference: route.team.visibility,
      key: keys.routes.cardVisibility(route.slug),
    ),
  ];
}
