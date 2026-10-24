import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/ride_group_action.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_registration_controller.dart';

/// La barre d'inscription de la page d'un groupe, collée en bas (ledger
/// `MOB-67`) — et celle du détail d'une sortie solo (ledger `MOB-69`).
///
/// À gauche les places — « 11/12 personnes », « 1 place restante » —, à
/// droite **la** seule action pleine de la page : « Rejoindre ». « Quitter »
/// est en contour, un groupe complet n'a qu'un badge, une sortie terminée ou
/// annulée rien ([rideGroupAction]).
///
/// La règle du serveur est **un groupe par sortie** (`RideService.joinGroup`
/// répond 409 `ALREADY_REGISTERED`, et ne déplace jamais personne) : inscrit
/// dans un autre groupe, on ne voit donc pas « Rejoindre », mais « Vous êtes
/// inscrit dans le groupe X. » et le lien vers ce groupe. La bascule
/// « quitter puis rejoindre » reste sur les cartes du détail.
class RideGroupActionBar extends ConsumerWidget {
  const RideGroupActionBar({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.group,
    this.onOpenGroup,
  });

  final RideKey rideKey;
  final RideDto ride;
  final RideGroupDto group;

  /// Passe la page sur un autre groupe de la sortie. `null` sur le détail
  /// d'une sortie solo (ledger `MOB-69`) : avec un seul groupe, on n'est
  /// jamais inscrit ailleurs, et il n'y a pas d'autre groupe où aller.
  final ValueChanged<String>? onOpenGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    // Inconnue, l'appartenance n'éteint rien : le 403 répondra, et son
    // bandeau est plus juste qu'un bouton absent sans explication.
    final bool isMember =
        ref.watch(teamMembershipProvider(ride.team.slug)) ?? true;
    final RideRegistrationState registration = ref.watch(
      rideRegistrationProvider(rideKey),
    );
    final RideRegistrationController controller = ref.read(
      rideRegistrationProvider(rideKey).notifier,
    );
    final bool pending = registration.pendingGroupId == group.id;

    final RideGroupDto? mine = ride.joinedGroup;
    final RideGroupDto? elsewhere = mine != null && mine.id != group.id
        ? mine
        : null;
    final RideGroupAction action = elsewhere != null
        ? RideGroupAction.none
        : rideGroupAction(ride: ride, group: group, isMember: isMember);

    final int? max = group.maxParticipants;
    final String count = max == null
        ? 'rides.groupPage.participantsCountNoMax'.plural(
            group.countParticipants,
            namedArgs: <String, String>{'count': '${group.countParticipants}'},
          )
        : 'rides.groupPage.participantsCount'.plural(
            max,
            namedArgs: <String, String>{
              'count': '${group.countParticipants}',
              'max': '$max',
            },
          );
    final int? left = max == null
        ? null
        : (max - group.countParticipants).clamp(0, max);

    final Widget? trailing = switch (action) {
      RideGroupAction.none => null,
      RideGroupAction.join => PdlButton(
        key: keys.rideGroup.joinButton,
        label: 'rides.groupJoin'.tr(),
        loadingLabel: 'rides.joining'.tr(),
        loading: pending,
        onPressed: () => controller.join(group.id),
      ),
      RideGroupAction.leave => PdlButton(
        key: keys.rideGroup.leaveButton,
        label: 'rides.groupLeave'.tr(),
        loadingLabel: 'rides.leaving'.tr(),
        variant: PdlButtonVariant.outline,
        loading: pending,
        onPressed: () => controller.leave(group.id),
      ),
      RideGroupAction.full => PdlBadge(
        key: keys.rideGroup.fullBadge,
        label: 'rides.groupFull'.tr(),
        tone: PdlFamily.gray.soft(c),
        size: PdlBadgeSize.lg,
      ),
    };

    return PdlActionBar(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    count,
                    key: keys.rideGroup.participantsCount,
                    style: t.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (left != null && !group.full)
                    Text(
                      'rides.groupPage.placesLeft'.plural(left),
                      style: t.xs,
                    ),
                  if (elsewhere != null) ...<Widget>[
                    Text(
                      'rides.groupPage.registeredElsewhere'.tr(
                        namedArgs: <String, String>{'group': elsewhere.name},
                      ),
                      key: keys.rideGroup.registeredElsewhere,
                      style: t.xs.copyWith(color: c.text),
                    ),
                    if (onOpenGroup != null)
                      PdlButton(
                        key: keys.rideGroup.viewMyGroup,
                        label: 'rides.groupPage.viewMyGroup'.tr(),
                        variant: PdlButtonVariant.text,
                        size: PdlButtonSize.sm,
                        onPressed: () => onOpenGroup!(elsewhere.id),
                      ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: PdlSpacing.chipGap),
              trailing,
            ],
          ],
        ),
      ],
    );
  }
}
