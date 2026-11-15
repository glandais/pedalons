import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final teamInvitationsRepositoryProvider = Provider<TeamInvitationsRepository>((
  ref,
) {
  return TeamInvitationsRepository(ref.watch(teamInvitationsClientProvider));
});

/// Borne de `CreateInvitationRequest.email` au contrat.
const int kInvitationEmailMaxLength = 250;

/// Les invitations qu'une équipe **envoie** (`/api/teams/{teamSlug}/invitations`,
/// administration de l'équipe seulement — docs/LEDGER_*.md MOB-167). Celles
/// qu'une personne reçoit sont dans `InvitationsRepository`.
///
/// Personne ne devient membre sans accepter. Le serveur répond la même chose
/// que l'adresse ait un compte ou non — répondre autrement ferait de
/// l'invitation une sonde d'existence de compte : une adresse mal saisie
/// produit donc une invitation ordinaire, que seule la liste des invitations
/// en attente rend visible.
class TeamInvitationsRepository {
  TeamInvitationsRepository(this._client);

  final TeamInvitationsClient _client;

  /// Les invitations en attente de [teamSlug] : la première page seulement,
  /// comme le site.
  Future<List<TeamInvitationDto>> listPending(String teamSlug) async {
    final TeamInvitationListResponse response = await _client.listInvitations(
      teamSlug: teamSlug,
      status: InvitationStatus.pending,
    );
    return response.invitations;
  }

  /// Invite [email] avec le rôle [role]. Réinviter la même adresse n'est pas
  /// une erreur : le serveur révoque l'invitation en attente et en émet une
  /// neuve — c'est ainsi que « Renvoyer » fonctionne.
  ///
  /// `TEAM_INVITE_SELF`, `TEAM_INVITE_ALREADY_MEMBER`,
  /// `TEAM_MEMBER_LIMIT_REACHED`, `TEAM_INVITE_RATE_LIMITED`,
  /// `TEAM_INVITE_DELIVERY_FAILED`.
  Future<TeamInvitationDto> invite(
    String teamSlug, {
    required String email,
    required String role,
  }) {
    return _client.invite(
      teamSlug: teamSlug,
      body: CreateInvitationRequest(email: email, role: role),
    );
  }

  /// Annule une invitation en attente. 409 (`TEAM_INVITE_NOT_PENDING`) si
  /// elle a déjà été acceptée, annulée ou a expiré.
  Future<void> revoke(String teamSlug, String invitationId) {
    return _client.revoke(teamSlug: teamSlug, invitationId: invitationId);
  }
}
