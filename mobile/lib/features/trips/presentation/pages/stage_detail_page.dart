import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
import '../../../../core/utils/directions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_reveal.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/day_box.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../core/widgets/detail_stat_tiles.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../rides/domain/ride_weather_display.dart';
import '../../../rides/domain/ride_weather_map.dart';
import '../../../rides/presentation/widgets/ride_weather_map_markers.dart';
import '../../../rides/presentation/widgets/ride_weather_widgets.dart';
import '../../../rides/presentation/widgets/ride_wind_map_legend.dart';
import '../../../rides/presentation/widgets/weather_map_layer.dart';
import '../../../rides/presentation/widgets/weather_section.dart';
import '../../../routes/domain/route_color_mode.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/widgets/route_climbs_section.dart';
import '../../../routes/presentation/widgets/route_color_mode_switch.dart';
import '../../../routes/presentation/widgets/route_cursor_controller.dart';
import '../../../routes/presentation/widgets/route_map.dart';
import '../../../routes/presentation/widgets/route_section.dart';
import '../../../routes/presentation/widgets/route_waypoints_section.dart';
import '../../../routes/presentation/widgets/waypoint_selection.dart';
import '../../../routes/providers/route_detail_provider.dart';
import '../../../teams/domain/publication_timing.dart';
import '../../domain/trip_weather_map.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_weather_provider.dart';

/// L'écran 25 — une étape de voyage (ledger `MOB-134`, lot 11, KIT §8,
/// maquette `etape-mobile-cible`). L'étape est à un voyage ce que le groupe
/// est à une sortie : même ossature que la page d'un groupe, une page qui
/// défile, de haut en bas :
///
/// 1. la barre « Étape 2 sur 3 » sur le nom du voyage, et le partage ;
/// 2. le rail des étapes, épinglé (« Aperçu », puis une pastille par étape) ;
/// 3. le nom de l'étape et son bloc de départ : boîte du jour, « Départ
///    09:00 », « Arrivée estimée 11:50 » (`TripStageDto.estimatedArrival`),
///    les lieux de départ et d'arrivée en liens d'itinéraire ;
/// 4. les tuiles Distance | Dénivelé positif / Durée estimée | Vitesse
///    moyenne ([stageStatTiles]) ;
/// 5. « Parcours » ([RouteSection]) puis, repliés, « Points du parcours » et
///    « Cols et montées » ;
/// 6. « Description » et ses pièces jointes ;
/// 7. « Météo » ([WeatherSection]), tant que l'étape n'est pas arrivée
///    ([tripStagePhase]) ;
/// 8. les commentaires **de l'étape**.
///
/// Ni lien vers le voyage ni badges dans le corps : ils sont sur le voyage.
///
/// **Il n'y a pas d'endpoint d'étape dédié** : l'écran charge le voyage et y
/// sélectionne l'étape par son slug. Le rail a de toute façon besoin de la
/// liste complète, et le détail est partagé avec l'écran 24 — passer d'une
/// étape à l'autre ne recharge rien.
class StageDetailPage extends ConsumerWidget {
  const StageDetailPage({
    super.key,
    required this.teamSlug,
    required this.tripSlug,
    required this.stageSlug,
    this.now,
  });

  final String teamSlug;
  final String tripSlug;
  final String stageSlug;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TripKey key = TripKey(teamSlug: teamSlug, tripSlug: tripSlug);

    return ref
        .watch(tripDetailProvider(key))
        .when(
          data: (TripDto trip) {
            final List<TripStageDto> stages = trip.orderedStages;
            final int index = stages.indexWhere(
              (TripStageDto s) => s.slug == stageSlug,
            );
            if (index < 0) return _StageNotFound(trip: trip);
            return _StageDetailContent(
              key: ValueKey<String>('stage_${stages[index].id}'),
              tripKey: key,
              trip: trip,
              stages: stages,
              stage: stages[index],
              now: now,
            );
          },
          loading: () => const _StageSkeleton(),
          error: (Object error, StackTrace stack) =>
              _StageError(tripKey: key, error: error),
        );
  }
}

/// Les tuiles d'une étape, dans l'ordre du KIT §8 : Distance | Dénivelé
/// positif, puis Durée estimée | Vitesse moyenne ; une tuile sans donnée
/// disparaît — sans durée ni vitesse, une seule ligne. La distance et le
/// dénivelé sont ceux du parcours de l'étape ; la durée, celle que le serveur
/// calcule (`estimatedDurationMinutes`, ledger `API-172`).
List<DetailStatTile> stageStatTiles(TripStageDto stage, UnitSystem units) {
  final RouteDto? route = stage.route;
  return <DetailStatTile>[
    if (route != null) ...<DetailStatTile>[
      DetailStatTile(
        label: 'rides.groupPage.stats.distance'.tr(),
        value: AppFormatters.formatDistance(route.distance, units),
      ),
      DetailStatTile(
        label: 'rides.groupPage.stats.elevation'.tr(),
        value: AppFormatters.formatElevation(route.elevationGain, units),
      ),
    ],
    if (stage.estimatedDurationMinutes != null)
      DetailStatTile(
        label: 'rides.groupPage.stats.estimatedDuration'.tr(),
        value: AppFormatters.formatDurationMinutes(
          stage.estimatedDurationMinutes!,
        ),
      ),
    if (stage.averageSpeed != null)
      DetailStatTile(
        label: 'rides.groupPage.stats.pace'.tr(),
        value: AppFormatters.formatSpeed(stage.averageSpeed!, units),
      ),
  ];
}

/// « Arrivée estimée 11:50 », dans le fuseau de l'étape — `null` sans
/// `estimatedArrival` (pas de parcours ou pas de vitesse, ou une API plus
/// ancienne qui ne le sert pas).
String? stageArrivalLine(TripStageDto stage) {
  final String? at = stage.estimatedArrival;
  if (at == null) return null;
  final DateTime? wall = AppFormatters.tryParseZoneTime(at, stage.timezone);
  if (wall == null) return null;
  return 'rides.groupPage.stats.arrival'.tr(
    namedArgs: <String, String>{'time': AppFormatters.formatTime(wall)},
  );
}

// ─────────────────────────────────────────────────────────────── contenu

class _StageDetailContent extends ConsumerStatefulWidget {
  const _StageDetailContent({
    super.key,
    required this.tripKey,
    required this.trip,
    required this.stages,
    required this.stage,
    this.now,
  });

  final TripKey tripKey;
  final TripDto trip;
  final List<TripStageDto> stages;
  final TripStageDto stage;
  final DateTime? now;

  @override
  ConsumerState<_StageDetailContent> createState() =>
      _StageDetailContentState();
}

class _StageDetailContentState extends ConsumerState<_StageDetailContent> {
  final ScrollController _scroll = ScrollController();

  /// La carte de « Parcours », que le toucher d'un point de la frise, d'une
  /// montée ou d'un point du parcours remonte à l'écran ; et le rail épinglé
  /// qu'un tel défilement doit laisser au-dessus.
  final GlobalKey _mapAnchor = GlobalKey();
  final GlobalKey _toolbarKey = GlobalKey();

  /// Le réticule, partagé par la carte, le profil, les montées et la frise
  /// météo — reconstruit quand, et seulement quand, le parcours change.
  RouteCursorController? _cursor;
  String? _cursorForSlug;

  /// Le point de parcours choisi, partagé par la carte, le profil et la liste
  /// (ledger `MOB-84`).
  final WaypointSelectionController _selection = WaypointSelectionController();

  /// L'`index` du point de la frise météo dont le réticule est sur la carte.
  int? _checkpoint;

  TripKey get tripKey => widget.tripKey;
  TripDto get trip => widget.trip;
  TripStageDto get stage => widget.stage;

  @override
  void dispose() {
    _scroll.dispose();
    _cursor?.dispose();
    _selection.dispose();
    super.dispose();
  }

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

  /// Remonte la carte sous le rail épinglé.
  Future<void> _revealMap() => revealInScroll(
    context,
    _scroll,
    _mapAnchor,
    topInset: _toolbarKey.currentContext?.size?.height ?? 0,
  );

  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  /// Pose le réticule d'un point de la frise et remonte jusqu'à la carte ; le
  /// même point retouché l'ôte, sans défiler (comme la page d'un groupe).
  void _toggleCheckpoint(WeatherCheckpointDto checkpoint) {
    final bool off = _checkpoint == checkpoint.indexField;
    setState(() => _checkpoint = off ? null : checkpoint.indexField);
    _cursor?.moveTo(off ? null : checkpoint.distance);
    if (!off) _afterFrame(_revealMap);
  }

  /// Une montée touchée : le réticule à son pied, la carte à l'écran.
  void _focusClimb(ClimbDto climb) {
    _cursor?.moveTo(climb.startDistance.toDouble());
    _afterFrame(_revealMap);
  }

  /// Un point touché dans la liste : la carte revient à l'écran, puis s'y
  /// centre — sans quoi le recentrage aurait lieu hors de vue.
  Future<void> _focusWaypoint(String key) async {
    await _revealMap();
    if (!mounted) return;
    _selection.select(key, move: PdlWaypointMove.center);
  }

  /// La météo se demande-t-elle ? Toujours, sauf pour un voyage annulé.
  /// Aucune règle de date ici : jusqu'à quand elle se montre est la décision
  /// du serveur, que sa réponse porte (`OUT_OF_RANGE` sur l'étape passé la
  /// fin du jour où elle arrive — ledger `API-170`, `API-183`).
  bool get _asksWeather => !trip.isCancelled;

  @override
  Widget build(BuildContext context) {
    final String? routeSlug = stage.route?.slug;
    final RouteKey? routeKey = routeSlug == null
        ? null
        : RouteKey(teamSlug: trip.team.slug, routeSlug: routeSlug);
    final RouteDetailDto? route = routeKey == null
        ? null
        : ref.watch(routeDetailProvider(routeKey)).value;
    final RouteCursorController? cursor = route == null
        ? null
        : _cursorFor(route);

    // Le mode de la carte de l'étape (ledgers `MOB-94`, `MOB-105`), partagé
    // avec la carte d'ensemble du voyage : gardé en vie tant que la page est
    // montée, ramené de « Météo » sur la pente quand l'étape perd sa
    // prévision.
    listenTripMapWindMode(
      ref,
      tripKey,
      trip,
      stillShows: (Map<String, WeatherLegDto> legs) =>
          legs.containsKey(stage.id),
    );
    final WeatherLegDto? windLeg = tripMapWindLegs(
      trip,
      watchTripMapWeather(ref, tripKey, trip),
    )[stage.id];

    final AsyncValue<TripWeatherDto>? watchedWeather = _asksWeather
        ? ref.watch(tripWeatherProvider(tripKey))
        : null;
    // `OUT_OF_RANGE` — le voyage, ou cette étape passé la fin du jour où elle
    // arrive : plus de section Météo du tout. La seule règle de fin, celle
    // du serveur (ledger `API-183`).
    final TripWeatherDto? readWeather = watchedWeather?.value;
    final bool weatherOver =
        readWeather != null &&
        (weatherIsOutOfRange(readWeather.status) ||
            weatherIsOutOfRange(
              stageWeatherFor(readWeather, stage.id)?.leg.status,
            ));
    final AsyncValue<TripWeatherDto>? weatherState = weatherOver
        ? null
        : watchedWeather;
    // Le réticule de la frise ne vaut que sur une carte à dessiner et une
    // frise prévue.
    final bool cursorEnabled =
        cursor != null &&
        route!.hasGeometry &&
        showsWindOnMap(_stageWeather(weatherState?.value)?.leg);

    final List<DetailStatTile> tiles = stageStatTiles(
      stage,
      ref.watch(unitSystemProvider),
    );
    final bool hasDescription =
        stage.media.markdown.trim().isNotEmpty ||
        stage.media.assets.attachments.isNotEmpty;

    EdgeInsets block({double top = PdlSpacing.section}) =>
        EdgeInsets.fromLTRB(PdlSpacing.section, top, PdlSpacing.section, 0);

    return PdlScreenScaffold(
      // Relit le voyage (le détail reste affiché pendant l'appel,
      // `skipLoadingOnRefresh`) et sa météo, partagés avec l'écran 24.
      onRefresh: () async {
        ref.invalidate(tripWeatherProvider(tripKey));
        try {
          ref.invalidate(tripDetailProvider(tripKey));
          await ref.read(tripDetailProvider(tripKey).future);
        } catch (_) {}
      },
      scrollController: _scroll,
      appBar: _appBar(context),
      // `PdlScreenScaffold` enveloppe lui-même la barre dans un
      // `PdlPinnedToolbar` : l'envelopper ici en imbriquerait deux slivers.
      toolbar: KeyedSubtree(key: _toolbarKey, child: _rail(context)),
      slivers: <Widget>[
        SliverPadding(
          padding: block(),
          sliver: SliverToBoxAdapter(
            child: Text(
              stage.name,
              key: keys.trip.stageTitle,
              style: context.pdlText.screenTitle,
            ),
          ),
        ),
        if (_departure(context) case final Widget departure)
          SliverPadding(
            padding: block(top: PdlSpacing.cardTight),
            sliver: SliverToBoxAdapter(child: departure),
          ),
        if (tiles.isNotEmpty)
          SliverPadding(
            padding: block(top: PdlSpacing.chipGap),
            sliver: SliverToBoxAdapter(
              child: DetailStatTiles(
                key: keys.trip.stageStatTiles,
                tiles: tiles,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.trip.stageRouteSection,
            child: routeKey == null
                ? _noRoute()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      RouteSection(
                        routeKey: routeKey,
                        title: 'rides.routeSection.title'.tr(),
                        selection: _selection,
                        cursor: cursor,
                        mapLayer: _mapLayer,
                        // L'interrupteur unique Pente | Revêtement | Météo
                        // sous la carte (ledger `MOB-105`), partagé avec la
                        // carte d'ensemble du voyage.
                        colorBy: ref.watch(tripMapColorModeProvider(tripKey)),
                        onColorByChanged: (RouteColorBy v) =>
                            ref
                                    .read(
                                      tripMapColorModeProvider(tripKey)
                                          .notifier,
                                    )
                                    .state =
                                v,
                        offersWind: windLeg != null,
                        // La bande du vent sous le profil, en mode Météo
                        // (ledger `MOB-106`).
                        windLeg: windLeg,
                        colorBySwitchKey: keys.trip.stageMapColorBy,
                        showDetailsAction: true,
                        mapKey: _mapAnchor,
                      ),
                      if (route != null) ..._routeLists(route),
                    ],
                  ),
          ),
        ),
        if (hasDescription)
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.trip.stageDescriptionSection,
              child: _description(),
            ),
          ),
        if (weatherState != null)
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.trip.stageWeatherSection,
              child: _weather(weatherState, cursorEnabled: cursorEnabled),
            ),
          ),
        // Le fil **propre à l'étape**, distinct de celui du voyage
        // (docs/LEDGER_*.md API-11). `commentCount` absent signifie « vous
        // n'avez pas le droit de lire les commentaires » : le fil n'est pas
        // monté du tout.
        if (stage.commentCount != null)
          SliverPadding(
            padding: block(top: PdlSpacing.detailSectionGap),
            sliver: SliverToBoxAdapter(
              child: KeyedSubtree(
                key: keys.trip.stageCommentsSection,
                child: CommentThread(
                  target: CommentTarget(
                    entity: CommentEntity.stage,
                    teamSlug: trip.team.slug,
                    slug: stage.slug,
                  ),
                  // Le droit calculé par le backend pour l'étape
                  // (docs/LEDGER_*.md MOB-137).
                  canComment: stage.permissions.canComment ?? false,
                  countAtEnd: true,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  // ── Barre du haut ───────────────────────────────────────────────────────
  /// « Étape 2 sur 3 » sur le nom du voyage, comme « Groupe A » sur celui de
  /// la sortie ; le retour ramène au voyage.
  PdlAppBar _appBar(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return PdlAppBar(
      onBack: () => _openTrip(context),
      backSemanticLabel: 'trips.stage.backToTrip'.tr(),
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          KeyedSubtree(
            key: keys.trip.stagePosition,
            child: Text(
              'trips.stage.numberOf'.tr(
                namedArgs: <String, String>{
                  'index': '${stage.stageIndex}',
                  'total': '${stage.stageCount}',
                },
              ),
              style: t.barTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            trip.name,
            style: t.xs,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: <Widget>[
        PdlAppBarAction(
          icon: PdlIcons.share,
          semanticLabel: 'routes.share'.tr(),
          onPressed: () => _share(context),
        ),
      ],
    );
  }

  // ── Le rail ─────────────────────────────────────────────────────────────
  /// Épinglé sous la barre, pastille active recentrée : arriver sur la J6 sans
  /// recentrage donnerait un rail qui commence à J1, c'est-à-dire un rail qui
  /// ne montre pas où l'on est.
  ///
  /// Un tap **remplace** l'écran, il ne l'empile pas : sans cela, parcourir
  /// sept étapes laisserait sept pages dans la pile et sept retours à faire.
  Widget _rail(BuildContext context) {
    final List<TripStageDto> stages = widget.stages;
    final int current = stages.indexOf(stage);

    return PdlStageRail(
      key: keys.trip.stageRail,
      selectedIndex: current + 1,
      items: <PdlStageRailItem>[
        PdlStageRailItem(label: 'trips.stage.overview'.tr()),
        for (final TripStageDto s in stages)
          PdlStageRailItem(
            label: s.name,
            // Le jour au format unique, dans le fuseau de l'étape : « mar.
            // 12 août », l'année hors de l'année en cours (BRANDING §8.3).
            sublabel: switch (DateTime.tryParse(s.dateTime)) {
              final DateTime at => AppFormatters.formatDepartureDate(
                at,
                s.timezone,
              ),
              null => null,
            },
          ),
      ],
      onSelected: (int index) {
        if (index == 0) {
          _openTrip(context);
          return;
        }
        final TripStageDto target = stages[index - 1];
        if (target.slug == stage.slug) return;
        context.replace(Paths.stage(trip.team.slug, trip.slug, target.slug));
      },
    );
  }

  void _openTrip(BuildContext context) =>
      context.go(Paths.trip(trip.team.slug, trip.slug));

  Future<void> _share(BuildContext context) => shareAppLink(
    context,
    title: '${trip.name} — ${stage.name}',
    path: Paths.stage(trip.team.slug, trip.slug, stage.slug),
  );

  // ── Bloc de départ ──────────────────────────────────────────────────────
  /// Boîte du jour turquoise, « Départ 09:00 », pastille « Demain » avant le
  /// départ, « Arrivée estimée 11:50 », la mention de fuseau sur cette heure ;
  /// dessous, les lieux en liens d'itinéraire (KIT §8). La boîte dit la date :
  /// la ligne atténuée ne la répète pas, le lecteur d'écran la lit.
  Widget? _departure(BuildContext context) {
    final DateTime? instant = DateTime.tryParse(stage.dateTime);
    if (instant == null) return null;
    final String zone = stage.timezone;
    final DateTime wall = AppFormatters.toZoneTime(instant, zone);
    final DateTime? now = widget.now;

    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{'time': AppFormatters.formatTime(wall)},
    );
    final String? relative =
        trip.isCancelled ||
            tripStagePhase(trip, stage, now: now) != PublicationPhase.upcoming
        ? null
        : AppFormatters.formatDepartureRelative(instant, zone, now: now);
    final String date = AppFormatters.formatDepartureDate(
      instant,
      zone,
      now: now,
    );
    final String? arrival = stageArrivalLine(stage);
    final String? mention = AppFormatters.formatZoneMention(instant, zone);

    return PdlDepartureBlock(
      key: keys.trip.stageDepartureBlock,
      dayBox: dayBoxFor(
        wall,
        tone: PublicationType.trip.tone(context.pdl),
        now: now,
      ),
      headline: headline,
      relativeLabel: relative,
      details: <String>[?arrival],
      zoneMention: mention == null
          ? null
          : ZoneMentionLine(instant: instant, zone: zone),
      semanticLabel: <String>[
        headline,
        ?relative,
        date,
        ?arrival,
        ?mention,
      ].join(', '),
      places: <Widget>[
        if (stage.startPlace case final PlaceDetailDto start)
          _placeLink(
            context,
            start,
            PdlPlaceKind.start,
            keys.trip.stageStartPlaceLink,
          ),
        if (stage.endPlace case final PlaceDetailDto end)
          _placeLink(
            context,
            end,
            PdlPlaceKind.end,
            keys.trip.stageEndPlaceLink,
          ),
      ],
    );
  }

  /// Un lieu en lien d'itinéraire ; sans coordonnées ni adresse, un texte
  /// simple.
  Widget _placeLink(
    BuildContext context,
    PlaceDetailDto place,
    PdlPlaceKind kind,
    Key key,
  ) {
    return PdlPlaceRow.link(
      key: key,
      kind: kind,
      name: place.name,
      semanticLabel: 'common.directionsTo'.tr(
        namedArgs: <String, String>{'place': place.name},
      ),
      onTap: placeDirectionsUri(place) != null
          ? () => openPlaceDirections(context, place)
          : null,
    );
  }

  // ── Parcours ────────────────────────────────────────────────────────────
  /// Sans parcours : le titre et un état vide, plutôt qu'un trou.
  Widget _noRoute() => DetailSection(
    title: 'rides.routeSection.title'.tr(),
    child: PdlEmptyState(
      variant: PdlEmptyVariant.empty,
      icon: PdlIcons.route,
      title: 'trips.stage.noRouteTitle'.tr(),
      message: 'trips.stage.noRouteMessage'.tr(),
    ),
  );

  /// « Points du parcours » et « Cols et montées », repliés sous les actions
  /// de la carte (maquette `etape-mobile-cible` ; KIT §8 : les points, sur un
  /// écran qui montre un seul parcours).
  List<Widget> _routeLists(RouteDetailDto route) {
    final List<ClimbDto> climbs = route.allClimbs;
    final bool waypoints = route.hasGeometry && route.waypoints.isNotEmpty;
    if (!waypoints && climbs.isEmpty) return const <Widget>[];
    return <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (waypoints) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              PdlDisclosure(
                key: keys.trip.stageWaypoints,
                title: 'routes.waypoints.title'.tr(),
                subtitles: <String>[
                  'routes.waypoints.count'.plural(route.waypoints.length),
                ],
                child: RouteWaypointsSection(
                  waypoints: route.waypoints,
                  selection: _selection,
                  showHeader: false,
                  onSelect: (String key, WaypointDto _) => _focusWaypoint(key),
                ),
              ),
            ],
            if (climbs.isNotEmpty) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              PdlDisclosure(
                key: keys.trip.stageClimbs,
                title: 'routes.climbsTitle'.tr(),
                subtitles: <String>['routes.climbCount'.plural(climbs.length)],
                child: RouteClimbsSection(
                  climbs: climbs,
                  showHeader: false,
                  // Taper une montée y amène le réticule : le lien entre la
                  // liste, le profil et la carte est toujours une distance.
                  onTapClimb: _focusClimb,
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ── Le mode de la carte ─────────────────────────────────────────────────
  /// Ce que l'étape pose sur la carte de son parcours, relu au `build` de
  /// chaque carte, plein écran compris (voir `RouteMapLayerBuilder`) :
  ///
  /// * le mode partagé avec la carte d'ensemble ([tripMapColorModeProvider],
  ///   ledger `MOB-105`), relu ici pour que le plein écran le suive ;
  /// * en plein écran, le même interrupteur Pente | Revêtement | Météo que
  ///   sous la carte encastrée, dans la carte du bas avec la légende
  ///   (`routeMapBottomLayer`) ;
  /// * en mode « Météo », le vent de l'étape comme sur la page d'un groupe
  ///   (ledger `MOB-94`) : tracé coloré, légende et crédit, pastilles et
  ///   goutte à l'heure de la zone de l'étape, encastrée comme en plein écran
  ///   (ledger `MOB-107`). Encastrée, une pastille touchée ouvre le plein
  ///   écran ; en plein écran, sa feuille.
  RouteMapLayer? _mapLayer(
    BuildContext context,
    WidgetRef ref,
    RouteDetailDto route, {
    required bool fullscreen,
  }) {
    final TripWeatherDto? weather = watchTripMapWeather(ref, tripKey, trip);
    final WeatherLegDto? leg = tripMapWindLegs(trip, weather)[stage.id];
    final List<RouteColorBy> modes = routeColorModes(
      surfaces: hasTrackSurfaces(route.tracks),
      wind: leg != null,
    );
    final RouteColorBy colorBy = resolveRouteColorBy(
      ref.watch(tripMapColorModeProvider(tripKey)),
      modes,
    );
    final WeatherLegDto? windLeg = colorBy == RouteColorBy.wind ? leg : null;
    final UnitSystem units = ref.watch(unitSystemProvider);
    return RouteMapLayer(
      colorBy: colorBy,
      // Un tronçon sans vent connu prend le bleu neutre, jamais le gris du
      // travers.
      segmentColors: windLeg == null
          ? null
          : weatherTrackColors(route, windLeg),
      markers: windLeg != null
          ? weatherMarkersOnRoute(
              route,
              windLeg,
              units: units,
              timezone: stage.timezone,
            )
          : const <PdlMapMarker>[],
      onMarkerTapped: windLeg == null
          ? null
          : fullscreen
          ? (BuildContext context, String id) => openWeatherMapMarker(
              context,
              id,
              leg: windLeg,
              units: units,
              timezone: stage.timezone,
            )
          : (BuildContext context, String _) =>
                PdlMapHero.openFullscreen(context),
      bottomLayer: routeMapBottomLayer(
        modeSwitch: fullscreen && modes.length > 1
            ? RouteColorModeSwitch(
                key: keys.routeDetail.fullscreenColorBy,
                modes: modes,
                value: colorBy,
                overMap: true,
                onChanged: (RouteColorBy v) =>
                    ref.read(tripMapColorModeProvider(tripKey).notifier).state =
                        v,
              )
            : null,
        legend: windLeg == null
            ? null
            : RideWindMapLegend(
                leg: windLeg,
                units: units,
                attribution: weather?.attribution,
              ),
      ),
    );
  }

  // ── Description ─────────────────────────────────────────────────────────
  /// « Description » : le texte puis les pièces jointes — une étape peut
  /// porter une trace ou un plan sans une ligne de texte.
  Widget _description() {
    return DetailSection(
      title: 'trips.description'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (stage.media.markdown.trim().isNotEmpty)
            MarkdownContent(
              data: stage.media.markdown,
              images: stage.media.assets.images,
            ),
          MediaAttachments(attachments: stage.media.assets.attachments),
        ],
      ),
    );
  }

  // ── Météo ───────────────────────────────────────────────────────────────
  /// La météo de cette étape dans la réponse du voyage, si son statut global
  /// montre quelque chose.
  TripStageWeatherDto? _stageWeather(TripWeatherDto? dto) {
    if (dto == null || !tripWeatherShowsAnything(dto)) return null;
    return stageWeatherFor(dto, stage.id);
  }

  /// La section Météo : le départ de l'étape (`TripStageWeatherDto.departure`,
  /// à l'heure de son leg), le vent, la frise, la source. « Météo le long du
  /// parcours » se replie quand les commentaires suivent. Sans prévision à
  /// montrer (étape partie, statut inconnu, `NO_LOCATION` pour qui
  /// n'organise pas), le titre et une phrase.
  Widget _weather(
    AsyncValue<TripWeatherDto> state, {
    required bool cursorEnabled,
  }) {
    void retry() => ref.invalidate(tripWeatherProvider(tripKey));
    final String empty = 'trips.weather.emptyMessage'.tr();
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(
          PdlSpacing.section,
          PdlSpacing.detailSectionGap,
          PdlSpacing.section,
          0,
        ),
        child: PdlSkeleton(height: 120, borderRadius: PdlRadii.cardAll),
      ),
      error: (Object _, StackTrace _) => WeatherSection(
        view: RideWeatherView.unavailable,
        timezone: stage.timezone,
        onRetry: retry,
      ),
      data: (TripWeatherDto dto) {
        final TripStageWeatherDto? stageWeather = _stageWeather(dto);
        if (stageWeather == null) {
          return WeatherSection(
            view: RideWeatherView.hidden,
            timezone: stage.timezone,
            emptyMessage: empty,
          );
        }
        final WeatherLegDto leg = stageWeather.leg;
        final String? fetchedAt = leg.fetchedAt ?? dto.fetchedAt;
        final String? availableFrom =
            leg.availableFrom ?? stageWeather.summary?.availableFrom;
        return WeatherSection(
          view: rideWeatherViewOf(
            leg.status,
            canSeeNoLocation: watchCanSeeWeatherNoLocation(
              ref,
              tripKey.teamSlug,
            ),
          ),
          timezone: stage.timezone,
          departure: stageWeather.departure,
          departureAt: leg.startTime,
          leg: leg,
          attribution: dto.attribution,
          fetchedAt: fetchedAt == null ? null : DateTime.tryParse(fetchedAt),
          availableFrom: availableFrom == null
              ? null
              : DateTime.tryParse(availableFrom),
          collapsed: stage.commentCount != null,
          speedDefaultKey: 'trips.weather.legSpeedDefault',
          noLocationMessage: 'trips.weather.noLocation'.tr(),
          emptyMessage: empty,
          onRetry: retry,
          onCheckpointTap: cursorEnabled ? _toggleCheckpoint : null,
          selectedCheckpoint: cursorEnabled ? _checkpoint : null,
        );
      },
    );
  }
}

// ────────────────────────────────────────── introuvable, chargement, erreur

class _StageNotFound extends StatelessWidget {
  const _StageNotFound({required this.trip});

  final TripDto trip;

  @override
  Widget build(BuildContext context) {
    void openTrip() => context.go(Paths.trip(trip.team.slug, trip.slug));

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: openTrip,
        backSemanticLabel: 'trips.stage.backToTrip'.tr(),
      ),
      body: Center(
        child: PdlEmptyState(
          variant: PdlEmptyVariant.notFound,
          title: 'trips.stage.notFound'.tr(),
          message: 'trips.stage.notFoundMessage'.tr(),
          actions: <Widget>[
            PdlButton(
              label: 'trips.stage.backToTrip'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: openTrip,
            ),
          ],
        ),
      ),
    );
  }
}

/// Le squelette annonce la forme de l'écran : quatre pastilles de rail, le
/// titre, le bloc de départ, la carte. Pas un rond qui tourne.
class _StageSkeleton extends StatelessWidget {
  const _StageSkeleton();

  @override
  Widget build(BuildContext context) {
    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PdlSpacing.section),
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < 4; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: PdlSpacing.chipGap),
                const PdlSkeleton(
                  height: PdlMetrics.tapTarget,
                  width: 74,
                  borderRadius: PdlRadii.pillAll,
                ),
              ],
            ],
          ),
          const SizedBox(height: PdlSpacing.section),
          const PdlSkeleton(height: 20, width: 180),
          const SizedBox(height: PdlSpacing.chipGap),
          const PdlSkeleton(height: 96, borderRadius: PdlRadii.cardAll),
          const SizedBox(height: PdlSpacing.section),
          const PdlSkeleton(height: 240),
          const SizedBox(height: PdlSpacing.section),
          const PdlSkeleton(height: 120),
        ],
      ),
    );
  }
}

class _StageError extends ConsumerWidget {
  const _StageError({required this.tripKey, required this.error});

  final TripKey tripKey;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ApiError resolved = resolveApiError(error);

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: Center(
        child: PdlEmptyState(
          variant: resolved.code == 'NOT_FOUND'
              ? PdlEmptyVariant.notFound
              : PdlEmptyVariant.error,
          icon: resolved.isOffline ? PdlIcons.offline : null,
          title: resolved.title ?? 'common.loadError'.tr(),
          message: resolved.message,
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: () => ref.invalidate(tripDetailProvider(tripKey)),
            ),
            ReportProblemButton(error: error),
          ],
        ),
      ),
    );
  }
}
