import 'package:easy_localization/easy_localization.dart';
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
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../core/widgets/detail_stat_tiles.dart';
import '../../../../keys.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../routes/domain/elevation_refresh.dart';
import '../../../routes/domain/track_key.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/widgets/route_cursor_controller.dart';
import '../../../routes/presentation/widgets/route_section.dart';
import '../../../routes/presentation/widgets/route_waypoints_section.dart';
import '../../../routes/presentation/widgets/waypoint_selection.dart';
import '../../data/gpx_preview_repository.dart';
import '../../domain/weather_arrival.dart';
import '../../providers/gpx_preview_provider.dart';
import '../widgets/gpx_preview_departure.dart';
import '../widgets/gpx_preview_map_layer.dart';
import '../widgets/gpx_preview_weather.dart';

/// Les gestes du `⋯` d'un aperçu, dans l'ordre du menu.
enum GpxPreviewAction { delete }

/// Les gestes offerts sur [preview] : supprimer est réservé à la personne qui
/// l'a déposé (`owned`).
List<GpxPreviewAction> gpxPreviewActions(GpxPreviewDto preview) =>
    <GpxPreviewAction>[if (preview.owned) GpxPreviewAction.delete];

/// La fiche d'un aperçu GPX (docs/LEDGER_*.md MOB-178), l'ossature commune
/// des fiches (KIT §8, ledger `MOB-134`) : une page qui défile, sans barre
/// d'action.
///
/// Dans l'ordre : le titre, les tuiles Distance | Dénivelé positif, le bloc
/// de départ s'il est daté, la section Parcours ([RouteSection] sur
/// [GpxPreviewKey] : carte, Pente | Revêtement | Météo, profil, revêtement,
/// « GPS »), la Météo s'il est daté, les points du parcours, la mention de
/// conservation. La barre porte le partage et le `⋯`.
///
/// Le lien est public au site ; l'app demande une session pour tout, celui-ci
/// compris (décision D2 du plan) : le `redirect` du routeur s'en charge.
class GpxPreviewPage extends ConsumerStatefulWidget {
  const GpxPreviewPage({super.key, required this.previewId});

  final String previewId;

  @override
  ConsumerState<GpxPreviewPage> createState() => _GpxPreviewPageState();
}

class _GpxPreviewPageState extends ConsumerState<GpxPreviewPage> {
  RouteCursorController? _cursor;
  String? _cursorForId;
  final WaypointSelectionController _selection = WaypointSelectionController();
  final GlobalKey _mapAnchor = GlobalKey();

  /// Un geste du `⋯` en cours : un à la fois.
  bool _busy = false;
  Object? _actionError;

  GpxPreviewKey get _key => GpxPreviewKey(widget.previewId);

  /// Redemande l'aperçu tant que son profil est l'altitude rapide ou que son
  /// revêtement se calcule, comme la fiche d'un parcours (ledger `MOB-76`).
  late final ElevationRefreshPoller _elevationPoller = ElevationRefreshPoller(
    refresh: () => ref.invalidate(gpxPreviewProvider(widget.previewId)),
  );

  /// Redemande la météo tant qu'elle arrive, 3 minutes au plus.
  late final WeatherArrivalPoller _weatherPoller = WeatherArrivalPoller(
    refresh: () => ref.invalidate(gpxPreviewWeatherProvider(widget.previewId)),
    onGaveUp: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<GpxPreviewDto>>(
      gpxPreviewProvider(widget.previewId),
      (AsyncValue<GpxPreviewDto>? _, AsyncValue<GpxPreviewDto> next) =>
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
    _weatherPoller.dispose();
    _cursor?.dispose();
    _selection.dispose();
    super.dispose();
  }

  RouteCursorController _cursorFor(GpxPreviewDto preview) {
    if (_cursor != null && _cursorForId == preview.id) return _cursor!;
    _cursor?.dispose();
    _cursorForId = preview.id;
    return _cursor = RouteCursorController(
      lines: <List<List<double>>>[
        for (final TrackDto t in preview.tracks) t.line.coordinates,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(gpxPreviewProvider(widget.previewId))
        .when(data: _content, loading: _loading, error: _error);
  }

  // ── Écran chargé ────────────────────────────────────────────────────────
  Widget _content(GpxPreviewDto preview) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final RouteCursorController cursor = _cursorFor(preview);
    final bool dated = preview.departureTime != null;
    final AsyncValue<RideWeatherDto>? weather = dated
        ? ref.watch(gpxPreviewWeatherProvider(preview.id))
        : null;
    if (weather != null) _weatherPoller.update(weather.value?.status);
    final mode = watchGpxPreviewColorMode(ref, preview);
    final WeatherLegDto? offeredWind = watchGpxPreviewWindLeg(ref, preview);
    final bool hasWaypoints =
        preview.tracks.isNotEmpty && preview.waypoints.isNotEmpty;

    return PdlScreenScaffold(
      onRefresh: () async {
        try {
          ref.invalidate(gpxPreviewProvider(preview.id));
          if (dated) ref.invalidate(gpxPreviewWeatherProvider(preview.id));
          await ref.read(gpxPreviewProvider(preview.id).future);
        } catch (_) {}
      },
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
        actions: _actions(preview),
      ),
      slivers: <Widget>[
        SliverPadding(
          key: keys.gpxTools.preview,
          padding: const EdgeInsets.all(PdlSpacing.section),
          sliver: SliverList.list(
            children: <Widget>[
              Text(
                'gpxTools.preview.title'.tr(),
                style: t.xs.copyWith(color: c.textDimmed),
              ),
              const SizedBox(height: 2),
              Text(
                preview.name,
                key: keys.gpxTools.previewTitle,
                style: t.screenTitle,
              ),
              if (_actionError != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.chipGap),
                PdlBanner(
                  key: keys.gpxTools.actionError,
                  tone: PdlBannerTone.danger,
                  message: getErrorMessage(_actionError!),
                  onDismiss: () => setState(() => _actionError = null),
                  dismissSemanticLabel: 'common.close'.tr(),
                ),
              ],
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          sliver: SliverToBoxAdapter(
            child: DetailStatTiles(
              key: keys.gpxTools.previewStats,
              tiles: <DetailStatTile>[
                DetailStatTile(
                  label: 'routes.distance'.tr(),
                  value: AppFormatters.formatDistance(preview.distance, units),
                ),
                DetailStatTile(
                  label: 'units.elevationGainLong'.tr(),
                  value: AppFormatters.formatElevation(
                    preview.elevationGain,
                    units,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (dated)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: GpxPreviewDeparture(preview: preview),
            ),
          ),
        SliverToBoxAdapter(
          child: RouteSection(
            key: keys.gpxTools.previewRouteSection,
            trackKey: _key,
            selection: _selection,
            cursor: cursor,
            mapKey: _mapAnchor,
            mapLayer: gpxPreviewMapLayer(preview),
            colorBy: mode.colorBy,
            onColorByChanged: (RouteColorBy v) =>
                ref
                        .read(gpxPreviewColorModeProvider(preview.id).notifier)
                        .state =
                    v,
            offersWind: offeredWind != null,
            windLeg: mode.windLeg,
            colorBySwitchKey: keys.gpxTools.previewColorBy,
          ),
        ),
        if (weather != null)
          SliverToBoxAdapter(
            child: GpxPreviewWeather(
              preview: preview,
              weather: weather,
              waiting: _weatherPoller.waiting,
              onRetry: _weatherPoller.retry,
              collapsed: hasWaypoints,
            ),
          ),
        if (hasWaypoints)
          SliverToBoxAdapter(
            child: DetailSection(
              key: keys.gpxTools.previewWaypoints,
              title: 'routes.waypoints.title'.tr(),
              count: 'routes.waypoints.count'.plural(preview.waypoints.length),
              child: RouteWaypointsSection(
                waypoints: preview.waypoints,
                selection: _selection,
                showHeader: false,
                onSelect: (String key, WaypointDto _) => _focusFromList(key),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          sliver: SliverToBoxAdapter(
            child: Text(
              'gpxTools.retentionNotice'.tr(),
              key: keys.gpxTools.previewRetention,
              style: t.xs.copyWith(color: c.textDimmed),
            ),
          ),
        ),
      ],
    );
  }

  /// Le partage, pour tout le monde ; le `⋯`, s'il a un geste à offrir.
  List<Widget> _actions(GpxPreviewDto preview) {
    final List<GpxPreviewAction> actions = gpxPreviewActions(preview);
    return <Widget>[
      // `Builder` : la feuille de partage s'ancre au bouton (iPad).
      Builder(
        builder: (BuildContext buttonContext) => PdlAppBarAction(
          key: keys.gpxTools.shareButton,
          icon: PdlIcons.share,
          semanticLabel: 'gpxTools.preview.share'.tr(),
          onPressed: () => shareAppLink(
            buttonContext,
            title: preview.name,
            path: Paths.gpxToolsView(preview.id),
          ),
        ),
      ),
      if (actions.isNotEmpty)
        PdlAppBarAction(
          key: keys.gpxTools.moreButton,
          icon: PdlIcons.more,
          semanticLabel: 'gpxTools.preview.more'.tr(),
          onPressed: _busy ? null : () => _openMenu(preview, actions),
        ),
    ];
  }

  Future<void> _openMenu(
    GpxPreviewDto preview,
    List<GpxPreviewAction> actions,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final GpxPreviewAction? action = await PdlSheet.show<GpxPreviewAction>(
        context: context,
        builder: (BuildContext sheetContext) => PdlSheet(
          title: preview.name,
          bodyPadding: EdgeInsets.zero,
          footer: const SafeArea(
            top: false,
            child: SizedBox(height: PdlSpacing.chipGap),
          ),
          children: <Widget>[
            for (final GpxPreviewAction a in actions)
              switch (a) {
                GpxPreviewAction.delete => PdlSettingRow(
                  key: keys.gpxTools.deleteAction,
                  icon: PdlIcons.delete,
                  title: 'gpxTools.preview.delete'.tr(),
                  destructive: true,
                  trailing: const SizedBox.shrink(),
                  onTap: () => Navigator.of(sheetContext).pop(a),
                ),
              },
          ],
        ),
      );
      if (action == null || !mounted) return;
      switch (action) {
        case GpxPreviewAction.delete:
          await _delete(preview);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(GpxPreviewDto preview) async {
    final bool ok = await confirmDestructive(
      context,
      title: 'gpxTools.preview.deleteConfirmTitle'.tr(),
      message: 'gpxTools.preview.deleteConfirm'.tr(),
      confirmLabel: 'gpxTools.preview.delete'.tr(),
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(gpxPreviewRepositoryProvider).delete(preview.id);
    } catch (error) {
      if (mounted) setState(() => _actionError = error);
      return;
    }
    if (!mounted) return;
    // La liste se relit ; la fiche, partie, ne relit rien.
    ref.invalidate(myGpxPreviewsProvider);
    context.pop();
  }

  /// Toucher une ligne de la liste : la carte revient à l'écran, puis se
  /// centre sur le point.
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

  // ── Chargement et erreurs ───────────────────────────────────────────────
  Widget _loading() {
    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PdlSpacing.section),
        children: const <Widget>[
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
              ? PdlIcons.gpx
              : (resolved.isOffline ? PdlIcons.offline : null),
          title: notFound
              ? 'gpxTools.preview.notFoundTitle'.tr()
              : (resolved.title ?? 'gpxTools.preview.loadErrorTitle'.tr()),
          message: notFound
              ? 'gpxTools.preview.notFoundMessage'.tr()
              : resolved.message,
          actions: <Widget>[
            if (!notFound)
              PdlButton(
                label: 'common.retry'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: () =>
                    ref.invalidate(gpxPreviewProvider(widget.previewId)),
              ),
            ReportProblemButton(error: error, stackTrace: stack),
          ],
        ),
      ),
    );
  }
}
