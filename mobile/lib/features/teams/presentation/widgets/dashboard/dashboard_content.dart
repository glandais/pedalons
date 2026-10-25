import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../config/paths.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/enum_colors.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import 'dashboard_section.dart';

// ──────────────────────────────────────────────────── dernières publications

/// « Dernières publications » : titre, extrait, date, auteur, commentaires.
///
/// L'extrait vient d'`excerpt` : les lignes du tableau de bord sont compactes,
/// `media.markdown` y est vide.
class DashboardLatestPosts extends StatelessWidget {
  const DashboardLatestPosts({super.key, required this.list, this.onViewAll});

  final PublicationListResponse list;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final List<PublicationDtoPost> posts = list.publications
        .whereType<PublicationDtoPost>()
        .toList();

    return DashboardSection(
      key: keys.teamDashboard.latestPosts,
      title: 'teams.dashboard.latestPosts.title'.tr(),
      onViewAll: onViewAll,
      child: posts.isEmpty
          ? DashboardEmptyLine(
              message: 'teams.dashboard.latestPosts.empty'.tr(),
            )
          : DashboardCardColumn(
              children: <Widget>[
                for (final PublicationDtoPost p in posts) _PostRow(post: p),
              ],
            ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post});

  final PublicationDtoPost post;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    // La date d'une publication est un rendez-vous dans son fuseau, celui de
    // l'équipe (`PostDto.timezone`, docs/LEDGER_*.md API-60).
    final DateTime? at = AppFormatters.tryParseZoneTime(
      post.dateTime,
      post.timezone,
    );
    // Signée au nom de l'équipe, la publication n'a pas d'autre auteur à
    // montrer ; sinon c'est `createdBy`, qui est bien ici l'auteur.
    final String? author = post.signedAsTeam
        ? post.team.name
        : post.createdBy?.displayName;
    final List<String> meta = <String>[
      if (at != null) AppFormatters.formatDayMonth(at),
      ?author,
      if (post.commentCount != null && post.commentCount! > 0)
        'comments.count'.plural(post.commentCount!),
    ];

    return PdlCard(
      onTap: () => context.push(Paths.post(post.team.slug, post.slug)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  post.name,
                  style: t.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (post.excerpt != null &&
                    post.excerpt!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    post.excerpt!,
                    style: t.sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (meta.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.badgeGap),
                  Text(meta.join(' · '), style: t.xs),
                ],
              ],
            ),
          ),
          if (post.thumbnailUrl != null) ...<Widget>[
            const SizedBox(width: PdlSpacing.cardTight),
            PdlThumb(
              imageUrl: post.thumbnailUrl,
              size: PdlMetrics.thumbSm,
              fallbackIcon: PdlIcons.post,
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── nouveaux parcours

/// « Nouveaux parcours » : vignette, distance, dénivelé, revêtement.
class DashboardNewRoutes extends ConsumerWidget {
  const DashboardNewRoutes({super.key, required this.list, this.onViewAll});

  final RouteListResponse list;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);

    return DashboardSection(
      key: keys.teamDashboard.newRoutes,
      title: 'teams.dashboard.newRoutes.title'.tr(),
      onViewAll: onViewAll,
      child: list.routes.isEmpty
          ? DashboardEmptyLine(message: 'teams.dashboard.newRoutes.empty'.tr())
          : DashboardCardColumn(
              children: <Widget>[
                for (final RouteDto r in list.routes)
                  PdlCard(
                    onTap: () => context.push(Paths.route(r.team.slug, r.slug)),
                    child: Row(
                      children: <Widget>[
                        PdlThumb(
                          imageUrl: r.thumbnailUrl,
                          size: PdlMetrics.thumbSm,
                        ),
                        const SizedBox(width: PdlSpacing.cardTight),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                r.name,
                                style: t.cardTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: PdlSpacing.badgeGap),
                              Wrap(
                                spacing: PdlSpacing.chipGap,
                                runSpacing: PdlSpacing.badgeGap,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  PdlStat(
                                    value: AppFormatters.formatDistance(
                                      r.distance,
                                      units,
                                    ),
                                    icon: PdlIcons.distance,
                                  ),
                                  PdlStat(
                                    value: AppFormatters.formatElevation(
                                      r.elevationGain,
                                      units,
                                    ),
                                    icon: PdlIcons.elevationUp,
                                    trend: PdlStatTrend.up,
                                  ),
                                  PdlBadge(
                                    label: AppFormatters.surfaceName(
                                      r.surfaceType,
                                    ),
                                    tone: SurfaceType.fromJson(r.surfaceType)
                                        .tone(c),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ────────────────────────────────────────────────────────────────── annonces

/// « Annonces » : type, prix — « Prix à négocier » quand il n'y en a pas —,
/// titre et **secteur**.
///
/// Le lieu d'une annonce est flouté au kilomètre : il se dit en texte
/// (`locationDescription`), jamais par une épingle ni même une icône
/// d'épingle, qui prétendrait une précision que la donnée n'a pas.
class DashboardLatestAds extends StatelessWidget {
  const DashboardLatestAds({super.key, required this.list, this.onViewAll});

  final AdListResponse list;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return DashboardSection(
      key: keys.teamDashboard.latestAds,
      title: 'teams.dashboard.latestAds.title'.tr(),
      onViewAll: onViewAll,
      child: list.ads.isEmpty
          ? DashboardEmptyLine(message: 'teams.dashboard.latestAds.empty'.tr())
          : DashboardCardColumn(
              children: <Widget>[
                for (final AdDto ad in list.ads)
                  Builder(
                    builder: (BuildContext context) {
                      final FormattedPrice price = AppFormatters.formatPrice(
                        ad.price,
                        rentalPeriod: ad.rentalPeriod,
                      );
                      final String? sector = ad.locationDescription;
                      return PdlCard(
                        onTap: () =>
                            context.push(Paths.ad(ad.team.slug, ad.slug)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                PdlBadge(
                                  label: 'ads.adType.${ad.adType}'.tr(),
                                  tone: AdType.fromJson(ad.adType).tone(c),
                                ),
                                const SizedBox(width: PdlSpacing.chipGap),
                                Expanded(
                                  child: Text(
                                    price.period == null
                                        ? price.amount
                                        : '${price.amount} ${price.period}',
                                    textAlign: TextAlign.end,
                                    style: t.bodyStrong.copyWith(
                                      color: price.isNegotiable
                                          ? c.textDimmed
                                          : c.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: PdlSpacing.badgeGap),
                            Text(
                              ad.name,
                              style: t.cardTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (sector != null && sector.isNotEmpty)
                              Text(
                                'teams.dashboard.latestAds.sector'.tr(
                                  namedArgs: <String, String>{'place': sector},
                                ),
                                style: t.xs,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
