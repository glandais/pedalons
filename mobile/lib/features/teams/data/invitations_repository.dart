import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final invitationsRepositoryProvider = Provider<InvitationsRepository>((ref) {
  return InvitationsRepository(ref.watch(invitationsClientProvider));
});

/// Les invitations **reçues** par l'utilisateur connecté.
///
/// Celles qu'une équipe envoie (`TeamInvitationsClient`) sont l'affaire de qui
/// l'administre : `TeamInvitationsRepository`, écran « Membres »
/// (docs/LEDGER_*.md MOB-167).
class InvitationsRepository {
  InvitationsRepository(this._client);

  final InvitationsClient _client;

  /// Les invitations en attente adressées à l'utilisateur.
  Future<List<MyInvitationDto>> listMine() async {
    final MyInvitationListResponse response = await _client.listMyInvitations();
    return response.invitations;
  }

  /// Accepte une invitation : l'utilisateur devient membre de l'équipe.
  Future<void> accept(String invitationId) async {
    await _client.acceptMyInvitation(invitationId: invitationId);
  }

  /// L'aperçu public du lien d'un e-mail d'invitation : qui invite, à quelle
  /// équipe, pour quelle adresse (masquée). Répond sans session.
  Future<InvitationPreviewDto> preview(String token) =>
      _client.preview(body: AcceptInvitationRequest(token: token));

  /// Accepte l'invitation du lien [token], au nom de la personne connectée —
  /// qui doit être celle de l'adresse invitée (`TEAM_INVITE_EMAIL_MISMATCH`
  /// sinon). Rejouer le lien d'une invitation déjà acceptée par ce membre
  /// réussit.
  Future<void> acceptToken(String token) async {
    await _client.accept(body: AcceptInvitationRequest(token: token));
  }
}
