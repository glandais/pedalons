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
import '../../../../core/utils/card_header_image.dart';
import '../../../../core/utils/formatters.dart';
import '../../../visibility/presentation/visibility_badge.dart';
import '../../../rides/presentation/widgets/ride_group_place_line.dart';
import '../../../rides/presentation/widgets/ride_display_stats.dart';
import '../../../rides/presentation/widgets/ride_weather_summary_line.dart';
import '../../../rides/providers/ride_detail_provider.dart';
import '../../../routes/presentation/gps_export_runner.dart';
import '../../../routes/presentation/widgets/gps_button.dart';
import '../../../routes/data/route_repository.dart';
import '../../../routes/providers/route_detail_provider.dart' show RouteKey;
import '../../../rides/presentation/widgets/ride_group_participants_section.dart'
    show RideGroupLeaveLink;
import '../../../teams/domain/publication_timing.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../rides/domain/group_title.dart';
import '../../providers/next_ride_leave_controller.dart';
import '../../../teams/presentation/widgets/publication_card.dart';
import '../../providers/next_ride_provider.dart';
import '../../../../keys.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../core/widgets/day_box.dart';
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
    // L'heure qui concerne la personne : celle de son groupe, qui vaut celle
    // de la sortie quand il part avec elle (docs/LEDGER_*.md MOB-112).
    final String start = myStartAt(ride.dateTime, group);
    final DateTime? instant = DateTime.tryParse(start);
    // « Aujourd'hui » / « Demain », seul relatif admis (BRANDING §8.3, ledger
    // `BRAND-8`), en pastille sur l'image comme les cartes du fil — plus de
    // « dans 2 jours » ni de « dans 3 h ». Rien pour une sortie annulée.
    final String? relative = instant == null || ride.isCancelled
        ? null
        : AppFormatters.formatDepartureRelative(instant, ride.timezone);

    final RideKey key = RideKey(teamSlug: ride.team.slug, rideSlug: ride.slug);
    // Pas `rideRegistrationProvider` : il chargerait le détail de la sortie,
    // que la ligne de liste rend inutile (`docs/LEDGER_*.md API-4`).
    final NextRideLeaveState registration = ref.watch(
      nextRideLeaveProvider(key),
    );
    // La photo de la sortie en bandeau, sinon la carte du tracé du groupe ;
    // la vignette du tracé seulement sous une photo (règle R10, KIT §9).
    final CardHeaderImage header = cardHeaderImage(
      photo: firstPhotoUrl(ride.media),
      trackMap: nextRideThumbnailUrl(
        ride,
        group,
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('home.nextRide'.tr(), style: t.sectionTitle),
        const SizedBox(height: PdlSpacing.cardTight),
        // Le bandeau d'échec de désinscription vit ici, au-dessus de la carte.
        if (registration.failure != null) ...<Widget>[
          PdlBanner(
            tone: PdlBannerTone.danger,
            title: 'rides.failure.generic'.tr(
              namedArgs: <String, String>{
                'group': groupLabel(registration.failure!.groupName),
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
                imageUrl: header.banner,
                height: PdlMediaHeights.hero,
                borderRadius: BorderRadius.zero,
                // La boîte du jour posée sur l'image (BRANDING §7.1, §7.8,
                // ledger `MOB-115`), au jour de l'heure affichée, et la
                // pastille « Aujourd'hui » / « Demain » en haut à droite.
                // Muettes : la ligne de départ dit le jour aux lecteurs
                // d'écran.
                overlay: instant == null
                    ? null
                    : ExcludeSemantics(
                        child: Stack(
                          children: <Widget>[
                            Positioned(
                              top: PdlSpacing.card,
                              left: PdlSpacing.card,
                              child: dayBoxFor(
                                AppFormatters.toZoneTime(
                                  instant,
                                  ride.timezone,
                                ),
                                posed: true,
                              ),
                            ),
                            if (relative != null)
                              Positioned(
                                top: PdlSpacing.card,
                                right: PdlSpacing.card,
                                child: PdlDayPill(
                                  key: keys.home.nextRideDayPill,
                                  label: relative,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                    ..._facts(c, t, start, instant),
                    const SizedBox(height: PdlSpacing.cardTight),
                    if (header.trackThumbnail == null)
                      _stats(units)
                    else
                      Row(
                        children: <Widget>[
                          Expanded(child: _stats(units)),
                          const SizedBox(width: PdlSpacing.statsNowrap),
                          PdlThumb(
                            key: keys.home.nextRideTrackThumb,
                            imageUrl: header.trackThumbnail,
                            size: PdlMetrics.thumbLg,
                          ),
                        ],
                      ),
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
                      _seats(
                        context,
                        c,
                        t,
                        group!,
                        ref.watch(
                          authProvider.select((AuthState s) => s.user?.id),
                        ),
                      ),
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

  /// Dans l'ordre des cartes (règle R1, KIT §9) : type → un état (Annulé,
  /// En cours) → visibilité si elle diffère de celle de l'équipe → J'y vais.
  /// Ni brouillon ni terminée ici : le bloc ne retient que les sorties
  /// publiées pas encore arrivées.
  Widget _badges(PdlColors c) => Wrap(
    key: keys.home.nextRideBadges,
    spacing: PdlSpacing.badgeGap,
    runSpacing: PdlSpacing.badgeGap,
    children: <Widget>[
      PdlBadge(
        label: 'publicationType.ride'.tr(),
        tone: PublicationType.ride.tone(c),
      ),
      if (ride.isCancelled)
        PdlBadge(label: 'status.cancelled'.tr(), tone: Status.cancelled.tone(c))
      else if (ridePhase(ride) == PublicationPhase.underWay)
        PdlBadge(
          label: 'teams.agenda.underWay'.tr(),
          tone: PdlDerivedTones.underWay(c),
          dot: true,
        ),
      ...cardVisibilityBadges(ride.visibility, reference: ride.team.visibility),
      PdlBadge(
        label: 'rides.registered'.tr(),
        tone: PdlDerivedTones.registered(c),
        icon: PdlIcons.check,
      ),
    ],
  );

  /// Date et heure de départ, puis « Groupe B · Place de la Mairie » — les
  /// faits qui décident si l'on y va.
  ///
  /// L'heure est celle de [start], le départ qui concerne la personne : la ligne
  /// de départ la porte, la mention de fuseau la commente (docs/LEDGER_*.md
  /// MOB-111). Dessous, le groupe rejoint et le lieu, **nom seul** — l'adresse
  /// est sur la page de la sortie (règle R11, KIT §9).
  List<Widget> _facts(
    PdlColors c,
    PdlTypography t,
    String start,
    DateTime? instant,
  ) {
    final Widget? groupPlace = RideGroupPlaceLine.maybe(
      key: keys.home.nextRideGroup,
      groupName: group?.name,
      placeName: ride.startPlace?.name,
    );
    return <Widget>[
      // « Départ 22:30 » en 20/700 (BRANDING §7.8), puis le retour ; le jour
      // est la boîte posée sur l'image et, en toutes lettres, l'étiquette
      // lue par les lecteurs d'écran.
      if (instant != null)
        Padding(
          key: keys.home.nextRideStart,
          padding: const EdgeInsets.only(bottom: 6),
          child: _departureLine(start, instant),
        ),
      // « heure de Tokyo (ven. 01:00 chez vous) » quand le lecteur est
      // ailleurs, à l'heure affichée juste au-dessus (docs/LEDGER_*.md API-60).
      if (ZoneMentionLine.maybe(start, ride.timezone) case final Widget mention)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: mention),
      ?groupPlace,
    ];
  }

  Widget _departureLine(String start, DateTime instant) {
    final String zone = ride.timezone;
    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{
        'time': AppFormatters.formatTime(
          AppFormatters.toZoneTime(instant, zone),
        ),
      },
    );
    return PdlDepartureLine(
      headline: headline,
      size: PdlDepartureLineSize.large,
      semanticLabel: <String>[
        headline,
        AppFormatters.formatDepartureRelative(instant, zone) ??
            AppFormatters.formatDepartureDate(instant, zone),
      ].join(', '),
    );
  }

  /// Distance et dénivelé tels que le serveur les donne pour la personne qui
  /// lit (`RideDto.displayDistance`, règle R3, KIT §9, docs/LEDGER_*.md
  /// API-178) : ceux du parcours de son groupe. La carte ne choisit plus entre
  /// la sortie et le groupe ; absents, rien ne s'affiche. Le compte des
  /// personnes n'y est plus : il rejoint la grappe, « 11/12 personnes »
  /// (règle R5, KIT §9).
  Widget _stats(UnitSystem units) => PdlStatRow(
    stats: rideDisplayStats(
      distance: ride.displayDistance,
      elevationGain: ride.displayElevationGain,
      units: units,
    ),
  );

  /// Les personnes du groupe rejoint, comme sur sa carte de groupe (règle
  /// R5, KIT §9, docs/LEDGER_*.md MOB-139) : la grappe — soi en primaire —,
  /// « 11/12 personnes » (« 11 personnes » sans maximum, compte du **groupe**,
  /// N13), puis la barre de places quand il y a un maximum, primaire, rouge
  /// si plein. Pas de « Voir tout » : la carte s'ouvre sur la sortie. La
  /// carte ne nomme pas de capitaine : la grappe garde tout le monde.
  Widget _seats(
    BuildContext context,
    PdlColors c,
    PdlTypography t,
    RideGroupDto g,
    String? currentUserId,
  ) {
    final int? max = g.maxParticipants;
    final String count = max == null
        ? 'rides.participants'.plural(
            g.countParticipants,
            namedArgs: <String, String>{'count': '${g.countParticipants}'},
          )
        : 'rides.participantsOf'.plural(
            max,
            namedArgs: <String, String>{
              'count': '${g.countParticipants}',
              'max': '$max',
            },
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Comme sur la carte de groupe : faute de place, le compte passe sous
        // la grappe en entier plutôt que de se couper.
        Wrap(
          spacing: PdlSpacing.chipGap,
          runSpacing: PdlSpacing.badgeGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (g.participants.isNotEmpty)
              PdlAvatarStack(
                key: keys.home.nextRideAvatars,
                people: <PdlAvatarEntry>[
                  for (final PublicUserDto p in g.participants)
                    PdlAvatarEntry(
                      name: p.displayName,
                      imageUrl: p.avatarUrl,
                      isCurrentUser: p.id == currentUserId,
                    ),
                ],
                total: g.countParticipants,
                semanticLabel: count,
              )
            else
              Icon(PdlIcons.people, size: 16, color: c.textDimmed),
            Text(
              count,
              key: keys.home.nextRideCount,
              style: t.sub.copyWith(color: c.text, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        if (max != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlProgressBar(
            key: keys.home.nextRideSeatsBar,
            value: max == 0 ? 1 : g.countParticipants / max,
            semanticLabel: count,
            color: g.full ? c.danger : c.primary,
          ),
        ],
      ],
    );
  }
}

/// Les actions de la carte : « Voir la sortie » en pleine largeur, « GPS »
/// dessous, et « Se désinscrire » en lien rouge au pied.
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

class _NextRideActionsState extends ConsumerState<_NextRideActions>
    with GpsExportRunner<_NextRideActions> {
  /// Les fichiers du parcours se cherchent, avant d'ouvrir la feuille.
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final RideDto ride = widget.ride;
    final RideGroupDto? joined = widget.group;
    // Le parcours du groupe, sinon celui de la sortie : le même repli que les
    // cartes de groupe du détail.
    final String? routeSlug = joined?.routeSlug ?? ride.routeSlug;
    // Jusqu'à la fin de la sortie — son arrivée estimée, pas son départ
    // (`finished` d'une ligne de liste ne dit que « partie ») —, et jamais
    // sur une sortie annulée : se désinscrire et exporter (règles R6 et R7,
    // KIT §9).
    final bool open =
        !ride.isCancelled && ridePhase(ride) != PublicationPhase.finished;
    // Dès qu'il y a un parcours, avec ou sans service connecté : la feuille
    // offre alors GPX et FIT, que la ligne de liste ne porte pas — ils se
    // demandent au moment d'ouvrir la feuille ([_openGps]).
    final bool canExport = routeSlug != null && open;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlButton(
          label: 'home.viewRide'.tr(),
          fullWidth: true,
          onPressed: () => context.push(Paths.ride(ride.team.slug, ride.slug)),
        ),
        if (canExport) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GpsButton(
              key: keys.home.nextRideGps,
              loading: gpsExporting || _resolving,
              onPressed: (BuildContext button) =>
                  _openGps(ride, joined, routeSlug, button),
            ),
          ),
        ],
        ...gpsExportBanners(gap: PdlSpacing.chipGap, gapBefore: true),
        // « Se désinscrire » en lien rouge au pied de la carte, la forme de
        // « Quitter le groupe » (règle R6, KIT §9).
        if (joined != null && open) ...<Widget>[
          const SizedBox(height: PdlSpacing.badgeGap),
          RideGroupLeaveLink(
            linkKey: keys.home.nextRideLeaveButton,
            label: 'rides.leave'.tr(),
            pending: widget.registration.pendingGroupId == joined.id,
            // Le groupe rejoint, porté par la ligne : **jamais une boucle**
            // sur les groupes.
            onPressed: () => ref
                .read(nextRideLeaveProvider(widget.rideKey).notifier)
                .leave(ride, joined),
          ),
        ],
      ],
    );
  }

  /// Ouvre la feuille GPS du parcours [routeSlug], ses fichiers GPX et FIT
  /// demandés d'abord : la ligne de liste ne les porte pas. Un seul appel
  /// existant, `getRoutesBulk(geometry: false)` — les métadonnées et les
  /// liens d'asset, sans le tracé. S'il échoue, la feuille s'ouvre quand même,
  /// avec les appareils seuls (ou « Connecter un compteur »).
  Future<void> _openGps(
    RideDto ride,
    RideGroupDto? joined,
    String routeSlug,
    BuildContext button,
  ) async {
    if (_resolving || gpsExporting) return;
    setState(() => _resolving = true);
    final RouteDetailDto? route = await ref.read(
      nextRideRouteFilesProvider(
        RouteKey(teamSlug: ride.team.slug, routeSlug: routeSlug),
      ).future,
    );
    if (!mounted) return;
    setState(() => _resolving = false);
    if (!button.mounted) return;
    await openGpsSheet(
      GpsExportTarget(
        subtitle: joined == null
            ? ride.name
            : '${groupLabel(joined.name)}'
                  ' · ${ride.name}',
        teamSlug: ride.team.slug,
        routeSlug: routeSlug,
        gpx: route?.media.assets.gpx,
        fit: route?.media.assets.fit,
      ),
      button,
    );
  }
}

/// Les fichiers du parcours de « Ma prochaine sortie », pour sa feuille GPS :
/// `getRoutesBulk(geometry: false)`, un endpoint qui existe, sans le tracé.
/// `null` si le parcours manque à la réponse ou si l'appel échoue — la feuille
/// garde alors les appareils. `autoDispose` : il ne sert qu'à l'ouverture.
final nextRideRouteFilesProvider = FutureProvider.autoDispose
    .family<RouteDetailDto?, RouteKey>((Ref ref, RouteKey key) async {
      try {
        final RoutesBulkResponse response = await ref
            .watch(routeRepositoryProvider)
            .getRoutesBulk(key.teamSlug, <String>[
              key.routeSlug,
            ], geometry: false);
        return response.routes
            .where((RouteDetailDto r) => r.slug == key.routeSlug)
            .firstOrNull;
      } catch (_) {
        return null;
      }
    });

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
