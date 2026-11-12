import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../keys.dart';
import '../../../routes/domain/route_color_mode.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/gps_export_runner.dart';
import '../../../routes/presentation/widgets/gps_button.dart';
import '../../../routes/presentation/widgets/route_color_mode_switch.dart';
import '../../../routes/presentation/widgets/route_waypoints_section.dart';
import '../../../routes/presentation/widgets/waypoint_selection.dart';
import '../../domain/ride_route_layers.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import 'ride_elevation_section.dart';
import 'ride_group_route_actions.dart';
import 'ride_groups_map.dart';
import 'weather_map_layer.dart';

/// La section « Parcours » d'une sortie (ledger `MOB-134`, KIT §8, maquettes
/// `groupe-mobile-cible`, `sortie-solo-mobile-cible`) :
///
/// 1. le titre « Parcours », au-dessus de la carte ;
/// 2. la carte pleine largeur, à `PdlMetrics.detailMapHeight` ([RideGroupsMap]) ;
/// 3. l'interrupteur Pente | Revêtement | Météo, partagé par la carte, son
///    plein écran et le profil (ledger `MOB-105`) — ou, sur une carte à
///    plusieurs couches, la seule puce « Météo » du parcours du groupe ;
/// 4. « Profil » et son ⓘ (la source des altitudes), le profil à
///    `PdlMetrics.detailElevation`, la barre de revêtement, sa légende et son
///    ⓘ (OpenStreetMap) — [RideElevationSection] en `detailLayout` ;
/// 5. le bouton « GPS » (la feuille GPS, [GpsExportRunner]) et « Détails »,
///    qui pousse la fiche du parcours ;
/// 6. « Points du parcours » dans un [PdlDisclosure] **replié** — seulement
///    quand la carte ne montre qu'un parcours (KIT §8).
///
/// Elle remplace la carte, le profil et les actions de l'ancien onglet Aperçu
/// d'un groupe, et la carte et le profil du détail d'une sortie solo ou sans
/// groupe (lot 7) et d'une sortie à plusieurs groupes (lot 8) :
///
/// * **page d'un groupe** — [group] le groupe, [groupOnly] vrai : son seul
///   parcours, coloré comme un parcours ;
/// * **sortie solo** — [group] son groupe, [groupOnly] faux : la carte de la
///   sortie (une couche, ou deux si le groupe roule un autre parcours) ;
/// * **sortie sans groupe** — [group] nul, [groupOnly] faux : le parcours de
///   la sortie ;
/// * **plusieurs groupes** — [group] le groupe sélectionné, [groupOnly] faux,
///   [actions] faux : toutes les couches, la pilule du groupe affiché, Pente |
///   Revêtement, « Profil du groupe sélectionné » ([profileTitle]) ; ni
///   « GPS » ni « Détails » (le « GPS » est sur la carte de son groupe), ni
///   légende — le groupe affiché se choisit par sa carte de groupe (KIT §8).
///
/// Rien n'est rendu sans parcours à montrer ([shows]). Aucune requête de
/// plus : la géométrie vient du lot de la carte, la météo de l'appelant.
class RideRouteSection extends ConsumerStatefulWidget {
  const RideRouteSection({
    super.key,
    required this.rideKey,
    required this.ride,
    this.group,
    this.groupOnly = true,
    this.weatherLeg,
    this.weatherAttribution,
    this.cursorDistance,
    this.colorByKey,
    this.windChipKey,
    this.profileColorByKey,
    this.mapKey,
    this.actions = true,
    this.profileTitle,
  });

  final RideKey rideKey;
  final RideDto ride;

  /// Le groupe dont la section montre le parcours et les chiffres : celui de
  /// la page, ou le groupe unique d'une sortie solo ; `null` pour une sortie
  /// sans groupe.
  final RideGroupDto? group;

  /// La carte ne dessine que le parcours de [group] (la page d'un groupe) ;
  /// faux : toutes les couches de la sortie.
  final bool groupOnly;

  /// Le leg météo de [group], `null` sans prévision chargée : il propose le
  /// mode « Météo » de la carte (ledgers `MOB-91`, `MOB-94`).
  final WeatherLegDto? weatherLeg;

  /// Le crédit des prévisions, porté par la légende du mode « Météo ».
  final WeatherAttributionDto? weatherAttribution;

  /// Le réticule d'un point de la frise météo, en mètres chaînés (ledger
  /// `MOB-93`) ; `null` : aucun.
  final double? cursorDistance;

  /// La clé de l'interrupteur sous la carte ; `keys.rideGroup.mapColorBy`
  /// par défaut.
  final Key? colorByKey;

  /// La clé de la puce « Météo » d'une carte à plusieurs couches.
  final Key? windChipKey;

  /// La clé de l'interrupteur propre au profil, quand la carte garde une
  /// couleur par couche.
  final Key? profileColorByKey;

  /// Posée sur la carte : l'ancre d'un défilement qui la remonte à l'écran
  /// (le réticule d'un point de la frise météo, ledger `MOB-134`).
  final Key? mapKey;

  /// « GPS » et « Détails » sous le profil.
  final bool actions;

  /// L'en-tête du profil ; « Profil » par défaut.
  final String? profileTitle;

  /// Le parcours que la section montre : celui de [group] quand la carte ne
  /// montre que lui, sinon celui sélectionné sur la carte de la sortie.
  static String? routeSlugOf(
    WidgetRef ref,
    RideKey rideKey,
    RideDto ride,
    RideGroupDto? group, {
    bool groupOnly = true,
  }) {
    if (groupOnly && group != null) return effectiveRouteSlug(ride, group);
    return resolvedRideRouteSlug(ref, rideKey, ride);
  }

  /// La section a-t-elle un parcours à montrer ?
  static bool shows(
    RideDto ride,
    RideGroupDto? group, {
    bool groupOnly = true,
  }) {
    if (groupOnly && group != null) {
      return effectiveRouteSlug(ride, group) != null;
    }
    return rideRouteLayers(ride).isNotEmpty || ride.routeSlug != null;
  }

  @override
  ConsumerState<RideRouteSection> createState() => _RideRouteSectionState();
}

class _RideRouteSectionState extends ConsumerState<RideRouteSection>
    with GpsExportRunner<RideRouteSection> {
  @override
  Widget build(BuildContext context) {
    final RideDto ride = widget.ride;
    final RideGroupDto? group = widget.group;
    if (!RideRouteSection.shows(ride, group, groupOnly: widget.groupOnly)) {
      return const SizedBox.shrink();
    }
    final RideKey rideKey = widget.rideKey;
    final RideGroupDto? onlyGroup = widget.groupOnly ? group : null;
    final String? routeSlug = RideRouteSection.routeSlugOf(
      ref,
      rideKey,
      ride,
      group,
      groupOnly: widget.groupOnly,
    );

    // L'interrupteur unique de la carte et du profil (ledger `MOB-105`).
    final bool likeRoute = rideMapColorsLikeRoute(ride, onlyGroup);
    final List<RouteColorBy> modes = rideMapColorModes(
      ref,
      rideKey: rideKey,
      ride: ride,
      onlyGroup: onlyGroup,
      weatherLeg: widget.weatherLeg,
    );
    final RouteColorBy colorBy = resolveRouteColorBy(
      ref.watch(rideMapColorModeProvider(rideKey)),
      modes,
    );

    const EdgeInsets side = EdgeInsets.symmetric(
      horizontal: PdlSpacing.section,
    );

    return DetailSection(
      title: 'rides.routeSection.title'.tr(),
      bleed: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KeyedSubtree(
            key: widget.mapKey,
            child: RideGroupsMap(
              rideKey: rideKey,
              ride: ride,
              onlyGroup: onlyGroup,
              weatherLeg: widget.weatherLeg,
              weatherAttribution: widget.weatherAttribution,
              cursorDistance: widget.cursorDistance,
            ),
          ),
          if (likeRoute && modes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                PdlSpacing.chipGap,
                PdlSpacing.section,
                0,
              ),
              child: RouteColorModeSwitch(
                key: widget.colorByKey ?? keys.rideGroup.mapColorBy,
                modes: modes,
                value: colorBy,
                onChanged: (RouteColorBy v) =>
                    ref.read(rideMapColorModeProvider(rideKey).notifier).state =
                        v,
              ),
            )
          else if (!likeRoute && modes.contains(RouteColorBy.wind))
            // Le vent sur le parcours du groupe d'une sortie solo à deux
            // parcours (ledger `MOB-94`) : la carte n'a que ce mode-là.
            Padding(
              padding: const EdgeInsets.only(top: PdlSpacing.chipGap),
              child: WeatherMapChip(
                chipKey: widget.windChipKey ?? keys.ride.windMapChip,
                selected: colorBy == RouteColorBy.wind,
                onChanged: (bool on) => setRideMapWindMode(ref, rideKey, on),
              ),
            ),
          if (routeSlug != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                PdlSpacing.section,
                PdlSpacing.section,
                0,
              ),
              child: RideElevationSection(
                teamSlug: ride.team.slug,
                rideSlug: ride.slug,
                routeSlug: routeSlug,
                distance: group?.distance,
                elevationGain: group?.elevationGain,
                // Une carte colorée comme un parcours : le profil suit son
                // interrupteur. Sinon, le profil a le sien, à lui seul.
                colorBy: likeRoute ? colorBy : null,
                profileColorByKey: widget.profileColorByKey,
                // Le vent sous le profil, en mode Météo (ledger `MOB-106`).
                windLeg: likeRoute && colorBy == RouteColorBy.wind
                    ? widget.weatherLeg
                    : null,
                detailLayout: true,
                detailTitle: widget.profileTitle,
              ),
            ),
            Padding(
              padding: side,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ...gpsExportBanners(gapBefore: true),
                  if (widget.actions) ...<Widget>[
                    const SizedBox(height: PdlSpacing.chipGap),
                    _actions(ride, group, routeSlug),
                  ],
                  ..._waypoints(ride, routeSlug),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// « GPS » et « Détails ».
  Widget _actions(RideDto ride, RideGroupDto? group, String routeSlug) {
    final RideKey rideKey = widget.rideKey;
    // Les parcours sont déjà chargés en lot pour la carte : leurs fichiers
    // GPX/FIT viennent de là, sans appel de plus.
    final RouteDetailDto? route = ref.watch(
      rideRouteGeometriesProvider(rideKey)
          .select((RideRouteGeometriesState s) => s.geometries[routeSlug]),
    );
    final GpsExportTarget target = gpsTargetOfGroup(
      subtitle: group == null
          ? ride.name
          : gpsSubtitleOfGroup(group, ref.watch(unitSystemProvider)),
      teamSlug: ride.team.slug,
      routeSlug: routeSlug,
      route: route,
    );
    return Wrap(
      spacing: PdlSpacing.chipGap,
      runSpacing: PdlSpacing.badgeGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (target.offered(watchGpsServices()))
          GpsButton(
            key: keys.rideGroup.gps,
            compact: true,
            loading: gpsExporting,
            onPressed: (BuildContext button) => openGpsSheet(target, button),
          ),
        PdlButton(
          key: keys.rideRoute.details,
          label: 'common.details'.tr(),
          icon: PdlIcons.route,
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          onPressed: () => context.push(Paths.route(ride.team.slug, routeSlug)),
        ),
      ],
    );
  }

  /// « Points du parcours », replié — seulement sur une carte d'un seul
  /// parcours (KIT §8).
  List<Widget> _waypoints(RideDto ride, String routeSlug) {
    final bool single = widget.groupOnly || rideRouteLayers(ride).length <= 1;
    if (!single) return const <Widget>[];
    final RideKey rideKey = widget.rideKey;
    final List<WaypointDto> waypoints =
        ref
            .watch(
              rideRouteGeometryProvider(
                RouteRef(
                  teamSlug: ride.team.slug,
                  rideSlug: rideKey.rideSlug,
                  routeSlug: routeSlug,
                ),
              ),
            )
            .value
            ?.waypoints ??
        const <WaypointDto>[];
    if (waypoints.isEmpty) return const <Widget>[];
    final WaypointSelectionController selection = ref.watch(
      rideWaypointSelectionProvider(rideKey),
    );
    return <Widget>[
      const SizedBox(height: PdlSpacing.chipGap),
      PdlDisclosure(
        key: keys.rideRoute.waypoints,
        title: 'routes.waypoints.title'.tr(),
        subtitles: <String>['routes.waypoints.count'.plural(waypoints.length)],
        child: RouteWaypointsSection(
          waypoints: waypoints,
          selection: selection,
          showHeader: false,
          onSelect: (String key, WaypointDto _) =>
              selection.select(key, move: PdlWaypointMove.center),
        ),
      ),
    ];
  }
}
