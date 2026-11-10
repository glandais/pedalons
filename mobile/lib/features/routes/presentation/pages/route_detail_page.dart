import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../core/widgets/detail_stat_tiles.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/elevation_refresh.dart';
import '../../domain/track_surfaces.dart';
import '../../providers/route_detail_provider.dart';
import '../../providers/route_editor_providers.dart';
import '../widgets/route_climbs_section.dart';
import '../widgets/route_cursor_controller.dart';
import '../widgets/route_manage_menu.dart';
import '../widgets/route_section.dart';
import '../widgets/route_usages_section.dart';
import '../widgets/route_waypoints_section.dart';
import '../widgets/waypoint_selection.dart';

/// L'écran 13 — la fiche parcours, **une page qui défile** (ledger `MOB-134`,
/// lot 10, maquette `parcours-mobile-cible`, KIT §8) : plus de carte plein
/// écran sous une feuille à crans, l'ossature commune des écrans de détail.
///
/// Dans l'ordre : l'identité (équipe, titre, badges, tags), les tuiles
/// Distance | Dénivelé positif, la section Parcours ([RouteSection] : carte,
/// Pente | Revêtement, profil, revêtement, « GPS »), « Description », « Points
/// du parcours », « Cols et montées », « Utilisée dans », « Informations »
/// (« Créé le 3 novembre 2026 »), « Commentaires ».
///
/// Hors maquette et gardés : le crayon et le menu d'organisateur, le
/// signalement, le bandeau d'un parcours supprimé, la relecture tant que le
/// profil ou le revêtement se calculent, le tirer-pour-rafraîchir.
class RouteDetailPage extends ConsumerStatefulWidget {
  const RouteDetailPage({
    super.key,
    required this.teamSlug,
    required this.routeSlug,
  });

  final String teamSlug;
  final String routeSlug;

  @override
  ConsumerState<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends ConsumerState<RouteDetailPage> {
  /// Le réticule, partagé par la carte, le profil et les montées : toucher
  /// une montée l'y amène.
  RouteCursorController? _cursor;
  String? _cursorForSlug;

  /// Le point de parcours choisi, partagé par la carte, le profil et la liste
  /// (ledger `MOB-84`).
  final WaypointSelectionController _selection = WaypointSelectionController();

  /// La carte de la section Parcours : la liste des points la remonte à
  /// l'écran avant d'y centrer un point.
  final GlobalKey _mapAnchor = GlobalKey();

  RouteKey get _key =>
      RouteKey(teamSlug: widget.teamSlug, routeSlug: widget.routeSlug);

  /// Redemande le parcours tant que son profil est l'altitude rapide
  /// (`elevationState` `PENDING`, ledger `MOB-76`) ou que son revêtement se
  /// calcule : la fiche passe d'elle-même au profil HD.
  late final ElevationRefreshPoller _elevationPoller = ElevationRefreshPoller(
    refresh: () => ref.invalidate(routeDetailProvider(_key)),
  );

  @override
  void initState() {
    super.initState();
    // Un rechargement garde la valeur précédente : le minuteur ne s'arrête
    // pas pendant l'aller-retour.
    ref.listenManual<AsyncValue<RouteDetailDto>>(
      routeDetailProvider(_key),
      (AsyncValue<RouteDetailDto>? _, AsyncValue<RouteDetailDto> next) =>
          _elevationPoller.updatePending(
            isElevationPending(next.value?.elevationState) ||
                trackSurfacesPending(next.value?.tracks ?? const <TrackDto>[]),
          ),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _elevationPoller.dispose();
    _cursor?.dispose();
    _selection.dispose();
    super.dispose();
  }

  /// Le réticule est indexé sur la géométrie : il n'est reconstruit que si le
  /// parcours change, jamais à chaque `build`.
  RouteCursorController _cursorFor(RouteDetailDto route) {
    if (_cursor != null && _cursorForSlug == route.slug) return _cursor!;
    _cursor?.dispose();
    _cursorForSlug = route.slug;
    return _cursor = RouteCursorController(
      lines: <List<List<double>>>[
        for (final TrackDto t in route.tracks) t.line.coordinates,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RouteDetailDto> detail = ref.watch(
      routeDetailProvider(_key),
    );

    return detail.when(data: _content, loading: _loading, error: _error);
  }

  // ── Écran chargé ────────────────────────────────────────────────────────
  Widget _content(RouteDetailDto route) {
    final RouteCursorController cursor = _cursorFor(route);
    final UnitSystem units = ref.watch(unitSystemProvider);
    final bool? isMember = ref.watch(teamMembershipProvider(route.team.slug));
    final List<ClimbDto> climbs = route.allClimbs;
    final bool hasDescription =
        route.media.markdown.trim().isNotEmpty ||
        route.media.assets.attachments.isNotEmpty;

    return PdlScreenScaffold(
      onRefresh: () async {
        ref.invalidate(routeUsagesProvider(_key));
        try {
          ref.invalidate(routeDetailProvider(_key));
          await ref.read(routeDetailProvider(_key).future);
        } catch (_) {}
      },
      appBar: PdlAppBar(
        // Pas de titre : le corps le porte, juste dessous (comme la sortie et
        // le voyage).
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
        actions: _actions(route),
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(child: _identity(route)),
        if (route.deleted)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                0,
                PdlSpacing.section,
                PdlSpacing.section,
              ),
              child: PdlBanner(
                key: keys.routeManage.deletedBanner,
                tone: PdlBannerTone.warn,
                icon: PdlIcons.delete,
                message: 'routes.manage.deletedBanner'.tr(),
              ),
            ),
          ),
        // Distance | Dénivelé positif, sur une seule ligne : un parcours n'a
        // ni durée ni vitesse (KIT §8).
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          sliver: SliverToBoxAdapter(
            child: DetailStatTiles(
              key: keys.routeDetail.statTiles,
              tiles: <DetailStatTile>[
                DetailStatTile(
                  label: 'routes.distance'.tr(),
                  value: AppFormatters.formatDistance(route.distance, units),
                ),
                DetailStatTile(
                  label: 'units.elevationGainLong'.tr(),
                  value: AppFormatters.formatElevation(
                    route.elevationGain,
                    units,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: RouteSection(
            key: keys.routeDetail.routeSection,
            routeKey: _key,
            selection: _selection,
            cursor: cursor,
            mapKey: _mapAnchor,
          ),
        ),
        if (hasDescription)
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.routeDetail.descriptionSection,
              child: _description(route),
            ),
          ),
        if (route.hasGeometry && route.waypoints.isNotEmpty)
          SliverToBoxAdapter(
            child: DetailSection(
              key: keys.routeDetail.waypointsSection,
              title: 'routes.waypoints.title'.tr(),
              count: 'routes.waypoints.count'.plural(route.waypoints.length),
              // Dépliés : c'est la page du parcours.
              child: RouteWaypointsSection(
                waypoints: route.waypoints,
                selection: _selection,
                showHeader: false,
                onSelect: (String key, WaypointDto _) => _focusFromList(key),
              ),
            ),
          ),
        if (climbs.isNotEmpty)
          SliverToBoxAdapter(
            child: DetailSection(
              key: keys.routeDetail.climbsSection,
              title: 'routes.climbsTitle'.tr(),
              count: 'routes.climbCount'.plural(climbs.length),
              child: RouteClimbsSection(
                climbs: climbs,
                showHeader: false,
                // Taper une montée y amène le réticule : le lien entre la
                // liste, le profil et la carte est toujours une distance.
                onTapClimb: (ClimbDto c) =>
                    cursor.moveTo(c.startDistance.toDouble()),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.routeDetail.usagesSection,
            child: RouteUsagesSection(routeKey: _key),
          ),
        ),
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.routeDetail.informationSection,
            child: _information(route),
          ),
        ),
        // `commentCount` absent : la personne ne peut pas lire les
        // commentaires de ce parcours — le fil n'est pas monté du tout.
        if (route.commentCount != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.detailSectionGap,
              PdlSpacing.section,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: KeyedSubtree(
                key: keys.routeDetail.commentsSection,
                child: CommentThread(
                  target: CommentTarget(
                    entity: CommentEntity.route,
                    teamSlug: route.team.slug,
                    slug: route.slug,
                  ),
                  canComment: isMember ?? false,
                  countAtEnd: true,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  /// Le partage, pour tout le monde ; un organisateur a en plus le crayon et
  /// le `⋯` qui porte tous ses gestes (ledger `MOB-79`) ; sinon le `⋯` de la
  /// modération — mais son propre parcours ne se signale pas : le menu serait
  /// vide.
  List<Widget> _actions(RouteDetailDto route) {
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    final bool canManage =
        ref.watch(canManageRoutesProvider(route.team.slug)) ?? false;
    final bool canReport =
        currentUserId != null && currentUserId != route.createdBy?.id;

    return <Widget>[
      // `Builder` : la feuille de partage s'ancre au bouton (iPad).
      Builder(
        builder: (BuildContext buttonContext) => PdlAppBarAction(
          key: keys.routeDetail.shareButton,
          icon: PdlIcons.share,
          semanticLabel: 'routes.share'.tr(),
          onPressed: () => shareAppLink(
            buttonContext,
            title: route.name,
            path: Paths.route(route.team.slug, route.slug),
          ),
        ),
      ),
      if (canManage && !route.deleted)
        PdlAppBarAction(
          key: keys.routeManage.editButton,
          icon: PdlIcons.edit,
          semanticLabel: 'routes.manage.edit'.tr(),
          onPressed: () =>
              context.push(Paths.routeEdit(route.team.slug, route.slug)),
        ),
      if (canManage)
        PdlAppBarAction(
          key: keys.routeDetail.moreButton,
          icon: PdlIcons.more,
          semanticLabel: 'routes.manage.menuTitle'.tr(),
          onPressed: () =>
              showRouteManageMenu(context, ref, route, canReport: canReport),
        )
      else if (canReport)
        PdlAppBarAction(
          key: keys.routeDetail.moreButton,
          icon: PdlIcons.more,
          semanticLabel: 'moderation.more'.tr(),
          onPressed: () => showDetailModerationMenu(
            context,
            subject: ModerationSubject(
              teamSlug: route.team.slug,
              type: ReportTargetType.route,
              id: route.id,
              teamName: route.team.name,
            ),
          ),
        ),
    ];
  }

  // ── Identité ────────────────────────────────────────────────────────────
  /// La ligne d'équipe, le titre, le revêtement et la visibilité, les tags.
  Widget _identity(RouteDetailDto route) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: const EdgeInsets.all(PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PdlTeamLine(
            label: route.team.name,
            imageUrl: route.team.logoUrl,
            onTap: () => pushLocation(context, Paths.team(route.team.slug)),
          ),
          const SizedBox(height: 2),
          Text(route.name, key: keys.routeDetail.title, style: t.screenTitle),
          const SizedBox(height: PdlSpacing.chipGap),
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
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
          if (route.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            ContentTagRow(tags: route.tags),
          ],
        ],
      ),
    );
  }

  IconData _visibilityIcon(String visibility) => switch (visibility) {
    'PUBLIC' => PdlIcons.visibilityPublic,
    'PUBLIC_UNLISTED' => PdlIcons.visibilityUnlisted,
    _ => PdlIcons.visibilityTeam,
  };

  /// Toucher une ligne de la liste : la carte revient à l'écran, puis se
  /// centre sur le point — sans quoi le recentrage aurait lieu hors de vue.
  Future<void> _focusFromList(String key) async {
    final BuildContext? map = _mapAnchor.currentContext;
    if (map != null) {
      await Scrollable.ensureVisible(
        map,
        duration: PdlMotion.stateChange,
        curve: PdlMotion.stateChangeCurve,
      );
      if (!mounted) return;
    }
    _selection.select(key, move: PdlWaypointMove.center);
  }

  // ── Description ─────────────────────────────────────────────────────────
  /// « Description » : le texte puis les pièces jointes — un parcours peut
  /// porter un road book sans une ligne de texte.
  Widget _description(RouteDetailDto route) {
    return DetailSection(
      title: 'routes.description'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (route.media.markdown.trim().isNotEmpty)
            MarkdownContent(
              data: route.media.markdown,
              images: route.media.assets.images,
            ),
          MediaAttachments(attachments: route.media.assets.attachments),
        ],
      ),
    );
  }

  // ── Informations ────────────────────────────────────────────────────────
  /// « Par », « Créé le 3 novembre 2026 » (date longue sans jour de la
  /// semaine, dans le fuseau d'affichage : un horodatage), « Équipe
  /// propriétaire ».
  Widget _information(RouteDetailDto route) {
    final PdlColors c = context.pdl;
    final DateTime? createdAt = AppFormatters.tryParseDisplayTime(
      route.createdAt,
    );

    return DetailSection(
      title: 'routes.information'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Null pour qui n'est pas membre de l'équipe : on n'affiche rien
          // (ledger `API-144`).
          if (route.createdBy != null)
            PdlInfoLine(
              label: 'routes.author'.tr(),
              value: route.createdBy!.displayName,
            ),
          if (createdAt != null)
            PdlInfoLine(
              label: 'routes.createdOn'.tr(),
              value: AppFormatters.formatLongDateWithoutWeekday(createdAt),
            ),
          PdlInfoLine(
            label: 'routes.ownerTeam'.tr(),
            showDivider: false,
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PdlAvatar(
                  name: route.team.name,
                  imageUrl: route.team.logoUrl,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    route.team.name,
                    style: context.pdlText.body.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chargement et erreurs ───────────────────────────────────────────────
  /// Le squelette annonce la forme de la page plutôt que de faire tourner un
  /// rond : identité, tuiles, carte, profil.
  Widget _loading() {
    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PdlSpacing.section),
        children: const <Widget>[
          PdlSkeleton(height: 12, width: 120),
          SizedBox(height: PdlSpacing.chipGap),
          PdlSkeleton(height: 20, width: 220),
          SizedBox(height: 14),
          PdlSkeleton(height: 64),
          SizedBox(height: 14),
          PdlSkeleton(height: PdlMetrics.detailMapMin),
          SizedBox(height: 14),
          PdlSkeleton(height: PdlMetrics.detailElevation),
        ],
      ),
    );
  }

  Widget _error(Object error, StackTrace stack) {
    final ApiError resolved = resolveApiError(error, stack);
    final bool notFound = resolved.code == 'NOT_FOUND';

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: Center(
        child: PdlEmptyState(
          variant: notFound ? PdlEmptyVariant.notFound : PdlEmptyVariant.error,
          icon: notFound
              ? PdlIcons.route
              : (resolved.isOffline ? PdlIcons.offline : null),
          title: notFound
              ? 'routes.notFoundTitle'.tr()
              : (resolved.title ?? 'routes.loadErrorTitle'.tr()),
          message: notFound ? 'routes.notFoundMessage'.tr() : resolved.message,
          actions: <Widget>[
            if (notFound)
              PdlButton(
                label: 'routes.backToRoutes'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: () => context.pop(),
              )
            else
              PdlButton(
                label: 'common.retry'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: () => ref.invalidate(routeDetailProvider(_key)),
              ),
            ReportProblemButton(error: error, stackTrace: stack),
          ],
        ),
      ),
    );
  }
}
