import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../data/team_invitations_repository.dart';
import '../../providers/team_invitations_provider.dart';

/// La forme `x@y.z`, celle du site (`TeamMembersPage.tsx`) : le serveur reste
/// l'autorité sur l'adresse (`@Email`), ceci n'épargne qu'un aller-retour sur
/// une saisie manifestement fausse.
final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// L'adresse a-t-elle la forme d'une adresse e-mail ?
bool looksLikeEmail(String value) => _emailShape.hasMatch(value.trim());

/// Les rôles proposés à l'invitation, « Membre » d'abord : le choix par
/// défaut.
const List<TeamRole> kInvitableTeamRoles = <TeamRole>[
  TeamRole.member,
  TeamRole.organizer,
  TeamRole.admin,
];

/// Ouvre la feuille « Inviter par e-mail » de [teamSlug] (docs/LEDGER_*.md
/// MOB-167). Rend l'adresse invitée, ou `null` si la feuille se ferme sans
/// envoi.
Future<String?> showTeamInviteSheet(BuildContext context, String teamSlug) {
  return PdlSheet.show<String>(
    context: context,
    builder: (BuildContext _) => TeamInviteSheet(teamSlug: teamSlug),
  );
}

/// Inviter une adresse e-mail dans l'équipe — le dialogue d'invitation de
/// `TeamMembersPage` du site.
///
/// **Personne n'est inscrit d'office** : la feuille le dit, et l'invitation
/// doit être acceptée. Ce que le serveur refuse (`TEAM_INVITE_SELF`,
/// `TEAM_INVITE_ALREADY_MEMBER`, `TEAM_MEMBER_LIMIT_REACHED`…) se lit dans un
/// bandeau, la feuille ouverte et la saisie gardée : une faute de frappe se
/// corrige, elle ne se retape pas.
class TeamInviteSheet extends ConsumerStatefulWidget {
  const TeamInviteSheet({super.key, required this.teamSlug});

  final String teamSlug;

  @override
  ConsumerState<TeamInviteSheet> createState() => _TeamInviteSheetState();
}

class _TeamInviteSheetState extends ConsumerState<TeamInviteSheet> {
  final TextEditingController _email = TextEditingController();

  TeamRole _role = TeamRole.member;
  bool _sending = false;

  /// Les erreurs de champ ne se montrent qu'après une tentative d'envoi.
  bool _attempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? get _emailError {
    if (!_attempted) return null;
    final String email = _email.text.trim();
    if (email.isEmpty) return 'teams.adminMembers.invite.emailRequired'.tr();
    if (!looksLikeEmail(email)) {
      return 'teams.adminMembers.invite.emailInvalid'.tr();
    }
    if (email.length > kInvitationEmailMaxLength) {
      return 'teams.adminMembers.invite.emailTooLong'.tr(
        namedArgs: <String, String>{'max': '$kInvitationEmailMaxLength'},
      );
    }
    return null;
  }

  Future<void> _submit() async {
    if (_sending) return;
    final String email = _email.text.trim();
    // La borne se lit sur l'adresse **rognée**, celle qui part : un espace
    // collé avec elle ne la raccourcit pas.
    if (!looksLikeEmail(email) || email.length > kInvitationEmailMaxLength) {
      setState(() => _attempted = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _attempted = true;
      _sending = true;
      _error = null;
    });
    final TeamInvitationsRepository repository = ref.read(
      teamInvitationsRepositoryProvider,
    );
    // Pris avant l'`await` : la feuille peut être fermée avant la réponse.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      await repository.invite(
        widget.teamSlug,
        email: email,
        role: _role.toJson(),
      );
      container.invalidate(teamInvitationsProvider(widget.teamSlug));
      if (mounted) Navigator.of(context).pop(email);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return PdlSheet(
      key: keys.teamAdminMembers.inviteSheet,
      title: 'teams.adminMembers.invite.open'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: PdlButton(
            key: keys.teamAdminMembers.inviteSubmit,
            label: 'teams.adminMembers.invite.send'.tr(),
            icon: PdlIcons.email,
            loading: _sending,
            loadingLabel: 'teams.adminMembers.invite.sending'.tr(),
            fullWidth: true,
            onPressed: _submit,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          PdlSpacing.section,
          PdlSpacing.chipGap,
          PdlSpacing.section,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_error != null) ...<Widget>[
              PdlBanner(
                key: keys.teamAdminMembers.inviteErrorBanner,
                tone: PdlBannerTone.danger,
                icon: PdlIcons.error,
                message: _error!,
                onDismiss: () => setState(() => _error = null),
                dismissSemanticLabel: 'common.close'.tr(),
              ),
              const SizedBox(height: PdlSpacing.section),
            ],
            PdlBanner(
              tone: PdlBannerTone.info,
              message: 'teams.adminMembers.invite.consentNotice'.tr(),
            ),
            const SizedBox(height: PdlSpacing.section),
            TextField(
              key: keys.teamAdminMembers.inviteEmailField,
              controller: _email,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const <String>[],
              onSubmitted: (String _) => _submit(),
              decoration: InputDecoration(
                labelText: 'teams.adminMembers.invite.email'.tr(),
                hintText: 'teams.adminMembers.invite.emailPlaceholder'.tr(),
                helperText: 'teams.adminMembers.invite.emailHelp'.tr(),
                helperMaxLines: 3,
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: PdlSpacing.section),
            Text('teams.adminMembers.invite.role'.tr(), style: t.bodyStrong),
            const SizedBox(height: PdlSpacing.chipGap),
            IgnorePointer(
              ignoring: _sending,
              child: Wrap(
                spacing: PdlSpacing.chipGap,
                runSpacing: PdlSpacing.chipGap,
                children: <Widget>[
                  for (final TeamRole role in kInvitableTeamRoles)
                    PdlChip(
                      key: keys.teamAdminMembers.inviteRole(role.json!),
                      label: AppFormatters.roleName(role.json!),
                      selected: _role == role,
                      onTap: () => setState(() => _role = role),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
