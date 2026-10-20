import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/units/unit_system.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../providers/route_detail_provider.dart';
import '../../domain/elevation_refresh.dart';
import '../../domain/track_surfaces.dart';
import '../../providers/route_editor_providers.dart';
import '../../providers/route_elevation_provider.dart';
import '../widgets/route_climbs_section.dart';
import '../widgets/route_cursor_controller.dart';
import '../widgets/route_download_actions.dart';
import '../widgets/route_manage_menu.dart';
import '../widgets/route_map.dart';
import '../widgets/route_sheet_header.dart';
import '../widgets/route_surface_section.dart';
import '../widgets/route_usages_section.dart';
import '../../../feedback/presentation/report_problem_button.dart';

/// L'écran 13 — fiche parcours.
///
/// **Restructuré, pas réécrit** : le motif `Stack` = carte plein écran +
/// feuille glissante est le meilleur socle de l'application, et il est
/// conservé. Ce qui change :
///
/// * les crans passent de `0.15 / 0.1 / 0.7` à `[0.18, 0.5, 0.92]` — l'ancien
///   plafond de 0,7 laissait 800 px de vide sous le contenu ;
/// * la pastille de titre passe de 80 % à opaque (F-DE-2) ;
/// * le tracé est colorisé par pente et porte un réticule synchronisé ;
/// * s'ajoutent les cols, les usages, les informations et la barre d'actions.
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

/// Les crans de la feuille, partagés entre elle et le cadrage de la carte.
const List<double> _kDetents = <double>[0.18, 0.5, 0.92];
const int _kInitialDetent = 1;

class _RouteDetailPageState extends ConsumerState<RouteDetailPage> {
  RouteCursorController? _cursor;
  String? _cursorForSlug;

  /// Le cran courant de la feuille. Il pilote la marge basse du cadrage : sans
  /// elle, le tracé est cadré sur toute la hauteur de la carte, dont la feuille
  /// couvre la moitié. Alimenté par `onDetentChanged`, donc **au franchissement
  /// de cran** et jamais en continu : la caméra ne bouge pas sous le doigt.
  double _detent = _kDetents[_kInitialDetent];

  /// Ce que la pente / le revêtement colorent (`MOB-81`) ; retombe sur la pente
  /// si le revêtement disparaît au rechargement.
  RouteColorBy _colorBy = RouteColorBy.grade;

  final TrackSurfaceBarColors _barColors = TrackSurfaceBarColors();

  RouteKey get _key =>
      RouteKey(teamSlug: widget.teamSlug, routeSlug: widget.routeSlug);

  /// Redemande le parcours tant que son profil est l'altitude rapide
  /// (`elevationState` `PENDING`, ledger `MOB-76`) : la fiche passe d'elle-même
  /// au profil HD quand le serveur l'a recalculé.
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
    final RouteColorBy colorBy = hasTrackSurfaces(route.tracks)
        ? _colorBy
        : RouteColorBy.grade;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // La carte occupe tout le fond : elle se manipule librement.
          // `PdlMapHero` accorde la barre système au thème.
          Positioned.fill(
            child: RouteMap(
              route: route,
              cursor: cursor,
              onMapTapped: cursor.moveTo,
              colorBy: colorBy,
              fitPadding: EdgeInsets.fromLTRB(
                50,
                50,
                50,
                MediaQuery.sizeOf(context).height * _detent,
              ),
            ),
          ),
          _overlay(route),
          PdlDetentSheet(
            detents: _kDetents,
            initialDetentIndex: _kInitialDetent,
            onDetentChanged: (double detent) {
              if (detent != _detent) setState(() => _detent = detent);
            },
            headerBuilder: (BuildContext context, double extent) =>
                RouteSheetHeader(route: route, extent: extent),
            footer: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  PdlSpacing.chipGap,
                ),
                child: RouteDownloadActions(route: route),
              ),
            ),
            bodyBuilder:
                (
                  BuildContext context,
                  ScrollController controller,
                  double footerInset,
                ) =>
                    _sheetBody(route, cursor, controller, footerInset, colorBy),
          ),
        ],
      ),
    );
  }

  /// L'overlay haut : retour et pastille de titre, **tous deux opaques**.
  ///
  /// F-DE-2 : `surface.withValues(alpha: 0.8)` laissait passer la tuile, et le
  /// nom devenait illisible sur du satellite ou une zone urbaine dense.
  /// `PdlMapButton` et `PdlMapPill` portent `overlaySolid` — 95 % — plus un
  /// flou.
  Widget _overlay(RouteDetailDto route) {
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    final bool canManage =
        ref.watch(canManageRoutesProvider(route.team.slug)) ?? false;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: <Widget>[
              PdlMapButton(
                icon: PdlIcons.back,
                semanticLabel: 'common.back'.tr(),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              Expanded(
                child: PdlMapPill(
                  key: keys.routeDetail.title,
                  label: route.name,
                ),
              ),
              // Un organisateur : partager, modifier (le crayon), puis le `⋯` qui
              // porte tous ses gestes (ledger `MOB-79`). Le pied de la fiche
              // garde son propre partage.
              if (canManage) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                // `Builder` : la feuille de partage s'ancre au bouton (iPad).
                Builder(
                  builder: (BuildContext buttonContext) => PdlMapButton(
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
              ],
              if (canManage && !route.deleted) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                PdlMapButton(
                  key: keys.routeManage.editButton,
                  icon: PdlIcons.edit,
                  semanticLabel: 'routes.manage.edit'.tr(),
                  onPressed: () => context.push(
                    Paths.routeEdit(route.team.slug, route.slug),
                  ),
                ),
              ],
              if (canManage) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                PdlMapButton(
                  key: keys.routeDetail.moreButton,
                  icon: PdlIcons.more,
                  semanticLabel: 'routes.manage.menuTitle'.tr(),
                  onPressed: () => showRouteManageMenu(
                    context,
                    ref,
                    route,
                    canReport:
                        currentUserId != null &&
                        currentUserId != route.createdBy.id,
                  ),
                ),
              ]
              // Sinon, la modération — mais son propre parcours ne se signale
              // pas : le menu serait vide.
              else if (currentUserId != null &&
                  currentUserId != route.createdBy.id) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                PdlMapButton(
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetBody(
    RouteDetailDto route,
    RouteCursorController cursor,
    ScrollController controller,
    double footerInset,
    RouteColorBy colorBy,
  ) {
    final List<ClimbDto> climbs = route.allClimbs;

    return ListView(
      controller: controller,
      padding: EdgeInsets.only(bottom: footerInset),
      children: <Widget>[
        if (route.deleted)
          Padding(
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
        // Les tags en tête du corps et non dans l'en-tête de la feuille : à
        // son cran bas, l'en-tête ne garde que le nom et un badge (ledger
        // `MOB-39`).
        if (route.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ContentTagRow(tags: route.tags),
          ),
        if (route.hasGeometry)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _profile(route, cursor, colorBy),
          )
        else
          PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            icon: PdlIcons.route,
            title: 'routes.noTrackTitle'.tr(),
            message: 'routes.noTrackMessage'.tr(),
          ),
        // Le gabarit de 16 px n'est posé que si la section rend quelque chose :
        // la plupart des parcours n'ont pas (encore) de revêtement.
        if (route.hasGeometry &&
            (hasTrackSurfaces(route.tracks) ||
                trackSurfacesPending(route.tracks)))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: RouteSurfaceSection(
              tracks: route.tracks,
              colorBy: colorBy,
              onColorByChanged: (RouteColorBy v) =>
                  setState(() => _colorBy = v),
            ),
          ),
        if (climbs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: RouteClimbsSection(
              climbs: climbs,
              // Taper une montée y amène le réticule : le lien entre la liste,
              // le profil et la carte est toujours une distance cumulée.
              onTapClimb: (ClimbDto c) =>
                  cursor.moveTo(c.startDistance.toDouble()),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: RouteUsagesSection(routeKey: _key),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _information(route),
        ),
        if (route.media.markdown.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PdlSectionHeader(title: 'routes.description'.tr()),
                MarkdownContent(
                  data: route.media.markdown,
                  images: route.media.assets.images,
                ),
              ],
            ),
          ),
        // Section à part, et non un appendice de la description : un parcours
        // peut porter un road book sans une ligne de texte.
        if (route.media.assets.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MediaAttachments(
              attachments: route.media.assets.attachments,
              spacingBefore: 0,
            ),
          ),
      ],
    );
  }

  Widget _profile(
    RouteDetailDto route,
    RouteCursorController cursor,
    RouteColorBy colorBy,
  ) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    final List<TrackSurface?>? bars = colorBy == RouteColorBy.surface
        ? ref.watch(routeSurfaceBarsProvider(_key)).value
        : null;

    return ref
        .watch(routeElevationSamplesProvider(_key))
        .when(
          // Pas d'altitude exploitable : rien, plutôt qu'un profil plat qui
          // se ferait passer pour un terrain.
          data: (ElevationSamples? samples) => samples == null
              ? const SizedBox.shrink()
              : _withRefiningNote(
                  route,
                  PdlElevationProfile(
                    credit: 'routes.elevationCredit'.tr(),
                    key: keys.routeDetail.elevationProfile,
                    samples: samples,
                    height: PdlMetrics.elevationLarge,
                    // Le **seul** état partagé avec la carte, et il ne passe pas
                    // par Riverpod : le réticule bouge à chaque frame de
                    // glissement.
                    barColors: bars == null
                        ? null
                        : _barColors.of(bars, context.pdl),
                    cursorDistance: cursor.distance,
                    axisLabel: (double meters, {required bool isLast}) => isLast
                        ? AppFormatters.formatDistance(meters, units)
                        : AppFormatters.formatNumber(
                            units.longDistance(meters),
                            fractionDigits: 1,
                          ),
                    tipLabel: (ElevationReading r) => <String>[
                      AppFormatters.formatDistance(r.distance, units),
                      AppFormatters.formatAltitude(r.elevation, units),
                      if (bars != null)
                        ?trackSurfaceTip(samples, bars, r.distance)
                      else if (r.grade != null)
                        AppFormatters.formatGrade(r.grade!),
                    ].join(' · '),
                  ),
                ),
          loading: () => PdlElevationProfile.loading(
            label: 'routes.profileLoading'.tr(),
            height: PdlMetrics.elevationLarge,
          ),
          error: (Object error, StackTrace stack) => PdlElevationProfile.failed(
            label: 'routes.profileUnavailable'.tr(),
            actionLabel: 'common.retry'.tr(),
            height: PdlMetrics.elevationLarge,
            onRetry: () => ref.invalidate(routeDetailProvider(_key)),
          ),
        );
  }

  /// Le profil, précédé de « Profil d'altitude provisoire » tant que c'est
  /// l'altitude rapide (`PENDING`) : comme au site, la mention se tait en
  /// `FAST` (le recalcul a été abandonné) et en `HD`.
  Widget _withRefiningNote(RouteDetailDto route, Widget profile) {
    if (!isElevationPending(route.elevationState)) return profile;
    return Column(
      key: keys.routeDetail.elevationRefining,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'routes.elevationRefining'.tr(),
          style: context.pdlText.xs.copyWith(color: context.pdl.textDimmed),
        ),
        const SizedBox(height: PdlSpacing.badgeGap),
        profile,
      ],
    );
  }

  Widget _information(RouteDetailDto route) {
    final PdlColors c = context.pdl;
    final DateTime? createdAt = AppFormatters.tryParseDisplayTime(
      route.createdAt,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'routes.information'.tr(),
          padding: const EdgeInsets.only(bottom: 4),
        ),
        // `createdBy` **existe au contrat et n'était pas lu** : cette section
        // l'active.
        PdlInfoLine(
          label: 'routes.author'.tr(),
          value: route.createdBy.displayName,
        ),
        if (createdAt != null)
          PdlInfoLine(
            label: 'routes.createdOn'.tr(),
            value: AppFormatters.formatLongDate(createdAt),
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
    );
  }

  // ── Chargement et erreurs ───────────────────────────────────────────────
  /// Chargement **progressif** : la feuille apparaît d'abord, le profil ensuite
  /// (§4.3 du brief). Ici la fiche entière attend le détail, mais le squelette
  /// en annonce la forme plutôt que de faire tourner un rond.
  Widget _loading() {
    return Scaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PdlSpacing.section),
        children: const <Widget>[
          PdlSkeleton(height: 20, width: 220),
          SizedBox(height: 14),
          PdlSkeleton(height: 48),
          SizedBox(height: 14),
          PdlSkeleton(height: PdlMetrics.elevationLarge),
        ],
      ),
    );
  }

  Widget _error(Object error, StackTrace stack) {
    final ApiError resolved = resolveApiError(error, stack);
    final bool notFound = resolved.code == 'NOT_FOUND';

    return Scaffold(
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
