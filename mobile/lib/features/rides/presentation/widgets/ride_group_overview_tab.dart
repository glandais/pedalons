import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/ride_group_tab.dart';
import '../../providers/ride_detail_provider.dart';
import 'ride_elevation_section.dart';
import 'ride_group_leader_row.dart';
import 'ride_group_route_actions.dart';
import 'ride_group_stats.dart';
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
              RideGroupStats(ride: ride, group: group, leg: widget.leg),
              if (RideGroupLeaderRow.shows(group)) ...<Widget>[
                const SizedBox(height: PdlSpacing.section),
                RideGroupLeaderRow(group: group),
              ],
              if (RideGroupWeatherLine.shows(widget.leg)) ...<Widget>[
                const SizedBox(height: PdlSpacing.section),
                _weatherSummary(units),
              ],
              const SizedBox(height: PdlSpacing.section),
              _participants(currentUserId),
              if (routeSlug != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.section),
                RideGroupRouteActions(
                  rideKey: widget.rideKey,
                  teamSlug: ride.team.slug,
                  routeSlug: routeSlug,
                  onDownload: downloadRouteAsset,
                  onSendToDevice: (List<GpsServiceConnectionDto> services) =>
                      sendRouteToDevice(ride.team.slug, routeSlug, services),
                ),
              ],
            ],
          ),
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
              semanticLabel: 'rides.participants'.plural(
                group.countParticipants,
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
}
