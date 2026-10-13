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
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/group_start.dart';
import '../../domain/ride_group_tab.dart';
import '../../domain/ride_weather_display.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import 'ride_elevation_section.dart';
import 'ride_group_route_actions.dart';
import 'ride_group_weather_line.dart';
import 'ride_groups_map.dart';

/// L'onglet Aperçu de la page d'un groupe (ledger `MOB-67`).
///
/// La carte du parcours du groupe et son profil, les chiffres (départ et
/// arrivée estimée, allure, distance, dénivelé positif), le meneur quand il
/// y en a un, le résumé météo qui ouvre l'onglet Météo, les visages inscrits
/// qui ouvrent l'onglet Participants, et l'export du parcours.
class RideGroupOverviewTab extends ConsumerStatefulWidget {
  const RideGroupOverviewTab({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.group,
    required this.leg,
    required this.onOpenTab,
    required this.onSelectGroup,
  });

  final RideKey rideKey;
  final RideDto ride;
  final RideGroupDto group;

  /// Le leg météo de ce groupe, `null` sans prévision chargée.
  final WeatherLegDto? leg;

  final ValueChanged<RideGroupTab> onOpenTab;

  /// Un autre tracé touché sur la carte : la page passe à son groupe.
  final ValueChanged<String> onSelectGroup;

  @override
  ConsumerState<RideGroupOverviewTab> createState() =>
      _RideGroupOverviewTabState();
}

class _RideGroupOverviewTabState extends ConsumerState<RideGroupOverviewTab>
    with RouteExportRunner<RideGroupOverviewTab> {
  @override
  Widget build(BuildContext context) {
    final RideDto ride = widget.ride;
    final RideGroupDto group = widget.group;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    final String? routeSlug = group.routeSlug ?? ride.routeSlug;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (routeSlug != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.section),
          RideGroupsMap(
            rideKey: widget.rideKey,
            ride: ride,
            selectedGroupId: group.id,
            onSelect: widget.onSelectGroup,
          ),
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
              distance: group.distance,
              elevationGain: group.elevationGain,
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.section,
            PdlSpacing.section,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ...exportBanners(),
              _stats(units),
              if (group.leader != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.section),
                _leader(group.leader!, currentUserId),
              ],
              if (RideGroupWeatherLine.shows(widget.leg)) ...<Widget>[
                const SizedBox(height: PdlSpacing.section),
                _weatherSummary(units),
              ],
              const SizedBox(height: PdlSpacing.section),
              _participants(currentUserId),
              if (routeSlug != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.section),
                _route(routeSlug),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Les chiffres ────────────────────────────────────────────────────────
  Widget _stats(UnitSystem units) {
    final PdlTypography t = context.pdlText;
    final RideDto ride = widget.ride;
    final RideGroupDto group = widget.group;
    final WeatherLegDto? leg = widget.leg;
    final WeatherStatus? legStatus = leg == null
        ? null
        : WeatherStatus.fromJson(leg.status);
    // L'arrivée estimée n'a de sens que pour un leg prévu.
    final String? arrival =
        leg != null &&
            (legStatus == WeatherStatus.ok || legStatus == WeatherStatus.stale)
        ? 'rides.groupPage.stats.arrival'.tr(
            namedArgs: <String, String>{
              'time': formatWeatherTime(leg.arrivalTime, ride.timezone),
            },
          )
        : null;

    Widget cell(String label, String value, {List<Widget> extra = const []}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: t.xs),
            const SizedBox(height: 2),
            Text(value, style: t.statBigValue),
            ...extra,
          ],
        );

    final List<Widget> cells = <Widget>[
      // L'heure du groupe se lit dans le fuseau de la sortie, et se situe
      // par rapport à elle (docs/LEDGER_*.md API-60).
      cell(
        'rides.groupPage.stats.departure'.tr(),
        formatGroupStart(group.startAt, ride.timezone),
        extra: <Widget>[
          Text(
            groupStartRelation(group.startAt, ride.dateTime).labelKey.tr(),
            style: t.xs,
          ),
          ?ZoneMentionLine.maybe(group.startAt, ride.timezone),
          if (arrival != null) Text(arrival, style: t.xs),
        ],
      ),
      if (group.averageSpeed != null)
        cell(
          'rides.groupPage.stats.pace'.tr(),
          AppFormatters.formatSpeed(group.averageSpeed!, units),
        ),
      if (group.distance != null)
        cell(
          'rides.groupPage.stats.distance'.tr(),
          AppFormatters.formatDistance(group.distance!, units),
        ),
      if (group.elevationGain != null)
        cell(
          'rides.groupPage.stats.elevation'.tr(),
          AppFormatters.formatElevation(group.elevationGain!, units),
        ),
    ];

    return PdlCard(
      flat: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Deux colonnes tant qu'elles restent lisibles, une au-delà.
          final bool twoColumns =
              constraints.maxWidth >= 320 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          if (!twoColumns) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < cells.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: PdlSpacing.meta2V),
                  cells[i],
                ],
              ],
            );
          }
          return Wrap(
            spacing: PdlSpacing.meta2H,
            runSpacing: PdlSpacing.meta2V,
            children: <Widget>[
              for (final Widget c in cells)
                SizedBox(
                  width:
                      (constraints.maxWidth - PdlSpacing.meta2H) / 2 -
                      PdlSpacing.card,
                  child: c,
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Le meneur ───────────────────────────────────────────────────────────
  /// Rendu **seulement** si l'API en désigne un : `leader` nul est le cas
  /// courant, et il n'y a jamais de repli sur le créateur de la sortie.
  Widget _leader(PublicUserDto leader, String? currentUserId) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Row(
      key: keys.rideGroup.leader,
      children: <Widget>[
        PdlAvatar(
          name: leader.displayName,
          imageUrl: leader.avatarUrl,
          size: 32,
          isCurrentUser: leader.id == currentUserId,
        ),
        const SizedBox(width: PdlSpacing.chipGap),
        Flexible(
          child: Text(
            leader.displayName,
            style: t.bodyStrong,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: PdlSpacing.chipGap),
        PdlBadge(
          label: 'rides.groupPage.leader'.tr(),
          tone: PdlDerivedTones.registered(c),
          icon: PdlIcons.leader,
        ),
      ],
    );
  }

  // ── Le résumé météo ─────────────────────────────────────────────────────
  Widget _weatherSummary(UnitSystem units) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return PdlCard(
      key: keys.rideGroup.weatherSummaryCard,
      flat: true,
      onTap: () => widget.onOpenTab(RideGroupTab.weather),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('rides.groupPage.weatherSummary'.tr(), style: t.xs),
              ),
              Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
            ],
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          RideGroupWeatherLine(
            leg: widget.leg,
            timezone: widget.ride.timezone,
            units: units,
          ),
        ],
      ),
    );
  }

  // ── Les participants ────────────────────────────────────────────────────
  Widget _participants(String? currentUserId) {
    final PdlTypography t = context.pdlText;
    final RideGroupDto group = widget.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'rides.groupPage.participantsTitle'.tr(),
          count: '${group.countParticipants}',
          padding: const EdgeInsets.only(bottom: PdlSpacing.chipGap),
        ),
        if (group.participants.isEmpty)
          Text('participants.emptyMessage'.tr(), style: t.sub)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: PdlAvatarStack(
              people: <PdlAvatarEntry>[
                for (final PublicUserDto p in group.participants)
                  PdlAvatarEntry(
                    name: p.displayName,
                    imageUrl: p.avatarUrl,
                    isCurrentUser: p.id == currentUserId,
                  ),
              ],
              total: group.countParticipants,
              onTap: () => widget.onOpenTab(RideGroupTab.participants),
              semanticLabel: 'rides.participants'.tr(
                namedArgs: <String, String>{
                  'count': '${group.countParticipants}',
                },
              ),
            ),
          ),
        if (group.countParticipants > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: PdlButton(
              key: keys.rideGroup.viewAllParticipants,
              label: 'rides.groupPage.viewAllParticipants'.tr(),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              icon: PdlIcons.chevronRight,
              onPressed: () => widget.onOpenTab(RideGroupTab.participants),
            ),
          ),
      ],
    );
  }

  // ── Le parcours du groupe ───────────────────────────────────────────────
  Widget _route(String routeSlug) {
    final RideDto ride = widget.ride;
    // Les parcours sont déjà chargés en lot pour la carte : leurs assets
    // GPX/FIT viennent de là, sans appel de plus.
    final RouteDetailDto? route = ref.watch(
      rideRouteGeometriesProvider(
        widget.rideKey,
      ).select((RideRouteGeometriesState s) => s.geometries[routeSlug]),
    );
    final List<GpsServiceConnectionDto> services = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.connectedServices ?? const [],
      ),
    );
    final AssetDto? gpx = route?.media.assets.gpx;
    final AssetDto? fit = route?.media.assets.fit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'rides.groupPage.routeTitle'.tr(),
          padding: const EdgeInsets.only(bottom: PdlSpacing.badgeGap),
        ),
        Wrap(
          spacing: PdlSpacing.badgeGap,
          children: <Widget>[
            PdlButton(
              label: 'rides.viewRoute'.tr(),
              icon: PdlIcons.route,
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () =>
                  context.push(Paths.route(ride.team.slug, routeSlug)),
            ),
            if (gpx != null)
              PdlButton(
                key: keys.rideGroup.exportGpx,
                label: 'routes.exportGpx'.tr(),
                icon: PdlIcons.gpx,
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () => downloadRouteAsset(gpx),
              ),
            if (fit != null)
              PdlButton(
                key: keys.rideGroup.exportFit,
                label: 'routes.exportFit'.tr(),
                icon: PdlIcons.gpx,
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () => downloadRouteAsset(fit),
              ),
            if (services.isNotEmpty)
              PdlButton(
                key: keys.rideGroup.sendToDevice,
                label: 'routes.sendToDevice'.tr(),
                icon: PdlIcons.device,
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () =>
                    sendRouteToDevice(ride.team.slug, routeSlug, services),
              ),
          ],
        ),
      ],
    );
  }
}
