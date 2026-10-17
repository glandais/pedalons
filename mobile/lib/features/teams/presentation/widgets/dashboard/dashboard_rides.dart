import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../config/paths.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/enum_colors.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/api_error_handler.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../../auth/domain/auth_state.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../rides/providers/participation_changes.dart';
import '../../../../routes/presentation/route_export.dart';
import 'dashboard_section.dart';
import '../../../../../core/widgets/zone_mention_line.dart';
import '../../../../rides/domain/group_start.dart';

/// Une inscription faite dans l'app depuis le chargement du tableau de bord
/// l'emporte sur la ligne chargée avant elle — même règle que le fil.
bool _registered(WidgetRef ref, String id, bool loaded) =>
    ref.watch(
      registrationOverridesProvider.select((Map<String, bool> m) => m[id]),
    ) ??
    loaded;

// ─────────────────────────────────────────────────── vos prochaines sorties

/// « Vos prochaines sorties » : les sorties et voyages de l'équipe auxquels on
/// est inscrit, du plus proche au plus lointain.
///
/// Le groupe rejoint est `registeredGroup`, porté par la ligne : son nom, son
/// allure et son heure de départ. **Jamais de meneur ici** — et surtout pas
/// `createdBy`, qui est le créateur de la sortie et non celui d'un groupe.
class DashboardMyUpcoming extends StatelessWidget {
  const DashboardMyUpcoming({super.key, required this.list, this.onViewAll});

  final PublicationListResponse list;

  /// « Voir tout » : l'Agenda de l'équipe sur « Je participe ». Sans lui,
  /// « Mes participations » du profil, toutes équipes.
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final List<PublicationDto> rows = list.publications
        .where((PublicationDto p) => p is! PublicationDtoPost)
        .toList();

    return DashboardSection(
      key: keys.teamDashboard.myUpcoming,
      title: 'teams.dashboard.myUpcoming.title'.tr(),
      onViewAll:
          onViewAll ??
          (list.total > rows.length
              ? () => context.push(Paths.myParticipations())
              : null),
      child: rows.isEmpty
          ? DashboardEmptyLine(message: 'teams.dashboard.myUpcoming.empty'.tr())
          : DashboardCardColumn(
              children: <Widget>[
                for (final PublicationDto p in rows)
                  _MyUpcomingRow(
                    key: keys.teamDashboard.myUpcomingRow(p.slug),
                    publication: p,
                  ),
              ],
            ),
    );
  }
}

class _MyUpcomingRow extends ConsumerStatefulWidget {
  const _MyUpcomingRow({super.key, required this.publication});

  final PublicationDto publication;

  @override
  ConsumerState<_MyUpcomingRow> createState() => _MyUpcomingRowState();
}

class _MyUpcomingRowState extends ConsumerState<_MyUpcomingRow> {
  bool _sending = false;
  bool _sent = false;
  Object? _sendError;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final PublicationDto p = widget.publication;
    // Le jour d'un rendez-vous, dans le fuseau de son entité
    // (docs/LEDGER_*.md API-60).
    final DateTime? at = AppFormatters.tryParseZoneTime(p.dateTime, p.timezone);

    final (
      String path,
      String viewLabel,
      List<PdlStat> stats,
      String? routeSlug,
    ) = switch (p) {
      PublicationDtoRide ride => (
        Paths.ride(ride.team.slug, ride.slug),
        'home.viewRide'.tr(),
        _rideStats(ride, units),
        ride.registeredGroup?.routeSlug ?? ride.routeSlug,
      ),
      PublicationDtoTrip trip => (
        Paths.trip(trip.team.slug, trip.slug),
        'teams.dashboard.viewTrip'.tr(),
        _tripStats(trip, units),
        null,
      ),
      PublicationDtoPost post => (
        Paths.post(post.team.slug, post.slug),
        'common.open'.tr(),
        const <PdlStat>[],
        null,
      ),
    };

    final List<GpsServiceConnectionDto> services = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.connectedServices ?? const [],
      ),
    );
    final bool canSend = routeSlug != null && services.isNotEmpty;

    return PdlCard(
      onTap: () => context.push(path),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (at != null) _DateBlock(date: at),
              const SizedBox(width: PdlSpacing.cardTight),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      p.name,
                      style: t.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: PdlSpacing.badgeGap,
                      runSpacing: PdlSpacing.badgeGap,
                      children: <Widget>[
                        if (p is PublicationDtoTrip)
                          PdlBadge(
                            label: 'publicationType.trip'.tr(),
                            tone: PublicationType.trip.tone(c),
                          ),
                        PdlBadge(
                          label: 'rides.registered'.tr(),
                          tone: PdlDerivedTones.registered(c),
                          icon: PdlIcons.check,
                        ),
                      ],
                    ),
                    if (stats.isNotEmpty) ...<Widget>[
                      const SizedBox(height: PdlSpacing.chipGap),
                      // Une ligne par fait, tronquée : un lieu de départ ou
                      // un nom de groupe n'a pas de longueur bornée, et une
                      // statistique de `PdlStatRow` ne se coupe pas.
                      for (final PdlStat s in stats)
                        _MetaLine(icon: s.icon, text: s.value),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          Row(
            children: <Widget>[
              Expanded(
                child: PdlButton(
                  label: viewLabel,
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  onPressed: () => context.push(path),
                ),
              ),
              if (canSend) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                IconButton.outlined(
                  tooltip: 'routes.sendToDevice'.tr(),
                  constraints: const BoxConstraints(
                    minWidth: PdlMetrics.tapTarget,
                    minHeight: PdlMetrics.tapTarget,
                  ),
                  icon: Icon(PdlIcons.device, color: c.primary),
                  onPressed: _sending
                      ? null
                      : () => _send(p.team.slug, routeSlug, services),
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
      ),
    );
  }

  /// Heure du groupe rejoint quand elle diffère de celle de la sortie, lieu de
  /// départ, puis « Groupe B · 26 km/h ».
  List<PdlStat> _rideStats(PublicationDtoRide ride, UnitSystem units) {
    final RideGroupDto? group = ride.registeredGroup;
    // Le départ du groupe rejoint — qui vaut celui de la sortie quand il n'a
    // pas d'heure propre —, dans le fuseau de la sortie (docs/LEDGER_*.md
    // API-60), et la mention quand le lecteur est ailleurs.
    final String start = group?.startAt ?? ride.dateTime;
    final DateTime? instant = DateTime.tryParse(start);
    final String? mention = instant == null
        ? null
        : AppFormatters.formatZoneMention(instant, ride.timezone);
    return <PdlStat>[
      if (instant != null)
        PdlStat(
          value: formatGroupStart(start, ride.timezone),
          icon: PdlIcons.time,
        ),
      if (mention != null)
        PdlStat(value: mention, icon: PdlIcons.otherTimezone),
      if (ride.startPlace != null)
        PdlStat(value: ride.startPlace!.name, icon: PdlIcons.placeStart),
      if (group != null)
        PdlStat(
          value: group.averageSpeed == null
              ? group.name
              : '${group.name} · '
                    '${AppFormatters.formatSpeed(group.averageSpeed!, units)}',
          icon: PdlIcons.speed,
        ),
    ];
  }

  List<PdlStat> _tripStats(PublicationDtoTrip trip, UnitSystem units) {
    // Une ligne de liste ne porte pas les étapes : `endDate` se lit dans le
    // fuseau du voyage, comme le documente `TripDto` (docs/LEDGER_*.md API-60).
    final DateTime? start = AppFormatters.tryParseZoneTime(
      trip.dateTime,
      trip.timezone,
    );
    final DateTime? end = AppFormatters.tryParseZoneTime(
      trip.endDate,
      trip.timezone,
    );
    final DateTime? instant = DateTime.tryParse(trip.dateTime);
    final String? mention = instant == null
        ? null
        : AppFormatters.formatZoneMention(instant, trip.timezone);
    return <PdlStat>[
      if (start != null)
        PdlStat(
          value: end == null
              ? AppFormatters.formatDayMonth(start)
              : '${AppFormatters.formatDayMonth(start)} → '
                    '${AppFormatters.formatDayMonth(end)}',
          icon: PdlIcons.date,
        ),
      if (mention != null)
        PdlStat(value: mention, icon: PdlIcons.otherTimezone),
      if (trip.stageCount > 0)
        PdlStat(
          value: 'trips.stageCount'.plural(trip.stageCount),
          icon: PdlIcons.stage,
        ),
      if (trip.totalDistance != null)
        PdlStat(
          value: AppFormatters.formatDistance(trip.totalDistance!, units),
          icon: PdlIcons.distance,
        ),
    ];
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

/// Une icône et un texte d'une ligne, tronqué au besoin.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: c.textDimmed),
            const SizedBox(width: PdlSpacing.badgeGap),
          ],
          Expanded(
            child: Text(
              text,
              style: context.pdlText.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Sam. / 10 / Oct. » : le jour, en bloc, à gauche de la ligne.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  /// Déjà ramenée à l'heure murale du fuseau de l'entité.
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Container(
      width: PdlMetrics.tapTarget + PdlSpacing.chipGap,
      padding: const EdgeInsets.symmetric(vertical: PdlSpacing.badgeGap),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: PdlRadii.mdAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            AppFormatters.dayAbbrev(date.weekday),
            style: t.xs.copyWith(color: c.primaryOnSoft),
          ),
          Text(
            '${date.day}',
            style: t.statBigValue.copyWith(color: c.primaryOnSoft),
          ),
          Text(
            DateFormat.MMM().format(date),
            style: t.xs.copyWith(color: c.primaryOnSoft),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── sorties à venir

/// « Sorties à venir » : les prochaines sorties publiées de l'équipe, avec le
/// remplissage de chaque groupe.
class DashboardUpcomingRides extends StatelessWidget {
  const DashboardUpcomingRides({
    super.key,
    required this.list,
    required this.canEdit,
    this.onViewAll,
  });

  final PublicationListResponse list;

  /// « Modifier » sur chaque carte — organisateurs et administrateurs.
  final bool canEdit;

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final List<PublicationDtoRide> rides = list.publications
        .whereType<PublicationDtoRide>()
        .toList();

    return DashboardSection(
      key: keys.teamDashboard.upcomingRides,
      title: 'teams.dashboard.upcomingRides.title'.tr(),
      count: list.total > 0 ? '${list.total}' : null,
      onViewAll: onViewAll,
      child: rides.isEmpty
          ? DashboardEmptyLine(
              message: 'teams.dashboard.upcomingRides.empty'.tr(),
            )
          : DashboardCardColumn(
              children: <Widget>[
                for (final PublicationDtoRide r in rides)
                  DashboardRideCard(ride: r, canEdit: canEdit),
              ],
            ),
    );
  }
}

/// La carte d'une sortie à venir : revêtement, distance, dénivelé, et une
/// barre de remplissage par groupe.
class DashboardRideCard extends ConsumerWidget {
  const DashboardRideCard({
    super.key,
    required this.ride,
    required this.canEdit,
  });

  final PublicationDtoRide ride;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final bool registered = _registered(ref, ride.id, ride.registered);
    final DateTime? at = DateTime.tryParse(ride.dateTime);
    final List<RideGroupSummaryDto> groups =
        <RideGroupSummaryDto>[...ride.groupSummaries]..sort(
          (RideGroupSummaryDto a, RideGroupSummaryDto b) =>
              a.sortOrder.compareTo(b.sortOrder),
        );
    final bool routed =
        ride.routeSlug != null ||
        groups.any((RideGroupSummaryDto g) => g.routeSlug != null);
    final String path = Paths.ride(ride.team.slug, ride.slug);

    return PdlCard(
      key: keys.teamDashboard.rideCard(ride.slug),
      onTap: () => context.push(path),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
              if (ride.surfaceType != null)
                PdlBadge(
                  label: AppFormatters.surfaceName(ride.surfaceType!),
                  tone: SurfaceType.fromJson(ride.surfaceType!).tone(c),
                ),
              if (registered)
                PdlBadge(
                  label: 'rides.registered'.tr(),
                  tone: PdlDerivedTones.registered(c),
                  icon: PdlIcons.check,
                ),
            ],
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          Text(
            ride.name,
            style: t.cardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (at != null) ...<Widget>[
            Text(
              AppFormatters.formatRideDate(at, zone: ride.timezone),
              style: t.sub,
            ),
            ?ZoneMentionLine.maybe(ride.dateTime, ride.timezone),
          ],
          const SizedBox(height: PdlSpacing.chipGap),
          PdlStatRow(
            stats: <PdlStat>[
              if (ride.distance != null)
                PdlStat(
                  value: AppFormatters.formatDistance(ride.distance!, units),
                  icon: PdlIcons.distance,
                ),
              if (ride.elevationGain != null)
                PdlStat(
                  value: AppFormatters.formatElevation(
                    ride.elevationGain!,
                    units,
                  ),
                  icon: PdlIcons.elevationUp,
                  trend: PdlStatTrend.up,
                ),
              PdlStat(
                value: 'rides.groupCount'.plural(ride.groupCount),
                icon: PdlIcons.people,
              ),
              if (ride.commentCount != null && ride.commentCount! > 0)
                PdlStat(
                  value: 'comments.count'.plural(ride.commentCount!),
                  icon: PdlIcons.comment,
                ),
            ],
          ),
          if (groups.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            for (final RideGroupSummaryDto g in groups)
              _GroupFill(group: g, units: units),
          ],
          if (!routed) ...<Widget>[
            const SizedBox(height: PdlSpacing.badgeGap),
            Row(
              children: <Widget>[
                Icon(PdlIcons.warning, size: 16, color: c.textDimmed),
                const SizedBox(width: PdlSpacing.badgeGap),
                Expanded(
                  child: Text(
                    'teams.dashboard.upcomingRides.noRoute'.tr(),
                    style: t.xs,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: PdlSpacing.chipGap),
          Row(
            children: <Widget>[
              Expanded(
                child: registered
                    ? PdlButton(
                        label: 'home.viewRide'.tr(),
                        variant: PdlButtonVariant.outline,
                        size: PdlButtonSize.sm,
                        onPressed: () => context.push(path),
                      )
                    // L'inscription se fait dans un groupe : la fiche de la
                    // sortie est l'endroit où l'on choisit lequel.
                    : PdlButton(
                        label: 'teams.dashboard.register'.tr(),
                        size: PdlButtonSize.sm,
                        onPressed: () => context.push(path),
                      ),
              ),
              if (canEdit) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                PdlButton(
                  key: keys.teamDashboard.rideEditButton(ride.slug),
                  label: 'teams.dashboard.edit'.tr(),
                  icon: PdlIcons.edit,
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  onPressed: () =>
                      context.push(Paths.rideEdit(ride.team.slug, ride.slug)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// « Groupe B   26 km/h   ▬▬▬▬▬──   11 / 16 », ou « Complet ».
class _GroupFill extends StatelessWidget {
  const _GroupFill({required this.group, required this.units});

  final RideGroupSummaryDto group;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final int? max = group.maxParticipants;
    final String count = max == null
        ? 'teams.dashboard.upcomingRides.registeredCount'.plural(
            group.countParticipants,
          )
        : '${group.countParticipants} / $max';
    final String name = group.averageSpeed == null
        ? group.name
        : '${group.name} · '
              '${AppFormatters.formatSpeed(group.averageSpeed!, units)}';
    // Une seule annonce pour la ligne : le groupe, son remplissage en toutes
    // lettres, et « Complet » le cas échéant — plutôt que la barre et le
    // texte « 11 / 16 » lus chacun pour soi, sans dire de quel groupe.
    final String semantics = <String>[
      name,
      if (max == null)
        count
      else
        'teams.dashboard.upcomingRides.groupFill'.plural(
          group.countParticipants,
          namedArgs: <String, String>{'max': '$max'},
        ),
      if (group.full) 'rides.groupFull'.tr(),
    ].join(', ');

    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                name,
                style: t.xs.copyWith(color: c.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            if (max != null && max > 0)
              Expanded(
                flex: 2,
                child: PdlProgressBar(
                  value: group.countParticipants / max,
                  color: group.full ? c.danger : null,
                ),
              ),
            const SizedBox(width: PdlSpacing.chipGap),
            if (group.full)
              PdlBadge(
                label: 'rides.groupFull'.tr(),
                // « Complet » est un état terminal (pas de liste d'attente) :
                // la famille rouge, comme la barre pleine.
                tone: PdlFamily.red.soft(c),
              )
            else
              Text(
                count,
                style: t.xs.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
