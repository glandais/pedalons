import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/data/team_invitations_repository.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';

import 'team_fixtures.dart';

/// Ce que les dépôts de la gestion des membres envoient (ledger `MOB-167`) :
/// le paramètre de chemin `memberId` porte l'identifiant de la **personne**,
/// et la liste des invitations ne demande que celles en attente.
class _MembersClient implements TeamMembersClient {
  final List<({String teamSlug, String memberId, String? role})> calls =
      <({String teamSlug, String memberId, String? role})>[];

  @override
  Future<MemberDto> updateMemberRole({
    required String memberId,
    required String teamSlug,
    required UpdateMemberRoleRequest body,
  }) async {
    calls.add((teamSlug: teamSlug, memberId: memberId, role: body.role));
    return fixtureMember(index: 7, role: body.role);
  }

  @override
  Future<void> removeMember({
    required String memberId,
    required String teamSlug,
  }) async {
    calls.add((teamSlug: teamSlug, memberId: memberId, role: null));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoTeamsClient implements TeamsClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InvitationsClient implements TeamInvitationsClient {
  InvitationStatus? status;
  int? page;
  CreateInvitationRequest? invited;
  ({String teamSlug, String invitationId})? revoked;

  @override
  Future<TeamInvitationListResponse> listInvitations({
    required String teamSlug,
    InvitationStatus? status,
    int? page = 0,
    int? size = 20,
  }) async {
    this.status = status;
    this.page = page;
    return const TeamInvitationListResponse(
      invitations: <TeamInvitationDto>[],
      total: 0,
      page: 0,
      size: 20,
    );
  }

  @override
  Future<TeamInvitationDto> invite({
    required String teamSlug,
    required CreateInvitationRequest body,
  }) async {
    invited = body;
    return TeamInvitationDto(
      id: 'inv1',
      email: body.email,
      role: body.role ?? 'MEMBER',
      status: 'PENDING',
      expiresAt: '2026-11-29T10:00:00Z',
      createdAt: '2026-11-15T10:00:00Z',
      invitedBy: const PublicUserDto(id: 'u1', displayName: 'Moi'),
    );
  }

  @override
  Future<void> revoke({
    required String invitationId,
    required String teamSlug,
  }) async {
    revoked = (teamSlug: teamSlug, invitationId: invitationId);
  }
}

void main() {
  test(
    'changer un rôle : `memberId` est l\'identifiant de la personne',
    () async {
      final _MembersClient client = _MembersClient();
      final TeamRepository repository = TeamRepository(
        _NoTeamsClient(),
        client,
      );

      await repository.updateMemberRole(
        'n-peloton',
        userId: 'u7',
        role: TeamRole.organizer,
      );

      expect(client.calls.single, (
        teamSlug: 'n-peloton',
        memberId: 'u7',
        role: 'ORGANIZER',
      ));
    },
  );

  test(
    'retirer un membre : `memberId` est l\'identifiant de la personne',
    () async {
      final _MembersClient client = _MembersClient();
      final TeamRepository repository = TeamRepository(
        _NoTeamsClient(),
        client,
      );

      await repository.removeMember('n-peloton', userId: 'u7');

      expect(client.calls.single, (
        teamSlug: 'n-peloton',
        memberId: 'u7',
        role: null,
      ));
    },
  );

  test('les invitations lues sont celles en attente, première page', () async {
    final _InvitationsClient client = _InvitationsClient();

    await TeamInvitationsRepository(client).listPending('n-peloton');

    expect(client.status, InvitationStatus.pending);
    expect(client.page, 0);
  });

  test('inviter envoie l\'adresse et le rôle ; annuler, l\'identifiant de '
      'l\'invitation', () async {
    final _InvitationsClient client = _InvitationsClient();
    final TeamInvitationsRepository repository = TeamInvitationsRepository(
      client,
    );

    await repository.invite(
      'n-peloton',
      email: 'lea@example.org',
      role: 'ORGANIZER',
    );
    await repository.revoke('n-peloton', 'inv1');

    expect(
      client.invited,
      const CreateInvitationRequest(
        email: 'lea@example.org',
        role: 'ORGANIZER',
      ),
    );
    expect(client.revoked, (teamSlug: 'n-peloton', invitationId: 'inv1'));
  });
}
