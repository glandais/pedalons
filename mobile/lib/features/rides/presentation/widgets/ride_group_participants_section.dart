import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../participants/presentation/widgets/participants_sheet.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_registration_controller.dart';
import 'ride_group_leader_row.dart';
import 'ride_registration_control.dart';

/// La section « Personnes inscrites » d'un groupe (ledger `MOB-134`, KIT §8,
/// maquettes `groupe-mobile-cible`, `groupe-inscrit-mobile-cible`) :
///
/// 1. le titre et, à droite, le compte (« 8/12 », « 8 » sans plafond) ;
/// 2. la barre de places et « 4 places restantes » (avec un plafond) ;
/// 3. la personne capitaine et son badge — **rien** quand `leader` est nul,
///    jamais de repli sur le créateur de la sortie ;
/// 4. la grappe d'avatars, **sans** la personne capitaine, déjà nommée ;
/// 5. « Voir toutes les personnes inscrites », qui ouvre [ParticipantsSheet] ;
/// 6. inscrit dans ce groupe, la sortie maintenue : le lien discret
///    « Quitter le groupe », sans confirmation — même une fois le groupe
///    parti, pour corriger qui est vraiment venu ([rideGroupCanLeave]).
///
/// **Aucun nom pour un non-membre** (`permissions.canSeeParticipants`, calculé
/// par le backend, docs/LEDGER_*.md MOB-137) : le compte,
/// la barre et les places seulement — ni capitaine, ni visages, ni liste.
class RideGroupParticipantsSection extends ConsumerWidget {
  const RideGroupParticipantsSection({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.group,
    this.now,
  });

  final RideKey rideKey;
  final RideDto ride;
  final RideGroupDto group;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final bool canSeeNames = ride.permissions.canSeeParticipants ?? false;
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    final int count = group.countParticipants;
    final int? max = group.maxParticipants;
    final int? left = max == null ? null : (max - count).clamp(0, max);

    final PublicUserDto? leader = canSeeNames ? group.leader : null;
    // La grappe sans la personne capitaine, déjà nommée au-dessus (KIT §8) :
    // le « +N » se compte sans elle quand elle est parmi les inscrites.
    final List<PublicUserDto> others = <PublicUserDto>[
      for (final PublicUserDto p in group.participants)
        if (p.id != leader?.id) p,
    ];
    final bool leaderListed =
        leader != null &&
        group.participants.any((PublicUserDto p) => p.id == leader.id);
    final int othersTotal = leaderListed ? count - 1 : count;

    final bool canLeave = rideGroupCanLeave(ride, group, now: now);
    final bool pending =
        ref.watch(rideRegistrationProvider(rideKey)).pendingGroupId == group.id;

    return DetailSection(
      title: 'rides.groupPage.participantsTitle'.tr(),
      count: max == null ? '$count' : '$count/$max',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (max != null)
            Column(
              key: keys.rideGroup.participantsCount,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PdlProgressBar(
                  value: max == 0 ? 1 : count / max,
                  semanticLabel: 'rides.groupPage.participantsTitle'.tr(),
                ),
                // Plein, la barre rouge le dit : rien à compter.
                if (!group.full && left! > 0) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  Text('rides.groupPage.placesLeft'.plural(left), style: t.xs),
                ],
              ],
            ),
          if (leader != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.cardTight),
            RideGroupLeaderRow(group: group),
          ],
          if (canSeeNames) ...<Widget>[
            if (others.isNotEmpty) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PdlAvatarStack(
                  key: keys.rideGroup.participantsAvatars,
                  people: <PdlAvatarEntry>[
                    for (final PublicUserDto p in others)
                      PdlAvatarEntry(
                        name: p.displayName,
                        imageUrl: p.avatarUrl,
                        isCurrentUser: p.id == currentUserId,
                      ),
                  ],
                  total: othersTotal,
                  onTap: () => ParticipantsSheet.open(context, ride, group),
                  semanticLabel: 'rides.participants'.plural(
                    count,
                    namedArgs: <String, String>{'count': '$count'},
                  ),
                ),
              ),
            ] else if (count == 0) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              Text('participants.emptyMessage'.tr(), style: t.sub),
            ],
            if (count > 0)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PdlButton(
                  key: keys.rideGroup.viewAllParticipants,
                  label: 'rides.groupPage.viewAllParticipants'.tr(),
                  variant: PdlButtonVariant.text,
                  size: PdlButtonSize.sm,
                  icon: PdlIcons.chevronRight,
                  onPressed: () => ParticipantsSheet.open(context, ride, group),
                ),
              ),
          ],
          if (canLeave)
            RideGroupLeaveLink(
              pending: pending,
              onPressed: () => ref
                  .read(rideRegistrationProvider(rideKey).notifier)
                  .leave(group.id),
            ),
        ],
      ),
    );
  }
}

/// « Quitter le groupe » : un lien discret en couleur de danger, sur 44 px
/// de haut — pas un bouton à contour, qui pèserait autant que « Rejoindre ».
/// Au pied de « Personnes inscrites » (page d'un groupe, sortie solo) et de
/// la carte de son groupe (sortie à plusieurs groupes, docs/LEDGER_*.md
/// MOB-134, lot 8). [linkKey] : `keys.rideGroup.leaveButton` par défaut.
class RideGroupLeaveLink extends StatelessWidget {
  const RideGroupLeaveLink({
    super.key,
    required this.pending,
    required this.onPressed,
    this.linkKey,
  });

  final bool pending;
  final VoidCallback? onPressed;
  final Key? linkKey;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        enabled: !pending,
        child: InkWell(
          key: linkKey ?? keys.rideGroup.leaveButton,
          onTap: pending ? null : onPressed,
          borderRadius: PdlRadii.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: Text(
                pending ? 'rides.leaving'.tr() : 'rides.groupLeaveLong'.tr(),
                style: t.sub.copyWith(
                  color: pending ? c.textDimmed : c.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
