import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../config/router.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/providers/pending_sign_in_link.dart';
import '../../data/invitations_repository.dart';
import '../../providers/membership_scoped_content.dart';
import '../../providers/team_providers.dart';

/// L'aperçu public d'un lien d'invitation, par jeton.
final invitationPreviewProvider = FutureProvider.autoDispose
    .family<InvitationPreviewDto, String>(
      (ref, token) => ref.watch(invitationsRepositoryProvider).preview(token),
    );

/// Où mène le lien d'un e-mail d'invitation (`/invitation?token=…`), docs/LEDGER_*.md MOB-179.
///
/// Le pendant de l'`AcceptInvitationPage` du site, pour les trois cas : connecté,
/// déconnecté avec un compte, déconnecté sans compte. L'aperçu est public — la
/// page dit qui invite, et à quoi, avant toute connexion. Hors session, « Se
/// connecter ou créer un compte » garde le lien dans [PendingSignInLink] : la
/// connexion, comme l'activation d'un compte créé entre-temps, y ramène
/// (`goAfterSignIn`). Rejoindre mène à la page de l'équipe, sa pile dessous.
///
/// Si l'app est fermée entre l'inscription et l'activation, le lien gardé est
/// perdu : l'invitation attend alors sur l'accueil (`PendingInvitationsCard`).
class InvitationPage extends ConsumerStatefulWidget {
  const InvitationPage({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends ConsumerState<InvitationPage> {
  bool _accepting = false;
  Object? _acceptError;

  String get _location => '${Paths.invitation()}?token=${widget.token}';

  Future<void> _accept(InvitationPreviewDto invitation) async {
    setState(() {
      _accepting = true;
      _acceptError = null;
    });
    try {
      await ref.read(invitationsRepositoryProvider).acceptToken(widget.token!);
      ref.invalidate(myInvitationsProvider);
      ref.invalidate(myTeamsProvider);
      invalidateMembershipScopedContent((p) => ref.invalidate(p));
      if (!mounted) return;
      openWithHierarchy(
        ref.read(routerProvider),
        Paths.team(invitation.teamSlug),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _acceptError = error;
          _accepting = false;
        });
      }
    }
  }

  /// Hors session : la connexion, ou la création d'un compte depuis la même
  /// page, puis retour ici.
  void _signIn() {
    ref.read(pendingSignInLinkProvider).location = _location;
    context.go(Paths.login());
  }

  /// Connecté avec un autre compte que celui de l'adresse invitée : se
  /// déconnecter, puis revenir ici une fois reconnecté. La déconnexion efface le
  /// lien en attente : il n'est posé qu'après.
  Future<void> _switchAccount() async {
    setState(() => _accepting = true);
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    setState(() => _accepting = false);
    _signIn();
  }

  void _leave() => context.go(Paths.home());

  @override
  Widget build(BuildContext context) {
    final String? token = widget.token;
    return PdlScreenScaffold(
      appBar: PdlAppBar(onBack: _leave, backSemanticLabel: 'common.back'.tr()),
      body: token == null || token.isEmpty
          ? _unavailable(null)
          : ref
                .watch(invitationPreviewProvider(token))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _unavailable(error),
                  data: _ready,
                ),
    );
  }

  Widget _unavailable(Object? error) {
    return PdlEmptyState(
      key: keys.invitation.unavailable,
      variant: PdlEmptyVariant.notFound,
      icon: PdlIcons.invitation,
      title: 'invitations.page.unavailableTitle'.tr(),
      message: error == null
          ? 'invitations.page.unavailableBody'.tr()
          : getErrorMessage(error),
      actions: <Widget>[
        PdlButton(
          label: 'invitations.page.backHome'.tr(),
          variant: PdlButtonVariant.outline,
          onPressed: _leave,
        ),
      ],
    );
  }

  Widget _ready(InvitationPreviewDto invitation) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool signedIn = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );

    return ListView(
      padding: const EdgeInsets.all(PdlSpacing.section),
      children: <Widget>[
        Icon(PdlIcons.invitation, size: 48, color: c.primary),
        const SizedBox(height: PdlSpacing.section),
        Text(
          'invitations.page.title'.tr(
            namedArgs: <String, String>{
              'inviter': invitation.inviterName,
              'team': invitation.teamName,
            },
          ),
          key: keys.invitation.title,
          style: t.screenTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        Text(
          'invitations.page.subtitle'.tr(
            namedArgs: <String, String>{
              'role': 'roles.${invitation.role.toLowerCase()}'.tr(),
              'email': invitation.maskedEmail,
            },
          ),
          style: t.sub.copyWith(color: c.textDimmed),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PdlSpacing.section),
        ..._actions(invitation, signedIn),
      ],
    );
  }

  List<Widget> _actions(InvitationPreviewDto invitation, bool signedIn) {
    if (!invitation.redeemable) {
      return <Widget>[_spent(invitation, signedIn)];
    }
    if (!signedIn) {
      return <Widget>[
        Text('invitations.page.signInPrompt'.tr(), textAlign: TextAlign.center),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlButton(
          key: keys.invitation.signInButton,
          label: 'invitations.page.signIn'.tr(),
          fullWidth: true,
          onPressed: _signIn,
        ),
      ];
    }
    final Object? error = _acceptError;
    return <Widget>[
      if (error != null) ...<Widget>[
        PdlBanner(
          key: keys.invitation.acceptError,
          tone: PdlBannerTone.danger,
          message: getErrorMessage(error),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
      ],
      PdlButton(
        key: keys.invitation.joinButton,
        label: 'invitations.page.join'.tr(),
        fullWidth: true,
        loading: _accepting,
        onPressed: _accepting ? null : () => _accept(invitation),
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      PdlButton(
        key: keys.invitation.switchAccountButton,
        label: 'invitations.page.switchAccount'.tr(),
        variant: PdlButtonVariant.text,
        fullWidth: true,
        onPressed: _accepting ? null : () => unawaited(_switchAccount()),
      ),
    ];
  }

  /// Une invitation qui n'est plus en attente peut être celle que ce membre a
  /// déjà acceptée : rejouer le lien est un succès pour le serveur, il ne doit
  /// pas se lire « plus valide » ici. Seul un membre a un rôle dans l'équipe.
  Widget _spent(InvitationPreviewDto invitation, bool signedIn) {
    final bool member =
        signedIn &&
        ref.watch(teamDetailProvider(invitation.teamSlug)).value?.role != null;
    if (!member) {
      return PdlBanner(
        key: keys.invitation.notRedeemable,
        tone: PdlBannerTone.warn,
        message: 'invitations.page.notRedeemable'.tr(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlBanner(
          key: keys.invitation.alreadyMember,
          tone: PdlBannerTone.info,
          message: 'invitations.page.alreadyMember'.tr(
            namedArgs: <String, String>{'team': invitation.teamName},
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlButton(
          label: 'invitations.page.goToTeam'.tr(),
          fullWidth: true,
          onPressed: () => openWithHierarchy(
            ref.read(routerProvider),
            Paths.team(invitation.teamSlug),
          ),
        ),
      ],
    );
  }
}
