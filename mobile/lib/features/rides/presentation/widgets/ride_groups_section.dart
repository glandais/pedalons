import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/ride_group_action.dart';
import '../../domain/ride_weather_display.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../providers/ride_registration_controller.dart';
import '../../providers/ride_weather_provider.dart';
import 'registration_failure_banner.dart';
import 'ride_group_route_actions.dart';
import 'ride_group_card.dart';
import '../../../../keys.dart';

/// Combien de groupes sont montrés avant le repli.
///
/// La maquette en montre quatre puis « Voir les N autres groupes » : dix
/// groupes de quatre lignes pleines font plus de trois écrans, et le lecteur
/// perd la carte et le profil qui les surplombent.
const int _kCollapsedGroupCount = 4;

/// La section « Groupes » de l'écran 12 — compteur, bandeau d'échec, cartes.
///
/// C'est ici que se joue l'inscription : le choix de groupe **est** la liste de
/// cartes, il n'y a plus ni `AlertDialog`, ni bouton d'action global en bas
/// d'écran qui ne dirait pas dans quel groupe il inscrit.
class RideGroupsSection extends ConsumerStatefulWidget {
  const RideGroupsSection({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.isMember,
    required this.selectedGroupId,
    required this.onSelect,
    this.onOpenGroup,
    this.onShowParticipants,
    this.onViewTeam,
  });

  final RideKey rideKey;
  final RideDto ride;

  /// `null` quand l'appartenance n'est pas encore connue : on laisse alors
  /// l'API trancher au premier appel plutôt que de masquer les boutons à un
  /// membre.
  final bool? isMember;

  final String? selectedGroupId;
  final ValueChanged<String> onSelect;

  /// Ouvre la page du groupe (ledger `MOB-67`) : toute la carte y mène. Sans
  /// lui, un appui ne fait que sélectionner le groupe.
  final ValueChanged<RideGroupDto>? onOpenGroup;

  final ValueChanged<RideGroupDto>? onShowParticipants;
  final VoidCallback? onViewTeam;

  @override
  ConsumerState<RideGroupsSection> createState() => _RideGroupsSectionState();
}

class _RideGroupsSectionState extends ConsumerState<RideGroupsSection>
    with RouteExportRunner<RideGroupsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final RideDto ride = widget.ride;
    // Le groupe où l'on est inscrit passe en tête, détaché des autres.
    final RideGroupDto? registered = ride.groups
        .where((RideGroupDto g) => g.id == ride.registeredGroupId)
        .firstOrNull;
    final List<RideGroupDto> groups = <RideGroupDto>[
      ?registered,
      ...ride.groups.where((RideGroupDto g) => g != registered),
    ];

    if (groups.isEmpty) {
      return PdlEmptyState(
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.people,
        title: 'rides.noGroupTitle'.tr(),
        message: 'rides.noGroupMessage'.tr(),
      );
    }

    final RideRegistrationState registration = ref.watch(
      rideRegistrationProvider(widget.rideKey),
    );
    final RideRegistrationController controller = ref.read(
      rideRegistrationProvider(widget.rideKey).notifier,
    );
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    final UnitSystem units = ref.watch(unitSystemProvider);
    // Les parcours des groupes sont déjà chargés en lot pour la carte : leurs
    // assets GPX/FIT viennent de là, sans appel de plus.
    final Map<String, RouteDetailDto> routes = ref.watch(
      rideRouteGeometriesProvider(
        widget.rideKey,
      ).select((RideRouteGeometriesState s) => s.geometries),
    );
    final List<GpsServiceConnectionDto> services = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.connectedServices ?? const [],
      ),
    );

    // La météo de chaque groupe, pour sa ligne non cliquable — partagée avec
    // la carte météo du détail, sans appel de plus. Une sortie terminée ou
    // annulée ne la demande même pas.
    final RideWeatherDto? weather = ride.isPast || ride.isCancelled
        ? null
        : ref.watch(rideWeatherProvider(widget.rideKey)).value;

    // Tant qu'on ne sait pas, on propose : un 403 `FORBIDDEN` répondra, et son
    // bandeau est plus juste qu'un bouton absent sans explication.
    final bool isMember = widget.isMember ?? true;

    final List<RideGroupDto> shown = _expanded
        ? groups
        : groups.take(_kCollapsedGroupCount).toList();
    final int hidden = groups.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'rides.groups'.tr(),
          count: 'rides.groupCount'.plural(groups.length),
          padding: const EdgeInsets.only(bottom: 10),
        ),
        if (registration.failure != null) ...<Widget>[
          registrationFailureBanner(
            registration.failure!,
            controller,
            onViewTeam: widget.onViewTeam,
          ),
          const SizedBox(height: 10),
        ],
        ...exportBanners(),
        for (final RideGroupDto group in shown) ...<Widget>[
          if (registered != null && shown.indexOf(group) == 1) ...<Widget>[
            const SizedBox(height: PdlSpacing.feedGap),
            Text('rides.otherGroupsLabel'.tr(), style: context.pdlText.count),
            const SizedBox(height: PdlSpacing.feedGap),
          ],
          _groupCard(
            group: group,
            ride: ride,
            route: routes[group.routeSlug ?? ride.routeSlug],
            services: services,
            isMember: isMember,
            registration: registration,
            controller: controller,
            currentUserId: currentUserId,
            units: units,
            weatherLeg: weather == null
                ? null
                : weatherLegOfGroup(weather.legs, group.id),
          ),
          const SizedBox(height: PdlSpacing.feedGap),
        ],
        if (hidden > 0)
          PdlButton(
            label: 'rides.otherGroups'.plural(hidden),
            variant: PdlButtonVariant.outline,
            fullWidth: true,
            onPressed: () => setState(() => _expanded = true),
          ),
      ],
    );
  }

  Widget _groupCard({
    required RideGroupDto group,
    required RideDto ride,
    required RouteDetailDto? route,
    required List<GpsServiceConnectionDto> services,
    required bool isMember,
    required RideRegistrationState registration,
    required RideRegistrationController controller,
    required String? currentUserId,
    required UnitSystem units,
    required WeatherLegDto? weatherLeg,
  }) {
    final String? routeSlug = group.routeSlug ?? ride.routeSlug;
    final AssetDto? gpx = route?.media.assets.gpx;
    final AssetDto? fit = route?.media.assets.fit;

    return RideGroupCard(
      key: keys.ride.group(group.id),
      group: group,
      rideDateTime: ride.dateTime,
      timezone: ride.timezone,
      action: rideGroupAction(ride: ride, group: group, isMember: isMember),
      trackColor: multiTrackColor(group.sortOrder),
      units: units,
      selected: group.id == widget.selectedGroupId,
      pending: registration.pendingGroupId == group.id,
      currentUserId: currentUserId,
      weatherLeg: weatherLeg,
      onTap: widget.onOpenGroup == null
          ? () => widget.onSelect(group.id)
          : () => widget.onOpenGroup!(group),
      onJoin: () => controller.join(group.id),
      onLeave: () => controller.leave(group.id),
      onShowParticipants: widget.onShowParticipants == null
          ? null
          : () => widget.onShowParticipants!(group),
      onExportGpx: gpx == null ? null : () => downloadRouteAsset(gpx),
      onExportFit: fit == null ? null : () => downloadRouteAsset(fit),
      onSendToDevice: routeSlug == null || services.isEmpty
          ? null
          : () => sendRouteToDevice(ride.team.slug, routeSlug, services),
    );
  }
}
