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
import '../../../../core/widgets/day_box.dart';
import '../../../../core/widgets/deleted_badge.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../posts/domain/post_neighbours.dart';
import '../../../rides/domain/group_start.dart';
import '../../../rides/presentation/widgets/ride_display_stats.dart';
import '../../../rides/presentation/widgets/ride_group_place_line.dart';
import '../../../rides/presentation/widgets/ride_weather_summary_line.dart';
import '../../../rides/providers/participation_changes.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../../visibility/presentation/visibility_badge.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../domain/publication_timing.dart';

/// Les trois hauteurs de bandeau média de la charte, **partagées**.
///
/// Elles étaient recopiées à plusieurs endroits ; une carte de fil et une carte
/// d'un autre écran finissaient par diverger de deux pixels sans que personne ne
/// sache laquelle avait raison.
abstract final class PdlMediaHeights {
  /// `.media--16x9` — carte hero de l'accueil.
  static const double hero = PdlMetrics.media16x9;

  /// `.media` — carte de fil.
  static const double feed = PdlMetrics.media;

  /// `.media--120` — carte compacte.
  static const double compact = PdlMetrics.media120;
}

/// La carte d'une publication dans un fil.
///
/// Le `switch` sur l'union scellée est **conservé** de la v1 : c'est la seule
/// chose qui garantisse qu'un nouveau type de publication au contrat casse la
/// compilation plutôt que de disparaître silencieusement du fil.
///
/// Trois corps sont rendus ici. Le quatrième, l'annonce, n'appartient pas à
/// `PublicationDto` — les annonces ont leur propre endpoint et leur propre DTO,
/// et leur carte arrive avec le lot 5.
class PublicationCard extends ConsumerWidget {
  const PublicationCard({
    super.key,
    required this.publication,
    this.showTeamLine = true,
    this.postNeighbours,
  });

  final PublicationDto publication;

  /// Voisins de cette publication **dans le fil courant**, calculés par la
  /// liste qui rend la carte. Ils voyagent dans l'`extra` de la route : le
  /// contrat n'expose aucun voisinage, et une URL partagée n'en porte donc
  /// aucun (§5.1). Sans objet pour une sortie ou un voyage.
  final PostNeighbours? postNeighbours;

  /// Masquée sur un fil d'équipe, où l'équipe est déjà l'écran.
  final bool showTeamLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (publication) {
      PublicationDtoRide ride => _RideBody(
        ride: ride,
        showTeamLine: showTeamLine,
      ),
      PublicationDtoPost post => _PostBody(
        post: post,
        showTeamLine: showTeamLine,
        neighbours: postNeighbours,
      ),
      PublicationDtoTrip trip => _TripBody(
        trip: trip,
        showTeamLine: showTeamLine,
      ),
    };
  }
}

/// La ligne d'une sortie ou d'un voyage, pour la vue « Lignes » de l'Agenda
/// (règle RL9 des listes, KIT §10) — le pendant de `AgendaRow` du site.
///
/// Plus dense qu'une carte : ni image ni extrait. La boîte du jour, le titre
/// et ses badges, la ligne de départ et « Groupe B · Place de la Mairie », les
/// chiffres. Le **contenu** est celui de la carte (KIT §9) : mêmes badges dans
/// le même ordre, même départ, mêmes compteurs — les deux vues le calculent au
/// même endroit, dans le corps de chaque type.
class PublicationRow extends ConsumerWidget {
  const PublicationRow({super.key, required this.publication});

  final PublicationDto publication;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (publication) {
    PublicationDtoRide ride => _RideBody(
      ride: ride,
      showTeamLine: false,
      dense: true,
    ),
    PublicationDtoTrip trip => _TripBody(
      trip: trip,
      showTeamLine: false,
      dense: true,
    ),
    // Une publication n'a pas de départ : elle garde sa carte.
    PublicationDtoPost post => _PostBody(post: post, showTeamLine: false),
  };
}

// ─────────────────────────────────────────────────────────── ossature commune

/// La ligne d'une liste en vue « Lignes » : la boîte du jour à plat, puis le
/// titre, ses badges, le départ et les chiffres ; un chevron à droite.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.onTap,
    required this.title,
    required this.badges,
    this.dayBox,
    this.departure,
    this.stats = const <PdlStat>[],
  });

  final VoidCallback onTap;
  final String title;
  final List<Widget> badges;
  final Widget? dayBox;
  final Widget? departure;
  final List<PdlStat> stats;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return PdlCard(
      padding: PdlCardPadding.tight,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          if (dayBox != null) ...<Widget>[
            ExcludeSemantics(child: dayBox!),
            const SizedBox(width: PdlSpacing.cardTight),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: t.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (departure != null) ...<Widget>[
                  const SizedBox(height: 2),
                  departure!,
                ],
                if (stats.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.badgeGap),
                  PdlStatRow(stats: stats),
                ],
                if (badges.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.badgeGap),
                  Wrap(
                    spacing: PdlSpacing.badgeGap,
                    runSpacing: PdlSpacing.badgeGap,
                    children: badges,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
        ],
      ),
    );
  }
}

/// Ce que les trois corps partagent : bandeau, ligne d'équipe, titre, extrait,
/// pile de badges, ligne sociale et rangée de statistiques.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.onTap,
    required this.tone,
    required this.icon,
    required this.title,
    required this.badges,
    this.imageUrl,
    this.teamName,
    this.teamSlug,
    this.teamLogoUrl,
    this.excerpt,
    this.trailingThumbnailUrl,
    this.social,
    this.stats = const <PdlStat>[],
    this.tags = const <TagDto>[],
    this.footer,
    this.dayBox,
    this.relativeLabel,
    this.relativeTone,
    this.departure,
  });

  final VoidCallback onTap;
  final PdlMediaTone tone;
  final IconData icon;
  final String title;
  final List<Widget> badges;
  final String? imageUrl;
  final String? teamName;
  final String? teamSlug;

  /// Logo de l'équipe (`TeamPublicationDto.logoUrl`) ; initiales sinon.
  final String? teamLogoUrl;
  final String? excerpt;

  /// La vignette carrée du parcours, à droite de la ligne sociale.
  final String? trailingThumbnailUrl;

  /// Avatars et barre de places — propres à chaque type.
  final Widget? social;

  final List<PdlStat> stats;

  /// Les tags d'équipe du contenu, tronqués à [kCardTagLimit] (ledger
  /// `MOB-39`). Sous le titre : ils disent *de quoi* parle le contenu, comme
  /// l'extrait, et non *où il en est*, qui est l'affaire des badges.
  final List<TagDto> tags;

  /// Une dernière ligne sous les statistiques — la météo d'une sortie.
  final Widget? footer;

  /// La boîte du jour posée en haut à gauche de l'image (BRANDING §7.1,
  /// §7.8 ; ledger `MOB-115`). Muette pour les lecteurs d'écran : la ligne de
  /// départ ([departure]) dit le jour en toutes lettres.
  final Widget? dayBox;

  /// « Aujourd'hui » / « Demain », en haut à droite de l'image ; rien sinon.
  final String? relativeLabel;
  final PdlTone? relativeTone;

  /// La ligne de départ et sa mention de fuseau, sous le titre.
  final Widget? departure;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;

    return PdlCard(
      padding: PdlCardPadding.none,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlCardMedia(
            tone: tone,
            icon: icon,
            imageUrl: imageUrl,
            height: PdlMediaHeights.feed,
            borderRadius: BorderRadius.zero,
            overlay: dayBox == null && relativeLabel == null
                ? null
                : ExcludeSemantics(
                    child: Stack(
                      children: <Widget>[
                        if (dayBox != null)
                          Positioned(
                            top: PdlSpacing.card,
                            left: PdlSpacing.card,
                            child: dayBox!,
                          ),
                        if (relativeLabel != null)
                          Positioned(
                            top: PdlSpacing.card,
                            right: PdlSpacing.card,
                            child: PdlDayPill(
                              label: relativeLabel!,
                              tone: relativeTone,
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
                if (teamName != null)
                  PdlTeamLine(
                    label: teamName!,
                    imageUrl: teamLogoUrl,
                    onTap: teamSlug == null
                        ? null
                        : () => pushLocation(context, Paths.team(teamSlug!)),
                  ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: t.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (departure != null) ...<Widget>[
                            const SizedBox(height: 2),
                            departure!,
                          ],
                          if (excerpt != null &&
                              excerpt!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              excerpt!,
                              style: t.sub,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (badges.isNotEmpty) ...<Widget>[
                      const SizedBox(width: PdlSpacing.chipGap),
                      PdlBadgeStack(badges: badges),
                    ],
                  ],
                ),
                if (tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  ContentTagRow(tags: tags, maxVisible: kCardTagLimit),
                ],
                if (social != null || trailingThumbnailUrl != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.cardTight),
                  Row(
                    children: <Widget>[
                      Expanded(child: social ?? const SizedBox.shrink()),
                      if (trailingThumbnailUrl != null) ...<Widget>[
                        const SizedBox(width: PdlSpacing.statsNowrap),
                        PdlThumb(
                          imageUrl: trailingThumbnailUrl,
                          size: PdlMetrics.thumbLg,
                        ),
                      ],
                    ],
                  ),
                ],
                if (stats.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.cardTight),
                  PdlStatRow(stats: stats),
                ],
                if (footer != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grappe d'avatars et barre de places : la « ligne sociale ».
///
/// La personne qui lit y est en primaire, comme sur toute grappe (règle R5,
/// KIT §9) ; la carte ne nomme pas de capitaine, la grappe garde tout le
/// monde.
class _SocialLine extends ConsumerWidget {
  const _SocialLine({required this.people, required this.count});

  final List<PublicUserDto> people;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    // **Pas de barre de places ici.** Le compteur brut est dans la rangée de
    // statistiques ; la barre est sur la carte « Ma prochaine sortie », qui
    // connaît le groupe et donc sa capacité. La capacité de la sortie entière
    // existe sur la ligne de liste (`RideDto.maxParticipants`,
    // `docs/LEDGER_*.md API-5`).
    if (people.isEmpty) return const SizedBox.shrink();
    return PdlAvatarStack(
      people: <PdlAvatarEntry>[
        for (final PublicUserDto p in people)
          PdlAvatarEntry(
            name: p.displayName,
            imageUrl: p.avatarUrl,
            isCurrentUser: p.id == currentUserId,
          ),
      ],
      total: count,
      semanticLabel: '$count',
    );
  }
}

/// La vignette thémée : `thumbnailUrl` est le repli servi par l'API pour un
/// client qui ne thème pas ses cartes — ici on thème, donc on choisit.
String? _themed(BuildContext context, String? light, String? dark) =>
    Theme.of(context).brightness == Brightness.dark
    ? (dark ?? light)
    : (light ?? dark);

// ───────────────────────────────────────────────────────────────────── sortie

class _RideBody extends ConsumerWidget {
  const _RideBody({
    required this.ride,
    required this.showTeamLine,
    this.dense = false,
  });

  final PublicationDtoRide ride;
  final bool showTeamLine;

  /// La ligne de la vue « Lignes » au lieu de la carte ([PublicationRow]).
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    // Une inscription faite dans l'app depuis le chargement du fil l'emporte
    // sur la page chargée avant elle.
    final bool registered =
        ref.watch(
          registrationOverridesProvider.select(
            (Map<String, bool> m) => m[ride.id],
          ),
        ) ??
        ride.registered;
    // Le départ qui concerne la personne : celui de son groupe quand elle est
    // inscrite et que la ligne le porte, sinon celui de la sortie
    // (docs/LEDGER_*.md MOB-112). L'instant du contrat : la plage et la date
    // se lisent dans le fuseau de la sortie, la mention se calcule au départ
    // affiché (docs/LEDGER_*.md API-60).
    final String start = myStartAt(
      ride.dateTime,
      registered ? ride.registeredGroup : null,
    );
    final DateTime? at = DateTime.tryParse(start);
    final bool isPast = ride.finished;
    // Partie et pas rentrée : « En cours » plutôt que « Terminée », que
    // `finished` (départ passé) aurait affiché (ledger `MOB-60`).
    final bool underWay = isUnderWay(
      dateTime: ride.dateTime,
      endDateTime: ride.endDateTime,
      status: ride.status,
    );
    final _Departure? departure = at == null
        ? null
        : _Departure.of(
            at,
            ride.timezone,
            showRelative: !isPast && ride.status != 'CANCELLED',
          );

    // La photo de la sortie en bandeau, sinon la carte du tracé ; la vignette
    // du tracé seulement sous une photo (règle R10, KIT §9).
    final CardHeaderImage header = cardHeaderImage(
      photo: firstPhotoUrl(ride.media),
      trackMap: ride.routeSlug == null
          ? null
          : _themed(context, ride.thumbnailLightUrl, ride.thumbnailDarkUrl),
    );

    // Sous « Départ 09:30 », « Groupe B · Place de la Mairie » : le groupe
    // quand la personne y est inscrite, le lieu, nom seul, s'il existe (règle
    // R11, KIT §9). Une inscription faite depuis le chargement du fil n'a pas
    // encore de groupe sur la ligne : le lieu seul, jusqu'au rechargement.
    final Widget? groupPlace = RideGroupPlaceLine.maybe(
      key: keys.feed.groupPlaceLine(ride.slug),
      groupName: registered ? ride.registeredGroup?.name : null,
      placeName: ride.startPlace?.name,
    );
    final Widget? departureLine = departure?.line();
    final Widget? departureBlock = departureLine == null && groupPlace == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ?departureLine,
              if (groupPlace != null) ...<Widget>[
                const SizedBox(height: 2),
                groupPlace,
              ],
            ],
          );
    void open() => context.push(Paths.ride(ride.team.slug, ride.slug));
    final List<Widget> badges = <Widget>[
      ...deletedBadgeFirst(ride.deleted),
      PdlBadge(
        label: 'publicationType.ride'.tr(),
        tone: PublicationType.ride.tone(c),
      ),
      if (ride.status == 'CANCELLED')
        PdlBadge(label: 'status.cancelled'.tr(), tone: Status.cancelled.tone(c))
      // Un brouillon se badge comme celui d'une publication (ledger
      // `MOB-139`, D1) : sans lui, rien ne le distingue d'une sortie publiée.
      else if (ride.status == 'DRAFT')
        PdlBadge(label: 'status.draft'.tr(), tone: Status.draft.tone(c))
      else if (underWay)
        PdlBadge(
          key: keys.feed.underWayBadge(ride.slug),
          label: 'teams.agenda.underWay'.tr(),
          tone: PdlDerivedTones.underWay(c),
          dot: true,
        )
      else if (isPast)
        PdlBadge(label: 'rides.finished'.tr(), tone: PdlDerivedTones.done(c)),
      // La visibilité, seulement quand elle diffère de celle de l'équipe
      // (règle R1, KIT §9) : une sortie lisible par lien d'une équipe privée.
      ...cardVisibilityBadges(
        ride.visibility,
        reference: ride.team.visibility,
        key: keys.feed.visibilityBadge(ride.slug),
      ),
      // L'apport principal de la v2 sur les listes : savoir, sans ouvrir la
      // sortie, qu'on y est inscrit.
      if (registered)
        PdlBadge(
          label: 'rides.registered'.tr(),
          tone: PdlDerivedTones.registered(c),
          icon: PdlIcons.check,
        ),
    ];
    // La date n'est plus une statistique (BRANDING §7.1, ledger `BRAND-8`) :
    // elle est la boîte du jour et la ligne de départ, en haut.
    final List<PdlStat> stats = <PdlStat>[
      // La distance et le D+ que le serveur donne pour la personne qui lit
      // (règle R3, KIT §9, docs/LEDGER_*.md API-178).
      ...rideDisplayStats(
        distance: ride.displayDistance,
        elevationGain: ride.displayElevationGain,
        units: ref.watch(unitSystemProvider),
      ),
      // Sans groupe, personne ne peut s'inscrire : pas de compteur ; et un
      // compteur à zéro ne s'affiche pas (règle R4, KIT §9).
      if (ride.groupCount > 0 && ride.participantCount > 0)
        PdlStat(
          value: 'rides.participants'.plural(
            ride.participantCount,
            namedArgs: <String, String>{'count': '${ride.participantCount}'},
          ),
          icon: PdlIcons.people,
        ),
      if (ride.groupCount > 0)
        PdlStat(
          value: 'rides.groupCount'.plural(ride.groupCount),
          icon: PdlIcons.rideGroup,
        ),
      if (ride.commentCount != null && ride.commentCount! > 0)
        PdlStat(
          value: 'comments.count'.plural(ride.commentCount!),
          icon: PdlIcons.comment,
        ),
    ];

    if (dense) {
      return _RowShell(
        onTap: open,
        title: ride.name,
        badges: badges,
        dayBox: departure?.flatDayBox(),
        departure: departureBlock,
        stats: stats,
      );
    }

    return _CardShell(
      onTap: open,
      tone: PdlMediaTone.ride,
      icon: PdlIcons.ride,
      imageUrl: header.banner,
      teamName: showTeamLine ? ride.team.name : null,
      teamSlug: ride.team.slug,
      teamLogoUrl: ride.team.logoUrl,
      title: ride.name,
      dayBox: departure?.dayBox(),
      relativeLabel: departure?.relative,
      departure: departureBlock,
      // **`excerpt`, pas `media.markdown`** : en vue compacte le corps n'est
      // même pas envoyé, et l'aplatir côté client rendait des liens bruts.
      excerpt: ride.excerpt,
      tags: ride.tags,
      badges: badges,
      // La vignette du parcours, à droite de la ligne sociale — sous une
      // photo seulement : sinon le bandeau est déjà la carte du tracé.
      trailingThumbnailUrl: header.trackThumbnail,
      social: _SocialLine(
        people: ride.topParticipants,
        count: ride.participantCount,
      ),
      footer:
          RideWeatherSummaryLine.shows(
            ride.weather,
            finished: isPast,
            cancelled: ride.status == 'CANCELLED',
          )
          ? RideWeatherSummaryLine(
              summary: ride.weather,
              timezone: ride.timezone,
              finished: isPast,
              cancelled: ride.status == 'CANCELLED',
            )
          : null,
      stats: stats,
    );
  }
}

// ──────────────────────────────────────────────────────────────── publication

class _PostBody extends StatelessWidget {
  const _PostBody({
    required this.post,
    required this.showTeamLine,
    this.neighbours,
  });

  final PublicationDtoPost post;
  final bool showTeamLine;
  final PostNeighbours? neighbours;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    // Un rendez-vous dans le fuseau de la publication (`PostDto.timezone`,
    // docs/LEDGER_*.md API-60) ; date seule, donc sans mention.
    final DateTime? at = AppFormatters.tryParseZoneTime(
      post.dateTime,
      post.timezone,
    );

    return _CardShell(
      onTap: () => context.push(
        Paths.post(post.team.slug, post.slug),
        extra: neighbours,
      ),
      tone: PdlMediaTone.post,
      icon: PdlIcons.post,
      // Le post n'a pas de variante thémée au contrat : `thumbnailUrl` est
      // sa seule image de bandeau.
      imageUrl: post.thumbnailUrl,
      teamName: showTeamLine ? post.team.name : null,
      teamSlug: post.team.slug,
      teamLogoUrl: post.team.logoUrl,
      title: post.name,
      excerpt: post.excerpt,
      tags: post.tags,
      badges: <Widget>[
        ...deletedBadgeFirst(post.deleted),
        PdlBadge(
          label: 'publicationType.post'.tr(),
          tone: PublicationType.post.tone(c),
        ),
        if (post.status == 'DRAFT')
          PdlBadge(label: 'status.draft'.tr(), tone: Status.draft.tone(c)),
        ...cardVisibilityBadges(
          post.visibility,
          reference: post.team.visibility,
          key: keys.feed.visibilityBadge(post.slug),
        ),
      ],
      stats: <PdlStat>[
        if (at != null)
          PdlStat(
            // Courte avec l'heure, l'année hors de l'année en cours (KIT §9,
            // docs/LEDGER_*.md MOB-139) : « dim. 8 nov. · 18:30 ».
            value: AppFormatters.formatTimestamp(at, zone: post.timezone),
            icon: PdlIcons.date,
          ),
        if (post.commentCount != null && post.commentCount! > 0)
          PdlStat(
            value: 'comments.count'.plural(post.commentCount!),
            icon: PdlIcons.comment,
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────── voyage

class _TripBody extends ConsumerWidget {
  const _TripBody({
    required this.trip,
    required this.showTeamLine,
    this.dense = false,
  });

  final PublicationDtoTrip trip;
  final bool showTeamLine;

  /// La ligne de la vue « Lignes » au lieu de la carte ([PublicationRow]).
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final bool registered =
        ref.watch(
          registrationOverridesProvider.select(
            (Map<String, bool> m) => m[trip.id],
          ),
        ) ??
        trip.registered;
    // Un rendez-vous dans le fuseau du voyage ; une ligne de liste ne porte pas
    // les étapes, la fin se lit donc dans le même (docs/LEDGER_*.md API-60).
    final DateTime? instant = DateTime.tryParse(trip.dateTime);
    final PdlTone tripTone = PublicationType.trip.tone(c);
    // Le départ du voyage — sa première étape — et, à la suite, sa plage du
    // départ à la fin stockée (`endDateTime`, ledger `API-85`) : « ven. 16 →
    // dim. 18 oct. » (ledger `MOB-114`). La mention commente cette heure.
    final _Departure? departure = instant == null
        ? null
        : _Departure.of(
            instant,
            trip.timezone,
            trailing: tripDaySpan(
              trip.dateTime,
              trip.endDateTime,
              timezone: trip.timezone,
            ),
            tone: tripTone,
            showRelative: !trip.finished && trip.status != 'CANCELLED',
          );
    final bool underWay = isUnderWay(
      dateTime: trip.dateTime,
      endDateTime: trip.endDateTime,
      status: trip.status,
    );

    // Comme la sortie (règle R10) : la photo, sinon la carte du tracé ; la
    // vignette du tracé seulement sous une photo.
    final CardHeaderImage header = cardHeaderImage(
      photo: firstPhotoUrl(trip.media),
      trackMap: _themed(context, trip.thumbnailLightUrl, trip.thumbnailDarkUrl),
    );

    void open() => context.push(Paths.trip(trip.team.slug, trip.slug));
    final List<Widget> badges = <Widget>[
      ...deletedBadgeFirst(trip.deleted),
      PdlBadge(
        label: 'publicationType.trip'.tr(),
        tone: PublicationType.trip.tone(c),
      ),
      // Les mêmes états que la sortie : Annulé, Brouillon, En cours,
      // Terminée (ledger `MOB-139`, D1 et D2 ; règle R1, KIT §9).
      if (trip.status == 'CANCELLED')
        PdlBadge(label: 'status.cancelled'.tr(), tone: Status.cancelled.tone(c))
      else if (trip.status == 'DRAFT')
        PdlBadge(label: 'status.draft'.tr(), tone: Status.draft.tone(c))
      else if (underWay)
        PdlBadge(
          key: keys.feed.underWayBadge(trip.slug),
          label: 'teams.agenda.underWay'.tr(),
          tone: PdlDerivedTones.underWay(c),
          dot: true,
        )
      else if (trip.finished)
        PdlBadge(
          key: keys.feed.finishedBadge(trip.slug),
          label: 'trips.finished'.tr(),
          tone: PdlDerivedTones.done(c),
        ),
      ...cardVisibilityBadges(
        trip.visibility,
        reference: trip.team.visibility,
        key: keys.feed.visibilityBadge(trip.slug),
      ),
      if (registered)
        PdlBadge(
          label: 'rides.registered'.tr(),
          tone: PdlDerivedTones.registered(c),
          icon: PdlIcons.check,
        ),
    ];
    final List<PdlStat> stats = <PdlStat>[
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
      if (trip.totalElevationGain != null)
        PdlStat(
          value: AppFormatters.formatElevation(trip.totalElevationGain!, units),
          icon: PdlIcons.elevationUp,
          trend: PdlStatTrend.up,
        ),
      // Le compte de l'API (`participantCount`), jamais la longueur d'une
      // liste de noms : une personne non membre le voit aussi, sans les
      // noms (règle R4, KIT §9 ; ledger `API-144`).
      if (trip.participantCount > 0)
        PdlStat(
          key: keys.feed.tripParticipantCount(trip.slug),
          value: 'rides.participants'.plural(
            trip.participantCount,
            namedArgs: <String, String>{'count': '${trip.participantCount}'},
          ),
          icon: PdlIcons.people,
        ),
      // Les commentaires s'il y en a ; absents pour qui ne peut pas les lire.
      if (trip.commentCount != null && trip.commentCount! > 0)
        PdlStat(
          value: 'comments.count'.plural(trip.commentCount!),
          icon: PdlIcons.comment,
        ),
    ];

    if (dense) {
      return _RowShell(
        onTap: open,
        title: trip.name,
        badges: badges,
        dayBox: departure?.flatDayBox(),
        departure: departure?.line(),
        stats: stats,
      );
    }

    return _CardShell(
      onTap: open,
      tone: PdlMediaTone.trip,
      icon: PdlIcons.trip,
      imageUrl: header.banner,
      trailingThumbnailUrl: header.trackThumbnail,
      teamName: showTeamLine ? trip.team.name : null,
      teamSlug: trip.team.slug,
      teamLogoUrl: trip.team.logoUrl,
      title: trip.name,
      dayBox: departure?.dayBox(),
      relativeLabel: departure?.relative,
      relativeTone: tripTone,
      departure: departure?.line(),
      excerpt: trip.excerpt,
      tags: trip.tags,
      badges: badges,
      social: _SocialLine(
        // Le voyage embarque ses premiers participants, la sortie un aperçu
        // (`topParticipants`) ; la pastille « +N » se compte sur le total.
        // Une personne hors de l'équipe reçoit une liste vide
        // (`MemberNamesVisibility`, ledger `API-144`) : pas de grappe, le
        // compte seul, dans la rangée de chiffres.
        people: trip.participants,
        count: trip.participantCount,
      ),
      // La ligne météo de la prochaine étape (`TripDto.weather`, ledger
      // `API-82`) : le même widget que la carte de sortie.
      footer:
          RideWeatherSummaryLine.shows(
            trip.weather,
            finished: trip.finished,
            cancelled: trip.status == 'CANCELLED',
          )
          ? RideWeatherSummaryLine(
              summary: trip.weather,
              timezone: trip.timezone,
              finished: trip.finished,
              cancelled: trip.status == 'CANCELLED',
            )
          : null,
      stats: stats,
    );
  }
}

// ───────────────────────────────────────────────────────────────────── départ

/// Le départ d'une carte de sortie ou de voyage (BRANDING §7.1, §7.8 ; ledgers
/// `BRAND-8`, `MOB-114`, `MOB-115`) : la boîte du jour posée sur l'image, la
/// pastille « Aujourd'hui » / « Demain », et sous le titre « Départ 09:00 »
/// suivi de [trailing], la mention de fuseau dessous.
///
/// [instant] est la valeur du contrat — le départ **affiché**, celui du groupe
/// de la personne quand elle en a un (ledger `MOB-112`) —, lue dans le fuseau
/// [zone] de l'entité ; la mention se calcule sur lui.
class _Departure {
  _Departure._(
    this.instant,
    this.zone, {
    required this.trailing,
    required this.relative,
    required this.tone,
  });

  factory _Departure.of(
    DateTime instant,
    String zone, {
    String? trailing,
    PdlTone? tone,
    bool showRelative = true,
  }) => _Departure._(
    instant,
    zone,
    trailing: trailing,
    tone: tone,
    // Une sortie passée ou annulée n'a pas de « Aujourd'hui » à annoncer :
    // son badge de statut le dit déjà.
    relative: showRelative
        ? AppFormatters.formatDepartureRelative(instant, zone)
        : null,
  );

  final DateTime instant;
  final String zone;
  final String? trailing;
  final String? relative;
  final PdlTone? tone;

  Widget dayBox() => dayBoxFor(
    AppFormatters.toZoneTime(instant, zone),
    tone: tone,
    posed: true,
  );

  /// À plat, sur le fond doux de son ton : la ligne de la vue « Lignes ».
  Widget flatDayBox() =>
      dayBoxFor(AppFormatters.toZoneTime(instant, zone), tone: tone);

  Widget line() {
    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{
        'time': AppFormatters.formatTime(
          AppFormatters.toZoneTime(instant, zone),
        ),
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PdlDepartureLine(
          headline: headline,
          trailing: trailing,
          // La boîte du jour et la pastille sont muettes : le jour se dit
          // ici (« Départ 09:00, Demain »).
          semanticLabel: <String>[
            headline,
            relative ?? AppFormatters.formatDepartureDate(instant, zone),
            ?trailing,
          ].join(', '),
        ),
        if (AppFormatters.formatZoneMention(instant, zone) != null)
          ZoneMentionLine(instant: instant, zone: zone),
      ],
    );
  }
}
