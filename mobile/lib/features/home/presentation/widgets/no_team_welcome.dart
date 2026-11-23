import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../../teams/data/invitations_repository.dart';
import '../../../teams/providers/membership_scoped_content.dart';
import '../../../teams/providers/team_providers.dart';

/// L'accueil de qui n'est membre d'aucune équipe, à la place de « Ma prochaine
/// sortie », de la semaine et de « Mes équipes » — trois états vides qui ne
/// disaient pas quoi faire en premier (docs/LEDGER_*.md WEB-194).
///
/// Un seul bloc, dans cet ordre : les invitations en attente, avec
/// « Rejoindre » sur place ; « Trouver une équipe » ; « Créer mon équipe ». Pas
/// de carrousel ni de tutoriel (écarté par la recherche du 22 novembre 2026).
/// Le bloc disparaît avec la première équipe : rejoindre invalide
/// [myTeamsProvider], et l'accueil retrouve ses cartes habituelles.
///
/// La première étape qui s'applique est le bouton plein, les autres en contour.
/// « Trouver une équipe » est caché sur un site mono-équipe
/// (`ConfigDto.singleTeam`), et tant que la configuration n'est pas connue.
class NoTeamWelcome extends ConsumerStatefulWidget {
  const NoTeamWelcome({super.key});

  @override
  ConsumerState<NoTeamWelcome> createState() => _NoTeamWelcomeState();
}

class _NoTeamWelcomeState extends ConsumerState<NoTeamWelcome> {
  /// L'invitation en cours d'acceptation : une seule à la fois.
  String? _accepting;
  Object? _error;

  Future<void> _join(MyInvitationDto invitation) async {
    setState(() {
      _accepting = invitation.id;
      _error = null;
    });
    try {
      await ref.read(invitationsRepositoryProvider).accept(invitation.id);
      ref.invalidate(myInvitationsProvider);
      ref.invalidate(myTeamsProvider);
      invalidateMembershipScopedContent((p) => ref.invalidate(p));
      if (mounted) pushLocation(context, Paths.team(invitation.team.slug));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final List<MyInvitationDto> invitations =
        ref.watch(myInvitationsProvider).value ?? const <MyInvitationDto>[];
    final bool hasInvitations = invitations.isNotEmpty;
    final bool canBrowse =
        ref.watch(appConfigProvider).value?.singleTeam == false;
    final Object? error = _error;

    return Padding(
      padding: const EdgeInsets.all(PdlSpacing.section),
      child: PdlCard(
        key: keys.home.noTeamWelcome,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('home.noTeam.title'.tr(), style: t.screenTitle),
            const SizedBox(height: PdlSpacing.chipGap),
            Text(
              'home.noTeam.subtitle'.tr(),
              style: t.sub.copyWith(color: c.textDimmed),
            ),
            if (hasInvitations) ...<Widget>[
              const SizedBox(height: PdlSpacing.section),
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
                        key: keys.home.noTeamJoinButton(invitation.team.slug),
                        label: 'home.noTeam.join'.tr(),
                        size: PdlButtonSize.sm,
                        loading: _accepting == invitation.id,
                        loadingLabel: 'invitations.pending.accepting'.tr(),
                        onPressed: _accepting == null
                            ? () => _join(invitation)
                            : null,
                      ),
                    ],
                  ),
                ),
              if (error != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.chipGap),
                PdlBanner(
                  tone: PdlBannerTone.danger,
                  message: getErrorMessage(error),
                ),
              ],
            ],
            if (canBrowse) ...<Widget>[
              const SizedBox(height: PdlSpacing.section),
              _Step(
                title: 'home.noTeam.find.title'.tr(),
                description: 'home.noTeam.find.description'.tr(),
                action: PdlButton(
                  key: keys.home.noTeamFindButton,
                  label: 'home.noTeam.find.action'.tr(),
                  icon: PdlIcons.search,
                  fullWidth: true,
                  variant: hasInvitations
                      ? PdlButtonVariant.outline
                      : PdlButtonVariant.fill,
                  onPressed: () => context.push(Paths.teamsDiscover()),
                ),
              ),
            ],
            const SizedBox(height: PdlSpacing.section),
            _Step(
              title: 'home.noTeam.create.title'.tr(),
              description: 'home.noTeam.create.description'.tr(),
              action: PdlButton(
                key: keys.home.noTeamCreateButton,
                label: 'home.noTeam.create.action'.tr(),
                icon: PdlIcons.add,
                fullWidth: true,
                variant: hasInvitations || canBrowse
                    ? PdlButtonVariant.outline
                    : PdlButtonVariant.fill,
                onPressed: () => context.push(Paths.teamsNew()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une étape : son titre, une ligne d'explication, son bouton.
class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.description,
    required this.action,
  });

  final String title;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: t.bodyStrong),
        const SizedBox(height: 2),
        Text(description, style: t.sub.copyWith(color: context.pdl.textDimmed)),
        const SizedBox(height: PdlSpacing.chipGap),
        action,
      ],
    );
  }
}
