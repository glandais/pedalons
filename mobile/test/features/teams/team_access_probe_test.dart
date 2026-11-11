import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_access_probe.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import 'team_fixtures.dart';

/// La question qu'un lien profond pose avant de reconstruire une équipe sous
/// une de ses entités (docs/LEDGER_*.md MOB-137) : `GET team` répondrait-il ?
class _Teams implements TeamRepository {
  _Teams({this.mine = const <TeamDetailDto>[], this.getTeamError});

  final List<TeamDetailDto> mine;
  final Object? getTeamError;
  int getTeamCalls = 0;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => mine;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    getTeamCalls++;
    if (getTeamError != null) throw getTeamError!;
    return fixtureTeam(slug: slug);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// « Mes équipes » répond une fois, puis ne répond plus : un rechargement qui
/// reste en vol.
class _ReloadingTeams extends _Teams {
  _ReloadingTeams(List<TeamDetailDto> first) : super(mine: first);

  int _myTeamsCalls = 0;

  @override
  Future<List<TeamDetailDto>> getMyTeams() {
    if (_myTeamsCalls++ == 0) return Future<List<TeamDetailDto>>.value(mine);
    return Completer<List<TeamDetailDto>>().future;
  }
}

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/x'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/api/teams/x'),
    statusCode: code,
  ),
);

void main() {
  Future<(bool, _Teams)> ask(_Teams teams, String slug) async {
    final ProviderContainer container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [teamRepositoryProvider.overrideWithValue(teams)],
    );
    addTearDown(container.dispose);
    await container.read(myTeamsProvider.future);
    return (await container.read(teamAccessProbeProvider)(slug), teams);
  }

  test('membre d\'après « Mes équipes » : oui, sans appel', () async {
    final (bool ok, _Teams teams) = await ask(
      _Teams(mine: <TeamDetailDto>[fixtureTeam(slug: 'club')]),
      'club',
    );
    expect(ok, isTrue);
    expect(teams.getTeamCalls, 0);
  });

  test(
    '« Mes équipes » en rechargement : sa valeur d\'avant ne compte pas',
    () async {
      // Un changement de compte recharge la liste ; Riverpod garde celle de la
      // session précédente pendant ce temps. Elle ne vaut pas réponse.
      final _ReloadingTeams teams = _ReloadingTeams(<TeamDetailDto>[
        fixtureTeam(slug: 'club'),
      ]);
      final ProviderContainer container = ProviderContainer(
        retry: (int _, Object _) => null,
        overrides: [teamRepositoryProvider.overrideWithValue(teams)],
      );
      addTearDown(container.dispose);
      container.listen(myTeamsProvider, (_, _) {});
      await container.read(myTeamsProvider.future);
      container.invalidate(myTeamsProvider);
      expect(container.read(myTeamsProvider).isLoading, isTrue);

      expect(await container.read(teamAccessProbeProvider)('club'), isTrue);
      expect(teams.getTeamCalls, 1);
    },
  );

  test('une équipe qui répond : oui', () async {
    final (bool ok, _) = await ask(_Teams(), 'club');
    expect(ok, isTrue);
  });

  test('404 ou 403 : non', () async {
    expect((await ask(_Teams(getTeamError: _status(404)), 'club')).$1, isFalse);
    expect((await ask(_Teams(getTeamError: _status(403)), 'club')).$1, isFalse);
  });

  test('tout autre échec : oui, la pile complète', () async {
    expect((await ask(_Teams(getTeamError: _status(500)), 'club')).$1, isTrue);
    expect(
      (await ask(
        _Teams(
          getTeamError: DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
        'club',
      )).$1,
      isTrue,
    );
  });
}
