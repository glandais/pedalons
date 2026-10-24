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
import '../../../../core/widgets/zone_mention_line.dart';
import '../../domain/group_start.dart';
import '../../domain/ride_group_action.dart';
import 'ride_group_weather_line.dart';
import '../../../../keys.dart';

/// La carte d'un groupe de sortie — **le choix de groupe lui-même**.
///
/// Elle remplace l'`AlertDialog` aveugle de la v1, qui demandait de choisir un
/// groupe en n'en montrant que le nom et l'heure. Ici l'action vit sur la carte
/// qui porte l'information : horaire, allure, distance, dénivelé, places
/// restantes et visages déjà inscrits.
///
/// Elle ne décide de rien : [action] est calculée par [rideGroupAction] et
/// [pending] par le contrôleur d'inscription (S12-3). La carte rend.
class RideGroupCard extends StatelessWidget {
  const RideGroupCard({
    super.key,
    required this.group,
    required this.rideDateTime,
    required this.timezone,
    required this.action,
    required this.trackColor,
    required this.units,
    this.selected = false,
    this.pending = false,
    this.currentUserId,
    this.weatherLeg,
    this.onTap,
    this.onJoin,
    this.onLeave,
    this.onShowParticipants,
    this.onExportGpx,
    this.onExportFit,
    this.onSendToDevice,
  });

  final RideGroupDto group;

  /// Le départ de la sortie (instant du contrat) : le groupe n'affiche son
  /// heure que s'il part à une autre (docs/LEDGER_*.md API-60).
  final String rideDateTime;

  /// Le fuseau de la sortie, où se lit l'heure du groupe.
  final String timezone;

  final RideGroupAction action;

  /// Couleur du parcours du groupe sur la carte de la sortie
  /// (`groupTrackColorIndex` dans `kMultiTrackPalette`), partagée par les
  /// groupes qui roulent le même parcours — c'est le lien visuel entre les deux.
  final Color trackColor;

  final UnitSystem units;

  /// Groupe pointé par la sélection croisée (carte, légende, profil).
  final bool selected;

  /// Un appel d'inscription ou de désinscription est en vol **sur ce groupe**.
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
  final VoidCallback? onLeave;
  final VoidCallback? onShowParticipants;
  final VoidCallback? onExportGpx;
  final VoidCallback? onExportFit;
  final VoidCallback? onSendToDevice;

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
          const SizedBox(height: PdlSpacing.cardTight),
          _statsRow(),
          // L'heure propre du groupe est un rendez-vous : lue d'un autre
          // décalage, sa mention « heure de Tokyo (…) » en seconde ligne,
          // comme l'icône à info-bulle du web (docs/LEDGER_*.md API-60).
          if (groupLeavesAtOwnTime(group.startAt, rideDateTime))
            if (ZoneMentionLine.maybe(group.startAt, timezone)
                case final Widget mention) ...<Widget>[
              const SizedBox(height: 4),
              mention,
            ],
          if (RideGroupWeatherLine.shows(weatherLeg)) ...<Widget>[
            const SizedBox(height: PdlSpacing.cardTight),
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
          if (_hasTextActions) ...<Widget>[
            const SizedBox(height: 4),
            _textActions(),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────── ligne 1
  Widget _titleRow(BuildContext context, PdlColors c, PdlTypography t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        PdlColorTrack(color: trackColor),
        const SizedBox(width: PdlSpacing.chipGap),
        Expanded(
          child: Text(
            group.name,
            style: t.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (group.registered) ...<Widget>[
          const SizedBox(width: PdlSpacing.badgeGap),
          PdlBadge(
            label: 'rides.registered'.tr(),
            tone: PdlDerivedTones.registered(c),
            icon: PdlIcons.check,
          ),
        ],
        if (_button != null) ...<Widget>[
          const SizedBox(width: PdlSpacing.chipGap),
          _button!,
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
  Widget? get _button => switch (action) {
    RideGroupAction.none => null,
    RideGroupAction.leave => PdlButton(
      key: keys.ride.groupLeaveButton(group.id),
      label: 'rides.groupLeave'.tr(),
      loadingLabel: 'rides.leaving'.tr(),
      variant: PdlButtonVariant.outline,
      size: PdlButtonSize.sm,
      loading: pending,
      onPressed: onLeave,
    ),
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

  // ───────────────────────────────────────────────────────────── ligne 2
  /// Heure · vitesse · **distance** · **D+**.
  ///
  /// `distance` et `elevationGain` sont portés par `RideGroupDto` depuis la
  /// 1.3.0 : cette ligne ne coûte plus un `getRoute` par groupe.
  Widget _statsRow() {
    final List<PdlStat> stats = <PdlStat>[
      if (groupLeavesAtOwnTime(group.startAt, rideDateTime))
        PdlStat(
          value: formatGroupStart(group.startAt, timezone),
          icon: PdlIcons.time,
        ),
      if (group.averageSpeed != null)
        PdlStat(
          value: AppFormatters.formatSpeed(group.averageSpeed!, units),
          icon: PdlIcons.speed,
        ),
      if (group.distance != null)
        PdlStat(
          value: AppFormatters.formatDistance(group.distance!, units),
          icon: PdlIcons.distance,
        ),
      if (group.elevationGain != null)
        PdlStat(
          value: AppFormatters.formatElevation(group.elevationGain!, units),
          icon: PdlIcons.elevationUp,
          trend: PdlStatTrend.up,
        ),
    ];
    // `nowrap` = gouttière serrée, avec le repli assuré par `PdlStatRow` : dès
    // que les quatre valeurs ne tiennent plus, la rangée passe en deux lignes
    // plutôt que de rogner le dénivelé, systématiquement le dernier et donc le
    // sacrifié.
    return PdlStatRow(stats: stats, nowrap: true);
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

    return Row(
      children: <Widget>[
        if (group.participants.isNotEmpty) ...<Widget>[
          PdlAvatarStack(
            people: <PdlAvatarEntry>[
              for (final PublicUserDto p in group.participants)
                PdlAvatarEntry(
                  name: p.displayName,
                  imageUrl: p.avatarUrl,
                  isCurrentUser: p.id == currentUserId,
                ),
            ],
            total: group.countParticipants,
            onTap: onShowParticipants,
            semanticLabel: _countLabel(max),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
        ],
        Flexible(
          child: Text(
            _countLabel(max),
            style: countStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // « Voir tout » n'est offert que sur la carte sélectionnée : dix
        // groupes portant chacun quatre lignes pleines dépassent l'écran. Les
        // avatars, eux, restent cliquables partout.
        if (selected && onShowParticipants != null) ...<Widget>[
          const Spacer(),
          PdlButton(
            label: 'common.viewAll'.tr(),
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            onPressed: onShowParticipants,
          ),
        ],
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

  // ───────────────────────────────────────────────────────────── ligne 4
  bool get _hasTextActions =>
      onExportGpx != null || onExportFit != null || onSendToDevice != null;

  // Une seule ligne : GPX et FIT gardent leur taille, l'envoi vers un appareil
  // prend le reste et s'abrège plutôt que de passer à la ligne.
  Widget _textActions() {
    return Row(
      spacing: PdlSpacing.badgeGap,
      children: <Widget>[
        if (onExportGpx != null)
          PdlButton(
            key: keys.ride.groupExportGpx(group.id),
            label: 'routes.exportGpx'.tr(),
            icon: PdlIcons.gpx,
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            onPressed: onExportGpx,
          ),
        if (onExportFit != null)
          PdlButton(
            key: keys.ride.groupExportFit(group.id),
            label: 'routes.exportFit'.tr(),
            icon: PdlIcons.gpx,
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            onPressed: onExportFit,
          ),
        if (onSendToDevice != null)
          Flexible(
            child: PdlButton(
              key: keys.ride.groupSendToDevice(group.id),
              label: 'routes.sendToDevice'.tr(),
              icon: PdlIcons.device,
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: onSendToDevice,
            ),
          ),
      ],
    );
  }
}
