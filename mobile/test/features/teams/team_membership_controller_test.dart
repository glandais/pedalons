import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_membership_controller.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// Une équipe de l'offre gratuite pleine refuse l'adhésion
/// (`TEAM_MEMBER_LIMIT_REACHED`, docs/LEDGER_*.md BILL-10) : la bascule
/// optimiste a déjà compté la personne, le refus doit la décompter.
class _FullTeam implements TeamRepository {
  @override
  Future<TeamDetailDto> getTeam(String slug) async =>
      fixtureTeam(slug: slug, memberCount: 25).copyWith(memberLimit: 25);

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => const <TeamDetailDto>[];

  @override
  Future<MemberDto> joinTeam(String slug) async => throw DioException(
    requestOptions: RequestOptions(path: '/'),
    type: DioExceptionType.badResponse,
    response: Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: 409,
      data: <String, dynamic>{
        'code': 'TEAM_MEMBER_LIMIT_REACHED',
        'errorDetails': <String, dynamic>{
          'type': 'TEAM_MEMBER_LIMIT_REACHED',
          'limit': 25,
          'current': 25,
        },
      },
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(loadTestTranslations);

  test(
    'un refus pour limite rétablit le rôle et le nombre de membres',
    () async {
      final ProviderContainer container = ProviderContainer(
        retry: (int _, Object _) => null,
        overrides: [teamRepositoryProvider.overrideWithValue(_FullTeam())],
      );
      addTearDown(container.dispose);
      final provider = teamMembershipControllerProvider('n-peloton');
      container.listen(provider, (_, _) {});
      while (!container.read(provider).team.hasValue) {
        await Future<void>.delayed(Duration.zero);
      }

      final Future<void> joining = container.read(provider.notifier).join();
      // Optimiste : la personne est comptée avant la réponse.
      expect(container.read(provider).team.value!.memberCount, 26);
      await joining;

      final TeamMembershipState state = container.read(provider);
      expect(state.isMember, isFalse);
      expect(state.team.value!.memberCount, 25);
      expect(state.pending, isFalse);
      expect(state.failure, contains('a atteint 25 membres'));
    },
  );
}
