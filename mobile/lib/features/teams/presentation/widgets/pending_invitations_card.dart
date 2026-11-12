import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../data/invitations_repository.dart';
import '../../providers/membership_scoped_content.dart';
import '../../providers/team_providers.dart';

/// « Vous avez des invitations en attente », en tête de « Mes équipes ».
///
/// Le pendant du `PendingInvitationsBanner` du web. Il rattrape deux cas que
/// rien d'autre ne couvre : la notification `TEAM_INVITATION`, qui ouvre cet
/// écran, et la personne invitée avant d'avoir un compte qui s'inscrit par le
/// formulaire ordinaire — s'inscrire n'est pas rejoindre une équipe, et ses
/// invitations dormiraient sinon jusqu'à expirer.
///
/// Rien ne s'affiche tant que la liste charge, échoue ou est vide : c'est un
/// rappel, pas un état de l'écran. Une acceptation réussie se voit d'elle-même
/// — l'invitation quitte la carte et l'équipe entre dans la liste — et un échec
/// reste affiché dans la carte, avec sa cause, plutôt qu'en snackbar.
class PendingInvitationsCard extends ConsumerStatefulWidget {
  const PendingInvitationsCard({super.key});

  @override
  ConsumerState<PendingInvitationsCard> createState() =>
      _PendingInvitationsCardState();
}

class _PendingInvitationsCardState
    extends ConsumerState<PendingInvitationsCard> {
  /// L'invitation en cours d'acceptation. Une seule à la fois : les autres
  /// boutons sont désactivés le temps de l'appel.
  String? _accepting;
  String? _error;

  Future<void> _accept(MyInvitationDto invitation) async {
    setState(() {
      _accepting = invitation.id;
      _error = null;
    });
    try {
      await ref.read(invitationsRepositoryProvider).accept(invitation.id);
      ref.invalidate(myInvitationsProvider);
      ref.invalidate(myTeamsProvider);
      invalidateMembershipScopedContent((p) => ref.invalidate(p));
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<MyInvitationDto> invitations =
        ref.watch(myInvitationsProvider).value ?? const <MyInvitationDto>[];
    if (invitations.isEmpty) return const SizedBox.shrink();

    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.section,
        PdlSpacing.section,
        0,
      ),
      child: PdlCard(
        key: keys.teams.pendingInvitationsCard,
        selected: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(PdlIcons.invitation, size: 20, color: c.primary),
                const SizedBox(width: PdlSpacing.chipGap),
                Expanded(
                  child: Text(
                    'invitations.pending.title'.plural(invitations.length),
                    style: t.bodyStrong,
                  ),
                ),
              ],
            ),
            for (final MyInvitationDto invitation in invitations)
              Padding(
                padding: const EdgeInsets.only(top: PdlSpacing.chipGap),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'invitations.pending.line'.tr(
                          namedArgs: <String, String>{
                            'inviter': invitation.inviterName,
                            'team': invitation.team.name,
                          },
                        ),
                        style: t.sub,
                      ),
                    ),
                    const SizedBox(width: PdlSpacing.chipGap),
                    PdlButton(
                      key: keys.teams.invitationAcceptButton(
                        invitation.team.slug,
                      ),
                      label: 'invitations.pending.accept'.tr(),
                      size: PdlButtonSize.sm,
                      loading: _accepting == invitation.id,
                      loadingLabel: 'invitations.pending.accepting'.tr(),
                      onPressed: _accepting == null
                          ? () => _accept(invitation)
                          : null,
                    ),
                  ],
                ),
              ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              PdlBanner(tone: PdlBannerTone.danger, message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}
