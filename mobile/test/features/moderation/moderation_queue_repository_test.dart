import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/moderation/data/moderation_repository.dart';

/// La file de modération d'une équipe (ledger `MOB-168`) : ce que le dépôt
/// demande au client généré, et le corps exact d'une décision.
class _Client implements ModerationClient {
  final List<({String teamSlug, ReportQueueStatus? status})> lists =
      <({String teamSlug, ReportQueueStatus? status})>[];
  final List<({String teamSlug, ModerationDecisionRequest body})> decisions =
      <({String teamSlug, ModerationDecisionRequest body})>[];

  @override
  Future<ModerationQueueResponse> listTeamReports({
    required String teamSlug,
    ReportQueueStatus? status,
  }) async {
    lists.add((teamSlug: teamSlug, status: status));
    return const ModerationQueueResponse(
      items: <ModerationItemDto>[
        ModerationItemDto(
          targetType: 'POST',
          targetId: 't1',
          teamSlug: 'n-peloton',
          teamName: 'N-Peloton',
          targetUser: PublicUserDto(id: 'u1', displayName: 'Léa'),
          reportCount: 2,
          reasons: <ReportReason>[ReportReason.spam],
          messages: <String>[],
          firstReportedAt: '2026-11-10T08:00:00Z',
          lastReportedAt: '2026-11-14T18:30:00Z',
          hidden: false,
          status: 'OPEN',
        ),
      ],
      total: 1,
    );
  }

  @override
  Future<void> resolveTeamReports({
    required String teamSlug,
    required ModerationDecisionRequest body,
  }) async {
    decisions.add((teamSlug: teamSlug, body: body));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Client client;
  late ModerationRepository repository;
  setUp(() {
    client = _Client();
    repository = ModerationRepository(client);
  });

  test('la file se lit par onglet, et rend ses cibles', () async {
    final List<ModerationItemDto> open = await repository.listTeamReports(
      'n-peloton',
      status: ReportQueueStatus.open,
    );
    await repository.listTeamReports(
      'n-peloton',
      status: ReportQueueStatus.resolved,
    );

    expect(open.single.targetId, 't1');
    expect(client.lists, <({String teamSlug, ReportQueueStatus? status})>[
      (teamSlug: 'n-peloton', status: ReportQueueStatus.open),
      (teamSlug: 'n-peloton', status: ReportQueueStatus.resolved),
    ]);
  });

  test(
    '« Supprimer le contenu » : le corps exact, l\'équipe comprise',
    () async {
      await repository.resolveTeamReports(
        'n-peloton',
        targetType: 'POST',
        targetId: 't1',
        action: ModerationAction.removeContent,
      );

      expect(client.decisions.single.teamSlug, 'n-peloton');
      expect(client.decisions.single.body.toJson(), <String, Object?>{
        'targetType': 'POST',
        'targetId': 't1',
        'action': 'REMOVE_CONTENT',
        'teamSlug': 'n-peloton',
      });
    },
  );

  test('« Rejeter le signalement » : le corps exact — le type part tel que '
      'la file l\'a donné', () async {
    await repository.resolveTeamReports(
      'n-peloton',
      targetType: 'MEMBER',
      targetId: 'u42',
      action: ModerationAction.dismiss,
    );

    expect(client.decisions.single.body.toJson(), <String, Object?>{
      'targetType': 'MEMBER',
      'targetId': 'u42',
      'action': 'DISMISS',
      'teamSlug': 'n-peloton',
    });
  });
}
