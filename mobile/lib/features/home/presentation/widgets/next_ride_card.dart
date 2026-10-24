import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
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
import '../../../../core/utils/api_error_handler.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../rides/presentation/widgets/ride_weather_summary_line.dart';
import '../../../rides/providers/ride_detail_provider.dart';
import '../../../routes/presentation/route_export.dart';
import '../../providers/next_ride_leave_controller.dart';
import '../../../teams/presentation/widgets/publication_card.dart';
import '../../providers/next_ride_provider.dart';
import '../../../../keys.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../rides/domain/group_start.dart';

/// La vignette de « Ma prochaine sortie » : celle du **parcours du groupe**
/// (`docs/LEDGER_*.md API-3`), puisque deux groupes sur deux parcours n'ont pas
/// la même image. Celle de la sortie reste le repli — pas de groupe, groupe
/// sans parcours, ou parcours sans vignette. Chaque niveau préfère la variante
/// du thème courant, puis l'autre.
String? nextRideThumbnailUrl(
  RideDto ride,
  RideGroupDto? group, {
  required bool dark,
}) {
  final String? groupUrl = group == null
      ? null
      : dark
      ? (group.thumbnailDarkUrl ?? group.thumbnailLightUrl)
      : (group.thumbnailLightUrl ?? group.thumbnailDarkUrl);
  return groupUrl ??
      (dark
          ? (ride.thumbnailDarkUrl ?? ride.thumbnailLightUrl)
          : (ride.thumbnailLightUrl ?? ride.thumbnailDarkUrl));
}

/// « Ma prochaine sortie » — la réponse à la question du brief : *qu'est-ce que
/// je fais à vélo cette semaine ?*
///
/// Le bloc **disparaît** quand il n'y a rien à montrer, remplacé par une carte
/// compacte. Il ne reste jamais en place vide : un cadre « aucune sortie » de
/// 400 px en tête d'accueil coûterait la première carte du fil.
class NextRideCard extends ConsumerWidget {
  const NextRideCard({super.key, required this.next});

  final NextRide next;

  RideDto get ride => next.ride;
  RideGroupDto? get group => next.group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final DateTime? at = ride.startsAt;

    final RideKey key = RideKey(teamSlug: ride.team.slug, rideSlug: ride.slug);
    // Pas `rideRegistrationProvider` : il chargerait le détail de la sortie,
    // que la ligne de liste rend inutile (`docs/LEDGER_*.md API-4`).
    final NextRideLeaveState registration = ref.watch(
      nextRideLeaveProvider(key),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('home.nextRide'.tr(), style: t.sectionTitle)),
            if (at != null)
              PdlBadge(
                // L'instant du contrat, pas l'heure murale de la sortie :
                // « dans 2 jours » se compte depuis le lecteur.
                label: AppFormatters.formatRelative(
                  DateTime.parse(ride.dateTime),
                ),
                tone: PdlDerivedTones.registered(c),
                size: PdlBadgeSize.lg,
                icon: PdlIcons.check,
              ),
          ],
        ),
        const SizedBox(height: PdlSpacing.cardTight),
        // Le bandeau d'échec de désinscription vit ici, au-dessus de la carte.
        if (registration.failure != null) ...<Widget>[
          PdlBanner(
            tone: PdlBannerTone.danger,
            title: 'rides.failure.generic'.tr(
              namedArgs: <String, String>{
                'group': registration.failure!.groupName,
              },
            ),
            message: registration.failure!.message,
            onDismiss: ref
                .read(nextRideLeaveProvider(key).notifier)
                .dismissFailure,
            dismissSemanticLabel: 'common.close'.tr(),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
        ],
        PdlCard(
          padding: PdlCardPadding.none,
          onTap: () => context.push(Paths.ride(ride.team.slug, ride.slug)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PdlCardMedia(
                tone: PdlMediaTone.ride,
                icon: PdlIcons.ride,
                imageUrl: nextRideThumbnailUrl(
                  ride,
                  group,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                height: PdlMediaHeights.hero,
                borderRadius: BorderRadius.zero,
              ),
              Padding(
                padding: const EdgeInsets.all(PdlSpacing.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _badges(c),
                    const SizedBox(height: 6),
                    PdlTeamLine(
                      label: ride.team.name,
                      imageUrl: ride.team.logoUrl,
                      onTap: () =>
                          pushLocation(context, Paths.team(ride.team.slug)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.name,
                      style: t.screenTitle.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: PdlSpacing.cardTight),
                    ..._facts(context, c, t, at),
                    const SizedBox(height: PdlSpacing.cardTight),
                    _stats(units),
                    if (RideWeatherSummaryLine.shows(
                      ride.weather,
                      finished: ride.isPast,
                      cancelled: ride.isCancelled,
                    )) ...<Widget>[
                      const SizedBox(height: PdlSpacing.chipGap),
                      RideWeatherSummaryLine(
                        summary: ride.weather,
                        timezone: ride.timezone,
                        finished: ride.isPast,
                        cancelled: ride.isCancelled,
                      ),
                    ],
                    if (group != null) ...<Widget>[
                      const SizedBox(height: PdlSpacing.cardTight),
                      _seats(context, c, t, group!),
                    ],
                    const SizedBox(height: 14),
                    _NextRideActions(
                      ride: ride,
                      group: group,
                      rideKey: key,
                      registration: registration,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badges(PdlColors c) => Wrap(
    spacing: PdlSpacing.badgeGap,
    runSpacing: PdlSpacing.badgeGap,
    children: <Widget>[
      PdlBadge(
        label: 'publicationType.ride'.tr(),
        tone: PublicationType.ride.tone(c),
      ),
      PdlBadge(
        label: 'rides.registered'.tr(),
        tone: PdlDerivedTones.registered(c),
        icon: PdlIcons.check,
      ),
      if (ride.isCancelled)
        PdlBadge(
          label: 'status.cancelled'.tr(),
          tone: Status.cancelled.tone(c),
        ),
    ],
  );

  /// Date, groupe et heure de départ, lieu — les trois faits qui décident si
  /// l'on y va.
  List<Widget> _facts(
    BuildContext context,
    PdlColors c,
    PdlTypography t,
    DateTime? at,
  ) {
    final RideGroupDto? g = group;
    return <Widget>[
      if (at != null)
        _fact(c, t, PdlIcons.date, AppFormatters.formatLongDate(at)),
      if (g != null)
        _fact(
          c,
          t,
          PdlIcons.time,
          !groupLeavesAtOwnTime(g.startAt, ride.dateTime)
              ? g.name
              : 'home.groupDeparture'.tr(
                  namedArgs: <String, String>{
                    'group': g.name,
                    'time': formatGroupStart(g.startAt, ride.timezone),
                  },
                ),
        ),
      // « heure de Tokyo (ven. 01:00 chez vous) » quand le lecteur est
      // ailleurs, au départ qui le concerne (docs/LEDGER_*.md API-60).
      if (ZoneMentionLine.maybe(g?.startAt ?? ride.dateTime, ride.timezone)
          case final Widget mention)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: mention),
      if (ride.startPlace != null) ...<Widget>[
        const SizedBox(height: 10),
        PdlPlaceRow(
          kind: PdlPlaceKind.start,
          name: ride.startPlace!.name,
          address: ride.startPlace!.address,
        ),
      ],
    ];
  }

  Widget _fact(PdlColors c, PdlTypography t, IconData icon, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: c.textDimmed),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: t.statValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  /// Distance et dénivelé viennent du **groupe**, pas de la sortie : deux
  /// groupes d'une même sortie ne roulent pas le même parcours.
  Widget _stats(UnitSystem units) {
    final RideGroupDto? g = group;
    return PdlStatRow(
      stats: <PdlStat>[
        if (g?.distance != null)
          PdlStat(
            value: AppFormatters.formatDistance(g!.distance!, units),
            icon: PdlIcons.distance,
          ),
        if (g?.elevationGain != null)
          PdlStat(
            value: AppFormatters.formatElevation(g!.elevationGain!, units),
            icon: PdlIcons.elevationUp,
            trend: PdlStatTrend.up,
          ),
        PdlStat(
          value: g?.maxParticipants == null
              ? '${ride.participantCount}'
              : '${g!.countParticipants}/${g.maxParticipants}',
          icon: PdlIcons.people,
        ),
      ],
    );
  }

  Widget _seats(
    BuildContext context,
    PdlColors c,
    PdlTypography t,
    RideGroupDto g,
  ) {
    return Row(
      children: <Widget>[
        if (g.participants.isNotEmpty)
          PdlAvatarStack(
            people: <PdlAvatarEntry>[
              for (final PublicUserDto p in g.participants)
                PdlAvatarEntry(name: p.displayName, imageUrl: p.avatarUrl),
            ],
            total: g.countParticipants,
          ),
        if (g.maxParticipants != null) ...<Widget>[
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: PdlProgressBar(
              value: g.countParticipants / g.maxParticipants!,
              semanticLabel: 'rides.participantsOf'.plural(
                g.maxParticipants!,
                namedArgs: <String, String>{
                  'count': '${g.countParticipants}',
                  'max': '${g.maxParticipants}',
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Les actions de la carte : « Voir la sortie », « Se désinscrire », et
/// l'envoi du parcours du groupe vers un compteur connecté.
///
/// À état parce que l'envoi a une issue à dire — succès ou échec, en bandeau
/// persistant sous les boutons, comme sur les cartes de groupe de la sortie.
class _NextRideActions extends ConsumerStatefulWidget {
  const _NextRideActions({
    required this.ride,
    required this.group,
    required this.rideKey,
    required this.registration,
  });

  final RideDto ride;
  final RideGroupDto? group;
  final RideKey rideKey;
  final NextRideLeaveState registration;

  @override
  ConsumerState<_NextRideActions> createState() => _NextRideActionsState();
}

class _NextRideActionsState extends ConsumerState<_NextRideActions> {
  bool _sending = false;
  Object? _sendError;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final RideDto ride = widget.ride;
    final RideGroupDto? joined = widget.group;
    // Le parcours du groupe, sinon celui de la sortie : le même repli que les
    // cartes de groupe du détail.
    final String? routeSlug = joined?.routeSlug ?? ride.routeSlug;
    final List<GpsServiceConnectionDto> services = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.connectedServices ?? const [],
      ),
    );
    final bool canSend =
        routeSlug != null && services.isNotEmpty && !ride.isPast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: PdlButton(
                label: 'home.viewRide'.tr(),
                onPressed: () =>
                    context.push(Paths.ride(ride.team.slug, ride.slug)),
              ),
            ),
            // Aucune désinscription sur une sortie annulée : elle n'a plus
            // lieu.
            if (joined != null &&
                !ride.isCancelled &&
                !ride.isPast) ...<Widget>[
              const SizedBox(width: PdlSpacing.chipGap),
              PdlButton(
                key: keys.home.nextRideLeaveButton,
                label: 'rides.leave'.tr(),
                loadingLabel: 'rides.leaving'.tr(),
                variant: PdlButtonVariant.outline,
                loading: widget.registration.pendingGroupId == joined.id,
                // Le groupe rejoint, porté par la ligne : **jamais une
                // boucle** sur les groupes.
                onPressed: () => ref
                    .read(nextRideLeaveProvider(widget.rideKey).notifier)
                    .leave(ride, joined),
              ),
            ],
            if (canSend) ...<Widget>[
              const SizedBox(width: PdlSpacing.chipGap),
              IconButton.outlined(
                key: keys.home.nextRideSendToDevice,
                tooltip: 'routes.sendToDevice'.tr(),
                constraints: const BoxConstraints(
                  minWidth: PdlMetrics.tapTarget,
                  minHeight: PdlMetrics.tapTarget,
                ),
                icon: Icon(PdlIcons.device, color: context.pdl.primary),
                onPressed: _sending
                    ? null
                    : () => _send(ride.team.slug, routeSlug, services),
              ),
            ],
          ],
        ),
        if (_sendError != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlBanner(
            tone: PdlBannerTone.danger,
            message: getErrorMessage(_sendError!),
            onDismiss: () => setState(() => _sendError = null),
            dismissSemanticLabel: 'common.close'.tr(),
          ),
        ],
        if (_sent) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlBanner(
            tone: PdlBannerTone.info,
            message: 'routes.uploadSuccess'.tr(),
            onDismiss: () => setState(() => _sent = false),
            dismissSemanticLabel: 'common.close'.tr(),
          ),
        ],
      ],
    );
  }

  Future<void> _send(
    String teamSlug,
    String routeSlug,
    List<GpsServiceConnectionDto> services,
  ) async {
    final GpsServiceConnectionDto? picked = await pickGpsService(
      context,
      services,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _sending = true;
      _sendError = null;
      _sent = false;
    });
    try {
      await uploadRouteToService(
        ref,
        picked,
        teamSlug: teamSlug,
        routeSlug: routeSlug,
      );
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _sendError = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

/// Ce qui remplace le bloc quand aucune participation n'est à venir.
///
/// Compacte et actionnable : « Explorer » mène au fil, pas à un cul-de-sac.
class NoNextRideCard extends StatelessWidget {
  const NoNextRideCard({super.key, this.onExplore});

  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return PdlCard(
      flat: true,
      child: Row(
        children: <Widget>[
          Icon(PdlIcons.dateBusy, size: 24, color: context.pdl.textDimmed),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(child: Text('rides.noUpcoming'.tr(), style: t.bodyStrong)),
          if (onExplore != null)
            PdlButton(
              label: 'home.explore'.tr(),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: onExplore,
            ),
        ],
      ),
    );
  }
}
