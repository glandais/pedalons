import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../participants/presentation/widgets/participants_sheet.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_registration_controller.dart';
import 'registration_failure_banner.dart';
import 'ride_group_leader_row.dart';
import 'ride_group_route_actions.dart';
import 'ride_group_stats.dart';
import '../../domain/group_title.dart';

/// Le groupe d'une sortie **solo** — un seul groupe —, à la place de la
/// section Groupes du détail (ledger `MOB-69`).
///
/// La page de la sortie est alors aussi celle de son groupe : il n'y a ni
/// carte de groupe, ni chevron, ni lien vers la page du groupe. On y trouve,
/// repris de l'Aperçu de cette page sans les dupliquer : le nom du groupe et
/// la couleur de son tracé, les chiffres (départ, arrivée estimée, allure,
/// distance, D+), le meneur **seulement** s'il est désigné, les visages
/// inscrits qui ouvrent la liste, et les actions du parcours. L'inscription
/// est dans la barre d'action du détail (`RideGroupActionBar`), la météo du
/// leg dans la carte météo (`RideWeatherCard`).
class RideSoloGroupSection extends ConsumerStatefulWidget {
  const RideSoloGroupSection({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.group,
    required this.leg,
    this.onViewTeam,
  });

  final RideKey rideKey;
  final RideDto ride;
  final RideGroupDto group;

  /// Le leg météo du groupe, `null` sans prévision chargée.
  final WeatherLegDto? leg;

  /// « Voir l'équipe » du bandeau d'échec d'un non-membre.
  final VoidCallback? onViewTeam;

  @override
  ConsumerState<RideSoloGroupSection> createState() =>
      _RideSoloGroupSectionState();
}

class _RideSoloGroupSectionState extends ConsumerState<RideSoloGroupSection>
    with RouteExportRunner<RideSoloGroupSection> {
  /// Le bandeau d'échec, que l'on fait défiler dans la vue : « Rejoindre »
  /// est dans la barre d'action, collée en bas, et cette section peut être
  /// loin sous le pli — sans ce défilement, un refus ne se verrait pas.
  final GlobalKey _failureAnchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    ref.listen<RegistrationFailure?>(
      rideRegistrationProvider(
        widget.rideKey,
      ).select((RideRegistrationState s) => s.failure),
      (RegistrationFailure? previous, RegistrationFailure? next) {
        if (next == null || identical(previous, next)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final BuildContext? anchor = _failureAnchor.currentContext;
          if (!mounted || anchor == null) return;
          Scrollable.ensureVisible(
            anchor,
            duration: PdlMotion.stateChange,
            curve: PdlMotion.stateChangeCurve,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        });
      },
    );
    final RideDto ride = widget.ride;
    final RideGroupDto group = widget.group;
    final String? routeSlug = group.routeSlug ?? ride.routeSlug;
    final RideRegistrationState registration = ref.watch(
      rideRegistrationProvider(widget.rideKey),
    );
    final RideRegistrationController controller = ref.read(
      rideRegistrationProvider(widget.rideKey).notifier,
    );

    return Column(
      key: keys.ride.soloGroupSection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(),
        const SizedBox(height: PdlSpacing.chipGap),
        if (registration.failure != null) ...<Widget>[
          KeyedSubtree(
            key: _failureAnchor,
            child: registrationFailureBanner(
              registration.failure!,
              controller,
              onViewTeam: widget.onViewTeam,
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...exportBanners(),
        RideGroupStats(ride: ride, group: group, leg: widget.leg),
        if (RideGroupLeaderRow.shows(group)) ...<Widget>[
          const SizedBox(height: PdlSpacing.section),
          RideGroupLeaderRow(group: group),
        ],
        if (group.participants.isNotEmpty) ...<Widget>[
          const SizedBox(height: PdlSpacing.section),
          _participants(),
        ],
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
    );
  }

  /// « Groupe X », précédé de la couleur de son tracé — la même que sur la
  /// carte et que sur la carte d'un groupe. Un bloc, pas un lien.
  Widget _header() {
    final PdlTypography t = context.pdlText;
    return Row(
      key: keys.ride.soloGroupHeader,
      children: <Widget>[
        PdlColorTrack(color: multiTrackColor(widget.group.sortOrder)),
        const SizedBox(width: PdlSpacing.chipGap),
        Expanded(
          child: Text(
            groupTitle(widget.group.name, 'rides.groupPage.title'.tr()),
            style: t.sectionTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Les visages inscrits du groupe, qui ouvrent sa feuille de
  /// participants, déjà cherchable. Pas de second bouton « Voir tous les
  /// participants » : le bloc méta porte déjà « Voir la liste », vers les
  /// mêmes personnes — un seul groupe, ce sont celles de la sortie.
  Widget _participants() {
    final RideDto ride = widget.ride;
    final RideGroupDto group = widget.group;
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: PdlAvatarStack(
        key: keys.ride.soloGroupParticipants,
        people: <PdlAvatarEntry>[
          for (final PublicUserDto p in group.participants)
            PdlAvatarEntry(
              name: p.displayName,
              imageUrl: p.avatarUrl,
              isCurrentUser: p.id == currentUserId,
            ),
        ],
        total: group.countParticipants,
        onTap: () => ParticipantsSheet.open(context, ride, group),
        semanticLabel: 'rides.participants'.tr(
          namedArgs: <String, String>{'count': '${group.countParticipants}'},
        ),
      ),
    );
  }
}
