import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../routes/presentation/gps_export_runner.dart';
import '../../domain/group_start.dart';
import '../../domain/ride_group_action.dart';
import '../../domain/ride_route_layers.dart';
import '../../domain/ride_weather_display.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../providers/ride_registration_controller.dart';
import 'registration_failure_banner.dart';
import 'ride_group_card.dart';
import 'ride_group_route_actions.dart';
import 'ride_registration_control.dart';

/// Combien de groupes sont montrés avant le repli.
///
/// La maquette en montre quatre puis « Voir les N autres groupes » : dix
/// groupes de quatre lignes pleines font plus de trois écrans, et le lecteur
/// perd la carte et le profil qui les surplombent.
const int _kCollapsedGroupCount = 4;

/// La section « Groupes » d'une sortie à plusieurs groupes (ledger
/// `MOB-134`, lot 8, KIT §8, maquettes `sortie-groupes-meme-heure-mobile-cible`,
/// `sortie-groupes-heures-differentes-mobile-cible`) : le titre et son compte
/// (« 3 groupes »), le bandeau d'échec, **ma** carte en tête, « Autres
/// groupes », les autres cartes, « Voir les N autres groupes », puis « Voir
/// les 31 personnes inscrites » ([onShowRideParticipants]).
///
/// C'est ici que se joue l'inscription : chaque carte porte son contrôle,
/// jugé sur le départ de **son** groupe (`rideRegistrationControlAction`,
/// ledger `API-170`) — un groupe plus tardif reste joignable quand le premier
/// est parti. Inscrite ailleurs, une carte ouverte offre « Changer pour A »,
/// un seul appel (`switchGroup`, ledger `API-171`) ; la sienne, « Quitter le
/// groupe » en pied de carte et le bouton « GPS ». Aucune confirmation.
class RideGroupsSection extends ConsumerStatefulWidget {
  const RideGroupsSection({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.selectedRouteSlug,
    required this.onSelect,
    this.weather,
    this.onOpenGroup,
    this.onShowParticipants,
    this.onShowRideParticipants,
    this.onViewTeam,
    this.now,
  });

  final RideKey rideKey;
  final RideDto ride;

  /// Le parcours sélectionné de l'écran : toutes les cartes des groupes qui le
  /// roulent s'allument, pas seulement celle du groupe courant. `null`, ou un
  /// parcours que personne ne roule (le principal), n'allume aucune carte.
  final String? selectedRouteSlug;
  final ValueChanged<String> onSelect;

  /// La prévision de la sortie, lue par l'écran (`null` : pas demandée, ou
  /// pas encore là) : le leg de chaque groupe donne sa ligne météo.
  final RideWeatherDto? weather;

  /// Ouvre la page du groupe (ledger `MOB-67`) : toute la carte y mène. Sans
  /// lui, un appui ne fait que sélectionner le groupe.
  final ValueChanged<RideGroupDto>? onOpenGroup;

  /// Les visages d'une carte : la feuille des personnes de ce groupe.
  final ValueChanged<RideGroupDto>? onShowParticipants;

  /// « Voir les 31 personnes inscrites », sous les cartes : la feuille des
  /// personnes de toute la sortie. `null` : pas de lien (qui ne voit pas les
  /// noms n'a que les comptes).
  final VoidCallback? onShowRideParticipants;
  final VoidCallback? onViewTeam;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  ConsumerState<RideGroupsSection> createState() => _RideGroupsSectionState();
}

class _RideGroupsSectionState extends ConsumerState<RideGroupsSection>
    with GpsExportRunner<RideGroupsSection> {
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
      rideRouteGeometriesProvider(widget.rideKey)
          .select((RideRouteGeometriesState s) => s.geometries),
    );
    final List<GpsServiceConnectionDto> services = watchGpsServices();
    final RideWeatherDto? weather = widget.weather;
    final bool showDeparture = someGroupLeavesAtOwnTime(
      ride.groups.map((RideGroupDto g) => g.startAt),
      ride.dateTime,
    );

    final List<RideGroupDto> shown = _expanded
        ? groups
        : groups.take(_kCollapsedGroupCount).toList();
    final int hidden = groups.length - shown.length;
    // L'échec se dit dans la carte du groupe concerné (règle R6, KIT §9) ;
    // en tête de section seulement si cette carte est repliée.
    final RegistrationFailure? failure = registration.failure;
    final bool failureInCard =
        failure != null &&
        shown.any((RideGroupDto g) => g.id == failure.groupId);
    final int people = ride.participantCount;

    return DetailSection(
      key: keys.ride.groupsSection,
      title: 'rides.groups'.tr(),
      count: 'rides.groupCount'.plural(groups.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (failure != null && !failureInCard) ...<Widget>[
            registrationFailureBanner(
              failure,
              controller,
              onViewTeam: widget.onViewTeam,
            ),
            const SizedBox(height: PdlSpacing.feedGap),
          ],
          ...gpsExportBanners(),
          for (final (int i, RideGroupDto group) in shown.indexed) ...<Widget>[
            if (registered != null && i == 1) ...<Widget>[
              const SizedBox(height: PdlSpacing.feedGap),
              Text('rides.otherGroupsLabel'.tr(), style: context.pdlText.count),
              const SizedBox(height: PdlSpacing.feedGap),
            ],
            _groupCard(
              group: group,
              ride: ride,
              route: routes[group.routeSlug ?? ride.routeSlug],
              services: services,
              registration: registration,
              controller: controller,
              currentUserId: currentUserId,
              units: units,
              showDeparture: showDeparture,
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
          if (widget.onShowRideParticipants != null && people > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PdlButton(
                key: keys.ride.participantsButton,
                label: 'rides.groupPage.viewParticipantsCount'.plural(people),
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                icon: PdlIcons.chevronRight,
                onPressed: widget.onShowRideParticipants,
              ),
            ),
        ],
      ),
    );
  }

  Widget _groupCard({
    required RideGroupDto group,
    required RideDto ride,
    required RouteDetailDto? route,
    required List<GpsServiceConnectionDto> services,
    required RideRegistrationState registration,
    required RideRegistrationController controller,
    required String? currentUserId,
    required UnitSystem units,
    required bool showDeparture,
    required WeatherLegDto? weatherLeg,
  }) {
    final String? routeSlug = group.routeSlug ?? ride.routeSlug;
    // Jusqu'à la fin de la sortie — son arrivée estimée, pas son départ —,
    // « GPS » et « Quitter le groupe » restent sur la carte de son groupe
    // (règles R6 et R7, KIT §9) ; une fois la sortie terminée, ni l'un ni
    // l'autre. Le badge « J'y vais » reste.
    final RideGroupAction action = rideGroupCardAction(
      ride: ride,
      group: group,
      canRegister: ride.permissions.canRegister ?? false,
      now: widget.now,
    );
    final RegistrationFailure? failure = registration.failure;
    // « GPS » sur la carte de son groupe seulement (KIT §8) : les autres
    // parcours se prennent sur la page de leur groupe.
    final GpsExportTarget? gps =
        rideGroupCardOffersGps(ride, group, now: widget.now)
        ? gpsTargetOfGroup(
            subtitle: gpsSubtitleOfGroup(group, units),
            teamSlug: ride.team.slug,
            routeSlug: routeSlug,
            route: route,
          )
        : null;

    return RideGroupCard(
      key: keys.ride.group(group.id),
      group: group,
      rideDateTime: ride.dateTime,
      timezone: ride.timezone,
      showDeparture: showDeparture,
      // Chaque groupe jugé sur son départ, et l'appartenance inconnue ne
      // propose rien — les règles du contrôle de la page d'un groupe.
      action: action,
      // La couleur de son parcours : les groupes qui le partagent portent la
      // même, celle de leur trace commune.
      trackColor: multiTrackColor(groupTrackColorIndex(ride, group)),
      units: units,
      selected: routeSlug != null && routeSlug == widget.selectedRouteSlug,
      pending: registration.pendingGroupId == group.id,
      currentUserId: currentUserId,
      weatherLeg: weatherLeg,
      onTap: widget.onOpenGroup == null
          ? () => widget.onSelect(group.id)
          : () => widget.onOpenGroup!(group),
      onJoin: () => controller.join(group.id),
      onSwitch: () => controller.switchGroup(group.id),
      onLeave: () => controller.leave(group.id),
      onShowParticipants: widget.onShowParticipants == null
          ? null
          : () => widget.onShowParticipants!(group),
      onOpenGps: gps != null && gps.offered(services)
          ? (BuildContext button) => openGpsSheet(gps, button, tag: group.id)
          : null,
      gpsLoading: gpsExportingFor(group.id),
      failure: failure != null && failure.groupId == group.id
          ? registrationFailureNotice(
              failure,
              controller,
              onViewTeam: widget.onViewTeam,
            )
          : null,
    );
  }
}
