import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';

/// Le meneur d'un groupe — rendu **seulement** si l'API en désigne un :
/// `RideGroupDto.leader` nul est le cas courant, et il n'y a jamais de repli
/// sur le créateur de la sortie. Partagé par l'Aperçu de la page d'un groupe
/// et le détail d'une sortie solo (ledgers `MOB-67`, `MOB-69`).
class RideGroupLeaderRow extends ConsumerWidget {
  const RideGroupLeaderRow({super.key, required this.group});

  final RideGroupDto group;

  /// Vrai quand la ligne a quelque chose à rendre.
  static bool shows(RideGroupDto group) => group.leader != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PublicUserDto? leader = group.leader;
    if (leader == null) return const SizedBox.shrink();
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    return Row(
      key: keys.rideGroup.leader,
      children: <Widget>[
        PdlAvatar(
          name: leader.displayName,
          imageUrl: leader.avatarUrl,
          size: 32,
          isCurrentUser: leader.id == currentUserId,
        ),
        const SizedBox(width: PdlSpacing.chipGap),
        Flexible(
          child: Text(
            leader.displayName,
            style: t.bodyStrong,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: PdlSpacing.chipGap),
        PdlBadge(
          label: 'rides.groupPage.leader'.tr(),
          tone: PdlDerivedTones.registered(c),
          icon: PdlIcons.leader,
        ),
      ],
    );
  }
}
