import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/publication_stats_line.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../domain/ride_group_action.dart';
import '../../../routes/presentation/widgets/gps_button.dart';
import 'ride_group_participants_section.dart' show RideGroupLeaveLink;
import 'ride_group_weather_line.dart';
import '../../../../keys.dart';

/// La carte d'un groupe de sortie — **le choix de groupe lui-même** (ledger
/// `MOB-134`, lot 8, KIT §8, maquettes `sortie-groupes-meme-heure-mobile-cible`,
/// `sortie-groupes-heures-differentes-mobile-cible`).
///
/// De haut en bas :
///
/// 1. l'en-tête : la barre de couleur du tracé, le nom, le badge « J'y vais »
///    sur la sienne ; à droite le contrôle d'inscription ([action]) —
///    « Rejoindre », « Complet » désactivé — et le chevron vers la page du
///    groupe. **Ni « Quitter » ni « Changer pour A » en haut** ;
/// 2. « Départ 09:30 » en bandeau, quand les groupes ne partent pas tous à
///    la même heure ([showDeparture]) ;
/// 3. la ligne de chiffres ([PublicationStatsLine]) : distance · D+ · vitesse ;
/// 4. la ligne météo du groupe ([RideGroupWeatherLine]) ;
/// 5. le capitaine, s'il y en a un (jamais de repli sur `createdBy`) ;
/// 6. les visages, « 11/12 personnes », « Voir tout », la barre de places ;
/// 7. le bouton « GPS » ([onOpenGps]) — l'appelant ne le donne qu'à la carte
///    de son groupe ;
/// 8. « Changer pour A », bouton plein en pleine largeur, quand [action] vaut
///    [RideGroupAction.switchTo] — au pied, pour que le nom tienne en entier ;
/// 9. « Quitter le groupe », lien discret, quand [action] vaut
///    [RideGroupAction.leave] — inscrite ici, que le groupe soit parti ou non.
///
/// Elle ne décide de rien : [action] est calculée par
/// `rideRegistrationControlAction` (chaque groupe jugé sur **son** départ,
/// ledger `API-170`) et [pending] par le contrôleur d'inscription. Aucune
/// confirmation, ni pour rejoindre, ni pour changer, ni pour quitter.
class RideGroupCard extends StatelessWidget {
  const RideGroupCard({
    super.key,
    required this.group,
    required this.rideDateTime,
    required this.timezone,
    required this.showDeparture,
    required this.action,
    required this.trackColor,
    required this.units,
    this.selected = false,
    this.pending = false,
    this.currentUserId,
    this.weatherLeg,
    this.onTap,
    this.onJoin,
    this.onSwitch,
    this.onLeave,
    this.onShowParticipants,
    this.onOpenGps,
    this.gpsLoading = false,
  });

  final RideGroupDto group;

  /// Le départ de la sortie (instant du contrat) : le jour du groupe ne
  /// s'affiche que s'il n'est pas le sien.
  final String rideDateTime;

  /// Afficher le départ du groupe : les groupes de la sortie ne partent pas
  /// tous à la même heure (`someGroupLeavesAtOwnTime`).
  final bool showDeparture;

  /// Le fuseau de la sortie, où se lit l'heure du groupe.
  final String timezone;

  /// Ce que la carte offre : [RideGroupAction.join] « Rejoindre »,
  /// [RideGroupAction.switchTo] « Changer pour A »,
  /// [RideGroupAction.full] « Complet » désactivé,
  /// [RideGroupAction.leave] le lien « Quitter le groupe » en pied de carte,
  /// [RideGroupAction.none] rien.
  final RideGroupAction action;

  /// Couleur du parcours du groupe sur la carte de la sortie
  /// (`groupTrackColorIndex` dans `kMultiTrackPalette`), partagée par les
  /// groupes qui roulent le même parcours — c'est le lien visuel entre les deux.
  final Color trackColor;

  final UnitSystem units;

  /// Groupe dont le parcours est celui de la carte et du profil.
  final bool selected;

  /// Un appel d'inscription, de changement ou de désinscription est en vol
  /// **sur ce groupe**.
  final bool pending;

  /// Identifiant de l'utilisateur courant, pour teinter son avatar en primaire
  /// dans la grappe.
  final String? currentUserId;

  /// Le leg météo **de ce groupe** (`OK`/`STALE`), pour sa ligne non
  /// cliquable ; `null` ne rend rien.
  final WeatherLegDto? weatherLeg;

  /// Ouvre la page du groupe (ledger `MOB-67`) — toute la carte y mène.
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  /// « Changer pour A » : `RideRegistrationController.switchGroup`.
  final VoidCallback? onSwitch;
  final VoidCallback? onLeave;
  final VoidCallback? onShowParticipants;

  /// Ouvre la feuille GPS du parcours du groupe, avec le contexte du bouton
  /// (ancre du partage sur iPad). `null` : pas de bouton « GPS ».
  final ValueChanged<BuildContext>? onOpenGps;

  /// Un export lancé depuis cette carte est en cours.
  final bool gpsLoading;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return PdlCard(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _titleRow(context, c, t),
          ?_departure(c, t),
          const SizedBox(height: PdlSpacing.cardTight),
          PublicationStatsLine(
            distanceMeters: group.distance,
            elevationGainMeters: group.elevationGain,
            speedKmh: group.averageSpeed,
            units: units,
          ),
          if (RideGroupWeatherLine.shows(weatherLeg)) ...<Widget>[
            const SizedBox(height: PdlSpacing.badgeGap),
            RideGroupWeatherLine(
              key: keys.ride.groupWeatherLine(group.id),
              leg: weatherLeg,
              timezone: timezone,
              units: units,
            ),
          ],
          if (group.leader != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.cardTight),
            _leaderRow(t, c),
          ],
          const SizedBox(height: PdlSpacing.cardTight),
          _participantsRow(context, c, t),
          if (onOpenGps != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.cardTight),
            GpsButton(
              key: keys.ride.groupGps(group.id),
              compact: true,
              loading: gpsLoading,
              onPressed: onOpenGps,
            ),
          ],
          // « Changer pour Groupe 2 » en pleine largeur, au pied : à côté du
          // nom il s'abrégeait dès que le groupe ne s'appelait pas « A ».
          if (action == RideGroupAction.switchTo) ...<Widget>[
            const SizedBox(height: PdlSpacing.cardTight),
            PdlButton(
              key: keys.ride.groupSwitchButton(group.id),
              label: 'rides.groupSwitchTo'.tr(
                namedArgs: <String, String>{'group': group.name},
              ),
              loadingLabel: 'rides.joining'.tr(),
              fullWidth: true,
              loading: pending,
              onPressed: onSwitch,
            ),
          ],
          if (action == RideGroupAction.leave) ...<Widget>[
            const SizedBox(height: PdlSpacing.badgeGap),
            RideGroupLeaveLink(
              linkKey: keys.ride.groupLeaveButton(group.id),
              pending: pending,
              onPressed: onLeave,
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────── en-tête
  Widget _titleRow(BuildContext context, PdlColors c, PdlTypography t) {
    final Widget? button = _button;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        PdlColorTrack(color: trackColor),
        const SizedBox(width: PdlSpacing.chipGap),
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  group.name,
                  style: t.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (group.registered) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                PdlBadge(
                  key: keys.ride.groupGoingBadge(group.id),
                  label: 'rides.registered'.tr(),
                  tone: PdlDerivedTones.registered(c),
                ),
              ],
            ],
          ),
        ),
        if (button != null) ...<Widget>[
          const SizedBox(width: PdlSpacing.chipGap),
          button,
        ],
        // La carte ouvre la page du groupe : le chevron le dit.
        if (onTap != null) ...<Widget>[
          const SizedBox(width: PdlSpacing.badgeGap),
          Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
        ],
      ],
    );
  }

  /// **Une seule action pleine et colorée** par carte : c'est ce bouton.
  /// Inscrite ici, rien : le badge « J'y vais » le dit, et « Quitter le
  /// groupe » est au pied de la carte.
  Widget? get _button => switch (action) {
    RideGroupAction.none ||
    RideGroupAction.leave ||
    RideGroupAction.switchTo => null,
    RideGroupAction.full => PdlButton(
      key: keys.ride.groupFullButton(group.id),
      label: 'rides.groupFull'.tr(),
      size: PdlButtonSize.sm,
      variant: PdlButtonVariant.outline,
      enabled: false,
    ),
    RideGroupAction.join => PdlButton(
      key: keys.ride.groupJoinButton(group.id),
      label: 'rides.groupJoin'.tr(),
      loadingLabel: 'rides.joining'.tr(),
      size: PdlButtonSize.sm,
      loading: pending,
      onPressed: onJoin,
    ),
  };

  // ──────────────────────────────────────────────────── ligne de départ
  /// L'heure du groupe, en bandeau sous son nom (BRANDING §7.8, ledger
  /// `BRAND-8`, comme la carte de groupe du web) : fond indigo très doux
  /// ([PdlColors.primaryFaint]), rayon 8 ; « Départ 22:30 » en 16/700 à
  /// l'horloge indigo, le jour quand il n'est pas celui de la sortie
  /// (« mer. 30 juil. »). Rien quand tous les groupes partent à l'heure de la
  /// sortie : le bloc de départ du détail la donne déjà.
  ///
  /// L'heure est un rendez-vous : lue d'un autre décalage, sa mention
  /// « heure de Tokyo (…) » suit (docs/LEDGER_*.md API-60).
  Widget? _departure(PdlColors c, PdlTypography t) {
    if (!showDeparture) return null;
    final DateTime? instant = DateTime.tryParse(group.startAt);
    final DateTime? rideInstant = DateTime.tryParse(rideDateTime);
    if (instant == null || rideInstant == null) return null;
    final DateTime wall = AppFormatters.toZoneTime(instant, timezone);
    final DateTime rideWall = AppFormatters.toZoneTime(rideInstant, timezone);
    final bool sameDay =
        wall.year == rideWall.year &&
        wall.month == rideWall.month &&
        wall.day == rideWall.day;
    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{'time': AppFormatters.formatTime(wall)},
    );
    final String? day = sameDay
        ? null
        : AppFormatters.formatDepartureDate(instant, timezone);

    return Padding(
      key: keys.ride.groupDeparture(group.id),
      padding: const EdgeInsets.only(top: PdlSpacing.chipGap),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.primaryFaint,
          borderRadius: PdlRadii.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PdlDepartureLine(
              headline: headline,
              trailing: day,
              semanticLabel: <String>[headline, ?day].join(', '),
            ),
            ?ZoneMentionLine.maybe(group.startAt, timezone),
          ],
        ),
      ),
    );
  }

  /// Meneur du groupe — rendu **seulement** si l'API en désigne un.
  ///
  /// `leader` nul est le cas courant, pas un cas dégradé : rien n'est rendu,
  /// et surtout **jamais** un repli sur le créateur de la sortie, qui serait le
  /// même sur tous ses groupes.
  Widget _leaderRow(PdlTypography t, PdlColors c) {
    final PublicUserDto leader = group.leader!;
    return Row(
      key: keys.ride.groupLeader(group.id),
      children: <Widget>[
        PdlAvatar(
          name: leader.displayName,
          imageUrl: leader.avatarUrl,
          size: 24,
          isCurrentUser: leader.id == currentUserId,
        ),
        const SizedBox(width: PdlSpacing.chipGap),
        Icon(PdlIcons.leader, size: 14, color: c.textDimmed),
        const SizedBox(width: PdlSpacing.badgeGap),
        Flexible(
          child: Text(
            'rides.leaderIs'.tr(
              namedArgs: <String, String>{'name': leader.displayName},
            ),
            style: t.count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────── ligne 3
  Widget _participantsRow(BuildContext context, PdlColors c, PdlTypography t) {
    final int? max = group.maxParticipants;
    // La maquette met ce compteur en `xs` **gras et en couleur de texte**, pas
    // en `count` estompé : c'est l'information qui décide si l'on peut encore
    // entrer dans le groupe.
    final TextStyle countStyle = t.xs.copyWith(
      color: c.text,
      fontWeight: FontWeight.w600,
    );

    // Un groupe complet ne montre pas des visages, il montre qu'il est plein :
    // la barre de places remplace la grappe d'avatars, et le compteur tombe à
    // « 18/18 », sans le mot « participants » qui n'ajoute rien ici.
    if (group.full && max != null) {
      return Row(
        children: <Widget>[
          Expanded(
            child: PdlProgressBar(
              value: 1,
              semanticLabel: _countLabel(max),
              color: c.danger,
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          Text('${group.countParticipants}/$max', style: countStyle),
        ],
      );
    }

    // La grappe sans la personne capitaine : la ligne « Capitaine : … »
    // au-dessus la nomme déjà (KIT §8, docs/LEDGER_*.md MOB-139, N10). Le
    // compteur, lui, la compte toujours.
    final String? leaderId = group.leader?.id;
    final List<PublicUserDto> faces = <PublicUserDto>[
      for (final PublicUserDto p in group.participants)
        if (p.id != leaderId) p,
    ];
    final int facesTotal =
        group.countParticipants - (group.participants.length - faces.length);

    // Les visages et « 11/12 personnes » forment un bloc qui ne s'abrège
    // jamais ; « Voir tout » passe à la ligne s'il n'a plus la place
    // (docs/LEDGER_*.md MOB-139, N2 — « 11/12 p… » à côté de « Voir tout »).
    final Widget count = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (faces.isNotEmpty) ...<Widget>[
          PdlAvatarStack(
            key: keys.ride.groupAvatars(group.id),
            people: <PdlAvatarEntry>[
              for (final PublicUserDto p in faces)
                PdlAvatarEntry(
                  name: p.displayName,
                  imageUrl: p.avatarUrl,
                  isCurrentUser: p.id == currentUserId,
                ),
            ],
            total: facesTotal,
            onTap: onShowParticipants,
            semanticLabel: _countLabel(max),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
        ],
        Flexible(
          child: Text(
            _countLabel(max),
            key: keys.ride.groupCount(group.id),
            style: countStyle,
          ),
        ),
      ],
    );

    // « Voir tout » n'est offert que sur la carte sélectionnée : dix groupes
    // portant chacun quatre lignes pleines dépassent l'écran. Les avatars,
    // eux, restent cliquables partout.
    if (!selected || onShowParticipants == null) return count;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        count,
        PdlButton(
          label: 'common.viewAll'.tr(),
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          onPressed: onShowParticipants,
        ),
      ],
    );
  }

  String _countLabel(int? max) => max == null
      ? 'rides.participants'.plural(
          group.countParticipants,
          namedArgs: <String, String>{'count': '${group.countParticipants}'},
        )
      : 'rides.participantsOf'.plural(
          max,
          namedArgs: <String, String>{
            'count': '${group.countParticipants}',
            'max': '$max',
          },
        );
}
