import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/features/teams/data/team_invitations_repository.dart';
import 'package:pedalons/features/teams/providers/team_dashboard_provider.dart';
import 'package:pedalons/features/teams/providers/team_first_steps_provider.dart';

import 'team_fixtures.dart';

/// Ce que lisent les « Premières étapes » (docs/LEDGER_*.md WEB-195) : rien
/// pour qui n'administre pas, rien de plus que le tableau de bord quand il
/// répond déjà, et une étape absente quand elle ne s'applique pas.
class _FakeInvitations implements TeamInvitationsRepository {
  _FakeInvitations(this.pending);

  final List<TeamInvitationDto> pending;
  int calls = 0;

  @override
  Future<List<TeamInvitationDto>> listPending(String teamSlug) async {
    calls++;
    return pending;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePublications implements PublicationsClient {
  _FakePublications(this.rides);

  final int rides;
  int calls = 0;

  @override
  Future<CountResponse> countPublications({
    required String teamSlug,
    String? from,
    String? search,
    Status? status,
    List<String>? tags,
    String? to,
    PublicationType? type,
    PublicationWhen? whenField,
    bool? dated = false,
    bool? participating = false,
    bool? withFullGroup = false,
    bool? withoutRoute = false,
  }) async {
    calls++;
    expect(type, PublicationType.ride);
    return CountResponse(total: rides);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const TeamDashboardAdminDto _admin = TeamDashboardAdminDto(
  newestMembers: MemberListResponse(
    members: <MemberDto>[],
    total: 1,
    page: 0,
    size: 3,
  ),
  webhook: TeamWebhookDto(configured: false, enabled: false),
);

TeamDashboardDto _dashboard(TeamDetailDto team, {bool admin = true}) =>
    TeamDashboardDto(team: team, admin: admin ? _admin : null);

Future<(FirstStepsState?, _FakeInvitations, _FakePublications)> _read(
  TeamDashboardDto dashboard, {
  List<TeamInvitationDto> pending = const <TeamInvitationDto>[],
  int rides = 0,
}) async {
  final _FakeInvitations invitations = _FakeInvitations(pending);
  final _FakePublications publications = _FakePublications(rides);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      teamDashboardProvider.overrideWith(
        (Ref ref, String slug) async => dashboard,
      ),
      teamInvitationsRepositoryProvider.overrideWithValue(invitations),
      publicationsClientProvider.overrideWithValue(publications),
    ],
  );
  addTearDown(container.dispose);
  final FirstStepsState? state = await container.read(
    teamFirstStepsProvider('n-peloton').future,
  );
  return (state, invitations, publications);
}

TeamDetailDto _team({
  int memberCount = 1,
  int upcomingRideCount = 0,
  int routeCount = 0,
  bool addMemberAllowed = true,
  bool enableRides = true,
  bool enableRoutes = true,
}) =>
    fixtureTeam(
      memberCount: memberCount,
      upcomingRideCount: upcomingRideCount,
    ).copyWith(
      routeCount: routeCount,
      addMemberAllowed: addMemberAllowed,
      enableRides: enableRides,
      enableRoutes: enableRoutes,
    );

void main() {
  test('pour qui n\'administre pas : rien, et aucun appel', () async {
    final (FirstStepsState? state, _FakeInvitations i, _FakePublications p) =
        await _read(_dashboard(_team(), admin: false));

    expect(state, isNull);
    expect(i.calls + p.calls, 0);
  });

  test(
    'une équipe neuve : rien n\'est fait, les deux appels partent',
    () async {
      final (FirstStepsState? state, _FakeInvitations i, _FakePublications p) =
          await _read(_dashboard(_team()));

      expect(state!.invite, isFalse);
      expect(state.ride, isFalse);
      expect(state.route, isFalse);
      expect(i.calls, 1);
      expect(p.calls, 1);
    },
  );

  test(
    'une invitation envoyée, une sortie passée, un parcours : tout est fait',
    () async {
      final (FirstStepsState? state, _, _) = await _read(
        _dashboard(_team(routeCount: 1)),
        pending: <TeamInvitationDto>[
          const TeamInvitationDto(
            id: 'i1',
            email: 'lea@example.org',
            role: 'MEMBER',
            status: 'PENDING',
            createdAt: '2026-11-20T10:00:00Z',
            expiresAt: '2026-12-20T10:00:00Z',
            invitedBy: PublicUserDto(id: 'u1', displayName: 'Gaby'),
          ),
        ],
        rides: 1,
      );

      expect(state!.invite, isTrue);
      expect(state.ride, isTrue);
      expect(state.route, isTrue);
    },
  );

  test('ce que le tableau de bord dit déjà ne coûte aucun appel', () async {
    final (FirstStepsState? state, _FakeInvitations i, _FakePublications p) =
        await _read(_dashboard(_team(memberCount: 3, upcomingRideCount: 2)));

    expect(state!.invite, isTrue);
    expect(state.ride, isTrue);
    expect(i.calls + p.calls, 0);
  });

  test(
    'sans les modules ni l\'invitation par e-mail : étapes absentes',
    () async {
      final (
        FirstStepsState? state,
        _FakeInvitations i,
        _FakePublications p,
      ) = await _read(
        _dashboard(
          _team(
            addMemberAllowed: false,
            enableRides: true,
            enableRoutes: false,
          ),
        ),
      );

      expect(state!.invite, isNull);
      expect(state.ride, isNull, reason: 'une sortie se crée sur un parcours');
      expect(state.route, isNull);
      expect(i.calls + p.calls, 0);
    },
  );
}
