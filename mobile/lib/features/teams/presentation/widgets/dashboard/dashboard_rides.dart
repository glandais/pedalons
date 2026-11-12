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
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../../rides/providers/participation_changes.dart';
import '../../../../routes/presentation/gps_export_runner.dart';
import '../../../../routes/presentation/widgets/gps_button.dart';
import 'dashboard_section.dart';
import '../../../../../core/widgets/day_box.dart';
import '../../../../../core/widgets/zone_mention_line.dart';
import '../../../../rides/domain/group_start.dart';
import '../../../domain/publication_timing.dart';

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
  const DashboardMyUpcoming({
    super.key,
    required this.list,
    required this.onViewAll,
  });

  final PublicationListResponse list;

  /// « Voir tout » : l'Agenda de l'équipe sur « Je participe ».
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final List<PublicationDto> rows = list.publications
        .where((PublicationDto p) => p is! PublicationDtoPost)
        .toList();

    return DashboardSection(
      key: keys.teamDashboard.myUpcoming,
      title: 'teams.dashboard.myUpcoming.title'.tr(),
      onViewAll: onViewAll,
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

class _MyUpcomingRowState extends ConsumerState<_MyUpcomingRow>
    with GpsExportRunner<_MyUpcomingRow> {
  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final PublicationDto p = widget.publication;
    // Le jour d'un rendez-vous, dans le fuseau de son entité
    // (docs/LEDGER_*.md API-60).
    // Pour une sortie, le jour du départ qui concerne la personne : celui de
    // son groupe (docs/LEDGER_*.md MOB-112).
    final DateTime? at = AppFormatters.tryParseZoneTime(
      p is PublicationDtoRide
          ? myStartAt(p.dateTime, p.registeredGroup)
          : p.dateTime,
      p.timezone,
    );

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

    // La ligne ne porte pas les fichiers du parcours : la feuille n'offre ici
    // que l'envoi vers un appareil, et le bouton n'apparaît qu'avec un
    // service connecté, comme avant elle.
    final bool canSend = routeSlug != null && watchGpsServices().isNotEmpty;

    return PdlCard(
      onTap: () => context.push(path),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Le jour en boîte à plat, à gauche (BRANDING §7.8).
              // Un voyage prend le turquoise doux.
              if (at != null)
                dayBoxFor(
                  at,
                  tone: p is PublicationDtoTrip
                      ? PublicationType.trip.tone(c)
                      : null,
                ),
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
                    // Le départ en information primaire, sous le titre
                    // (BRANDING §7.8, ledger `BRAND-8`) : « Départ 09:30 »
                    // en 700, jamais une statistique atténuée parmi d'autres.
                    ?_departure(p),
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
                GpsButton(
                  key: keys.teamDashboard.myUpcomingGps(p.slug),
                  compact: true,
                  loading: gpsExporting,
                  onPressed: (BuildContext button) => openGpsSheet(
                    GpsExportTarget(
                      subtitle: p.name,
                      teamSlug: p.team.slug,
                      routeSlug: routeSlug,
                    ),
                    button,
                  ),
                ),
              ],
            ],
          ),
          ...gpsExportBanners(gap: PdlSpacing.chipGap, gapBefore: true),
        ],
      ),
    );
  }

  /// La ligne de départ de la ligne (BRANDING §7.8, ledger `BRAND-8`) :
  ///
  /// * une sortie — « Départ 09:30 », l'heure **du groupe rejoint** (qui vaut
  ///   celle de la sortie quand il part avec elle, docs/LEDGER_*.md MOB-112) ;
  /// * un voyage — « Départ 09:00 », sa première étape, puis sa plage au
  ///   format unique, « ven. 16 → dim. 18 oct. ».
  ///
  /// Tout se lit dans le fuseau de l'entité, la mention de fuseau commente
  /// l'heure affichée (docs/LEDGER_*.md API-60). La boîte du jour, à gauche,
  /// est muette : l'étiquette dit le jour aux lecteurs d'écran.
  Widget? _departure(PublicationDto p) {
    final String start = p is PublicationDtoRide
        ? myStartAt(p.dateTime, p.registeredGroup)
        : p.dateTime;
    final String? trailing = switch (p) {
      PublicationDtoRide() => null,
      PublicationDtoTrip trip => tripDaySpan(
        trip.dateTime,
        trip.endDateTime,
        timezone: trip.timezone,
      ),
      PublicationDtoPost() => null,
    };
    if (p is PublicationDtoPost) return null;
    final DateTime? instant = DateTime.tryParse(start);
    if (instant == null) return null;
    final String zone = p.timezone;
    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{
        'time': AppFormatters.formatTime(
          AppFormatters.toZoneTime(instant, zone),
        ),
      },
    );
    final String day =
        AppFormatters.formatDepartureRelative(instant, zone) ??
        AppFormatters.formatDepartureDate(instant, zone);
    return Padding(
      key: keys.teamDashboard.myUpcomingDeparture(p.slug),
      padding: const EdgeInsets.only(top: PdlSpacing.chipGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlDepartureLine(
            headline: headline,
            trailing: trailing,
            semanticLabel: <String>[
              headline,
              // Un voyage : sa plage commence par le jour du départ.
              if (p is! PublicationDtoTrip) day,
              ?trailing,
            ].join(', '),
          ),
          ?ZoneMentionLine.maybe(start, zone),
        ],
      ),
    );
  }

  /// Lieu de départ, puis « Groupe B · 26 km/h ». L'heure est la ligne de
  /// départ ([_departure]).
  List<PdlStat> _rideStats(PublicationDtoRide ride, UnitSystem units) {
    final RideGroupDto? group = ride.registeredGroup;
    return <PdlStat>[
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

  /// Étapes et distance. La plage et l'heure sont la ligne de départ
  /// ([_departure]).
  List<PdlStat> _tripStats(PublicationDtoTrip trip, UnitSystem units) {
    return <PdlStat>[
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
    // Le départ du groupe rejoint quand il est connu, sinon celui de la
    // sortie (docs/LEDGER_*.md MOB-112). Une désinscription faite depuis le
    // chargement l'emporte sur le groupe de la ligne.
    final String start = myStartAt(
      ride.dateTime,
      registered ? ride.registeredGroup : null,
    );
    final DateTime? at = DateTime.tryParse(start);
    final List<RideGroupSummaryDto> groups =
        <RideGroupSummaryDto>[...ride.groupSummaries]..sort(
          (RideGroupSummaryDto a, RideGroupSummaryDto b) =>
              a.sortOrder.compareTo(b.sortOrder),
        );
    final bool routed =
        ride.routeSlug != null ||
        groups.any((RideGroupSummaryDto g) => g.routeSlug != null);
    final String path = Paths.ride(ride.team.slug, ride.slug);
    final bool allFull =
        groups.isNotEmpty && groups.every((RideGroupSummaryDto g) => g.full);

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
          // Le départ au format unique, en 700 à l'horloge (BRANDING §7.8,
          // ledger `MOB-115`) — il était en `sub` atténué.
          if (at != null) ...<Widget>[
            const SizedBox(height: 2),
            PdlDepartureLine(
              headline: AppFormatters.formatDeparture(at, ride.timezone),
            ),
            ?ZoneMentionLine.maybe(start, ride.timezone),
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
                icon: PdlIcons.rideGroup,
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
              _GroupFill(
                group: g,
                units: units,
                timezone: ride.timezone,
                showStartTime: someGroupLeavesAtOwnTime(
                  groups.map((RideGroupSummaryDto g) => g.startAt),
                  start,
                ),
              ),
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
                    // Tous les groupes pleins : plus rien à rejoindre, le
                    // bouton le dit désactivé, comme la carte de groupe
                    // (docs/LEDGER_*.md MOB-139, N4).
                    : allFull
                    ? PdlButton(
                        key: keys.teamDashboard.rideFullButton(ride.slug),
                        label: 'rides.groupFull'.tr(),
                        variant: PdlButtonVariant.outline,
                        size: PdlButtonSize.sm,
                        enabled: false,
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

/// « Groupe B · 26 km/h · départ 08:30   ▬▬▬▬▬──   11 / 16 », ou « Complet ».
///
/// L'heure de chaque groupe est dite dès que les groupes ne partent pas tous à
/// celle de l'en-tête de la carte — le départ du groupe rejoint, sinon celui de
/// la sortie —, qui porte seul la mention de fuseau (docs/LEDGER_*.md MOB-112,
/// pendant web `WEB-136`).
class _GroupFill extends StatelessWidget {
  const _GroupFill({
    required this.group,
    required this.units,
    required this.timezone,
    required this.showStartTime,
  });

  final RideGroupSummaryDto group;
  final UnitSystem units;
  final String timezone;
  final bool showStartTime;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final int? max = group.maxParticipants;
    final String count = max == null
        ? 'teams.dashboard.upcomingRides.registeredCount'.plural(
            group.countParticipants,
          )
        // « 8/12 », la forme du compte partout ailleurs (règle R5, KIT §9).
        : '${group.countParticipants}/$max';
    final String label = <String>[
      group.name,
      if (group.averageSpeed != null)
        AppFormatters.formatSpeed(group.averageSpeed!, units),
    ].join(' · ');
    // L'heure à part, jamais tronquée : c'est le nom du groupe qui cède
    // (docs/LEDGER_*.md MOB-139, N3 — « départ 10… »).
    final String? departure = showStartTime
        ? 'teams.dashboard.upcomingRides.groupStart'.tr(
            namedArgs: <String, String>{
              'time': formatGroupStart(group.startAt, timezone),
            },
          )
        : null;
    final String name = <String>[label, ?departure].join(' · ');
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
            // Les barres restent alignées d'une ligne à l'autre ; dans la
            // colonne du nom, seuls le nom et l'allure s'abrègent. Faute de
            // place, l'heure passe dessous plutôt que d'être coupée.
            Expanded(
              flex: 2,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    label,
                    style: t.xs.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (departure != null)
                    Text(
                      // Insécable : « départ 10:00 » ne se coupe pas non plus.
                      ' · ${departure.replaceAll(' ', AppFormatters.nbsp)}',
                      key: keys.teamDashboard.groupFillDeparture(group.id),
                      style: t.xs.copyWith(color: c.text),
                    ),
                ],
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            if (max != null && max > 0)
              Expanded(
                // Primaire, rouge si plein : plus de vert ni d'orange
                // (règle R5, KIT §9).
                child: PdlProgressBar(
                  value: group.countParticipants / max,
                  color: group.full ? c.danger : c.primary,
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
