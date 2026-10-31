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
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../routes/presentation/widgets/embedded_route_sheet.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../routes/providers/route_detail_provider.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_weather_provider.dart';
import '../../domain/trip_weather_map.dart';
import '../../../rides/presentation/widgets/ride_weather_map_markers.dart';
import '../../../rides/presentation/widgets/ride_wind_map_legend.dart';
import '../../../rides/presentation/widgets/weather_map_layer.dart';
import '../../../routes/domain/route_color_mode.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/widgets/route_color_mode_switch.dart';
import '../../../routes/presentation/widgets/route_map.dart';
import '../widgets/stage_weather_card.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';
import '../../../../core/widgets/zone_mention_line.dart';

/// L'écran 25 — une étape de voyage.
///
/// **Il n'y a pas d'endpoint d'étape dédié, et ce n'est pas un problème** :
/// l'écran charge le voyage et y sélectionne l'étape par son slug. Le rail
/// d'étapes a de toute façon besoin de la liste complète, et le détail est
/// partagé avec l'écran 24 — passer d'une étape à l'autre ne recharge rien.
class StageDetailPage extends ConsumerWidget {
  const StageDetailPage({
    super.key,
    required this.teamSlug,
    required this.tripSlug,
    required this.stageSlug,
  });

  final String teamSlug;
  final String tripSlug;
  final String stageSlug;

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
              tripKey: key,
              trip: trip,
              stages: stages,
              stage: stages[index],
            );
          },
          loading: () => const _StageSkeleton(),
          error: (Object error, StackTrace stack) =>
              _StageError(tripKey: key, error: error),
        );
  }
}

// ─────────────────────────────────────────────────────────────── contenu

class _StageDetailContent extends ConsumerWidget {
  const _StageDetailContent({
    required this.tripKey,
    required this.trip,
    required this.stages,
    required this.stage,
  });

  final TripKey tripKey;
  final TripDto trip;
  final List<TripStageDto> stages;
  final TripStageDto stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? routeSlug = stage.route?.slug;
    final bool? isMember = ref.watch(teamMembershipProvider(trip.team.slug));
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
    final bool showsWind = tripMapWindLegs(
      trip,
      watchTripMapWeather(ref, tripKey, trip),
    ).containsKey(stage.id);

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
      appBar: PdlAppBar(
        // Pas de titre : le corps le porte déjà en 22/700, juste dessous,
        // avec sa ligne d'équipe et ses badges. Le répéter en 17 dans la
        // barre le dit deux fois sur le même écran.
        onBack: () => _openTrip(context),
        backSemanticLabel: 'trips.stage.backToTrip'.tr(),
        actions: <Widget>[
          PdlAppBarAction(
            icon: PdlIcons.share,
            semanticLabel: 'routes.share'.tr(),
            onPressed: () => _share(context),
          ),
        ],
      ),
      // `PdlScreenScaffold` enveloppe lui-même la barre dans un
      // `PdlPinnedToolbar` : l'envelopper ici en imbriquerait deux slivers.
      toolbar: _rail(context),
      slivers: <Widget>[
        SliverToBoxAdapter(child: _identity(context)),
        SliverToBoxAdapter(
          child: _facts(context, ref.watch(unitSystemProvider)),
        ),
        SliverToBoxAdapter(
          child: StageWeatherCard(tripKey: tripKey, trip: trip, stage: stage),
        ),
        if (routeSlug != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              // **Le bloc de l'écran 13, tel quel.** Toute divergence de rendu
              // entre les deux serait un défaut, pas une adaptation : c'est le
              // même widget, avec ses exports, son réticule et ses cols.
              child: EmbeddedRouteSheet(
                routeKey: RouteKey(
                  teamSlug: trip.team.slug,
                  routeSlug: routeSlug,
                ),
                mapLayer: _mapLayer,
                // L'interrupteur unique Pente | Revêtement | Météo sous la
                // carte (ledger `MOB-105`), partagé avec la carte d'ensemble.
                colorBy: ref.watch(tripMapColorModeProvider(tripKey)),
                onColorByChanged: (RouteColorBy v) =>
                    ref.read(tripMapColorModeProvider(tripKey).notifier).state =
                        v,
                offersWind: showsWind,
                colorBySwitchKey: keys.trip.stageMapColorBy,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PdlEmptyState(
                variant: PdlEmptyVariant.empty,
                icon: PdlIcons.route,
                title: 'trips.stage.noRouteTitle'.tr(),
                message: 'trips.stage.noRouteMessage'.tr(),
              ),
            ),
          ),
        if (stage.media.markdown.trim().isNotEmpty)
          SliverToBoxAdapter(child: _description(context)),
        // Section à part, et non un appendice de la description : une étape
        // peut porter une trace ou un plan sans une ligne de texte.
        if (stage.media.assets.attachments.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: MediaAttachments(
                attachments: stage.media.assets.attachments,
                spacingBefore: 0,
              ),
            ),
          ),
        // Le fil **propre à l'étape**, distinct de celui du voyage
        // (docs/LEDGER_*.md API-11). Même règle que sur le voyage :
        // `commentCount` absent signifie « vous n'avez pas le droit de lire
        // les commentaires », et le fil n'est pas monté du tout.
        if (stage.commentCount != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(PdlSpacing.section),
              child: CommentThread(
                target: CommentTarget(
                  entity: CommentEntity.stage,
                  teamSlug: trip.team.slug,
                  slug: stage.slug,
                ),
                canComment: isMember ?? false,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  // ── Le mode de la carte ─────────────────────────────────────────────────
  /// Ce que l'étape pose sur la carte de son parcours, relu au `build` de
  /// chaque carte, plein écran compris (voir `RouteMapLayerBuilder`) :
  ///
  /// * le mode partagé avec la carte d'ensemble ([tripMapColorModeProvider],
  ///   ledger `MOB-105`), relu ici pour que le plein écran le suive ;
  /// * en plein écran, le même interrupteur Pente | Revêtement | Météo que
  ///   sous la carte encastrée, posé en bas de la carte ;
  /// * en mode « Météo », le vent de l'étape comme dans l'Aperçu d'un groupe
  ///   (ledger `MOB-94`) : tracé coloré, légende et crédit ; pastilles et leur
  ///   feuille en plein écran seulement, à l'heure de la zone de l'étape.
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
      markers: fullscreen && windLeg != null
          ? weatherMarkersOnRoute(
              route,
              windLeg,
              units: units,
              timezone: stage.timezone,
            )
          : const <PdlMapMarker>[],
      onMarkerTapped: windLeg == null
          ? null
          : (BuildContext context, String id) => openWeatherMapMarker(
              context,
              id,
              leg: windLeg,
              units: units,
              timezone: stage.timezone,
            ),
      foreground: routeMapBottomLayer(
        fullscreen: fullscreen,
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

  // ── Le rail ─────────────────────────────────────────────────────────────
  /// Épinglé sous la barre, pastille active recentrée : arriver sur la J6 sans
  /// recentrage donnerait un rail qui commence à J1, c'est-à-dire un rail qui
  /// ne montre pas où l'on est.
  ///
  /// Un tap **remplace** l'écran, il ne l'empile pas : sans cela, parcourir
  /// sept étapes laisserait sept pages dans la pile et sept retours à faire.
  Widget _rail(BuildContext context) {
    final int current = stages.indexOf(stage);

    return PdlStageRail(
      key: keys.trip.stageRail,
      selectedIndex: current + 1,
      items: <PdlStageRailItem>[
        PdlStageRailItem(label: 'trips.stage.overview'.tr()),
        for (final TripStageDto s in stages)
          PdlStageRailItem(
            label: s.name,
            sublabel: s.startsAt == null
                ? null
                : AppFormatters.formatDayMonth(s.startsAt!),
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

  // ── Identité ────────────────────────────────────────────────────────────
  Widget _identity(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: const EdgeInsets.all(PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // La ligne de contexte remonte au **voyage**, pas à l'équipe : c'est
          // le parent immédiat de l'étape, et celui vers lequel tout le reste
          // de l'écran renvoie.
          PdlTeamLine(
            label: trip.name,
            icon: PdlIcons.trip,
            onTap: () => _openTrip(context),
          ),
          const SizedBox(height: 2),
          Text(stage.name, key: keys.trip.stageTitle, style: t.screenTitle),
          const SizedBox(height: PdlSpacing.chipGap),
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
              PdlBadge(
                key: keys.trip.stagePosition,
                label: 'trips.stage.numberOf'.tr(
                  namedArgs: <String, String>{
                    'index': '${stage.stageIndex}',
                    'total': '${stage.stageCount}',
                  },
                ),
                tone: PdlDerivedTones.registered(c),
              ),
              if (trip.isCancelled)
                PdlBadge(
                  label: 'status.cancelled'.tr(),
                  tone: Status.fromJson('CANCELLED').tone(c),
                )
              else if (trip.isPast)
                PdlBadge(
                  label: 'trips.finished'.tr(),
                  tone: PdlDerivedTones.done(c),
                )
              else
                PdlBadge(
                  label: 'status.${trip.status.toLowerCase()}'.tr(),
                  tone: Status.fromJson(trip.status).tone(c),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Date, vitesse et lieux ──────────────────────────────────────────────
  Widget _facts(BuildContext context, UnitSystem units) {
    final PdlTypography t = context.pdlText;
    final DateTime? start = stage.startsAt;
    final PlaceDetailDto? from = stage.startPlace;
    final PlaceDetailDto? to = stage.endPlace;

    if (start == null && from == null && to == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: PdlCard(
        flat: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (start != null)
              Row(
                children: <Widget>[
                  PdlNumberPill(value: stage.stageIndex),
                  const SizedBox(width: PdlSpacing.chipGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppFormatters.formatLongDate(start),
                          style: t.bodyStrong,
                        ),
                        // La vitesse de l'étape, facultative, suit l'heure
                        // de départ comme sur la carte d'un groupe de sortie.
                        Text(
                          <String>[
                            'trips.stage.groupStart'.tr(
                              namedArgs: <String, String>{
                                'time': AppFormatters.formatTime(start),
                              },
                            ),
                            if (stage.averageSpeed != null)
                              AppFormatters.formatSpeed(
                                stage.averageSpeed!,
                                units,
                              ),
                          ].join(' · '),
                          style: t.xs,
                        ),
                        // Le départ vu d'ailleurs (docs/LEDGER_*.md API-60).
                        ?ZoneMentionLine.maybe(stage.dateTime, stage.timezone),
                      ],
                    ),
                  ),
                ],
              ),
            // `PlaceDetailDto.address` existe au contrat et n'était **jamais
            // lue** : « Place de Jaude » devient « Place de Jaude, 63000
            // Clermont-Ferrand ». Absente, la ligne se réduit d'elle-même.
            if (from != null) ...<Widget>[
              const SizedBox(height: PdlSpacing.cardTight),
              PdlPlaceRow(
                kind: PdlPlaceKind.start,
                name: from.name,
                address: from.address,
              ),
            ],
            if (to != null) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              PdlPlaceRow(
                kind: PdlPlaceKind.end,
                name: to.name,
                address: to.address,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _description(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlSectionHeader(title: 'trips.description'.tr()),
          MarkdownContent(
            data: stage.media.markdown,
            images: stage.media.assets.images,
          ),
        ],
      ),
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

/// Le squelette annonce la forme de l'écran : quatre pastilles de rail, la
/// carte, deux blocs. Pas un rond qui tourne.
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
          const PdlSkeleton(height: 96),
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
