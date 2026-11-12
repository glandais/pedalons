import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/providers/route_list_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import '../teams/team_fixtures.dart';

/// Règle RL1 des listes (KIT §10) : une liste inter-équipes — le fil
/// d'accueil, Explorer — part sur « Membre », comme `useMembershipDefault`
/// côté web, sauf pour qui n'a aucune équipe.
void main() {
  test('sans réponse encore, la portée de départ est « Membre »', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        myTeamsProvider.overrideWith(
          (ref) => Completer<List<TeamDetailDto>>().future,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(membershipDefaultScopeProvider), MinRole.member);
  });

  test('sans aucune équipe, la portée de départ est « toutes »', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
      ],
    );
    addTearDown(container.dispose);
    final ProviderSubscription<MinRole?> sub = container.listen(
      membershipDefaultScopeProvider,
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(myTeamsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read(), isNull);
  });

  group('Explorer › Parcours', () {
    test('s\'ouvre sur « Membre » pour qui a une équipe', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          myTeamsProvider.overrideWith(
            (ref) async => <TeamDetailDto>[fixtureTeam()],
          ),
        ],
      );
      addTearDown(container.dispose);
      final ProviderSubscription<RouteFilters> sub = container.listen(
        routeFiltersProvider(null),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(myTeamsProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(sub.read().minRole, MinRole.member);
      expect(sub.read().teamSlug, isNull);
    });

    test('s\'ouvre sur toutes les équipes pour qui n\'en a aucune', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
        ],
      );
      addTearDown(container.dispose);
      final ProviderSubscription<RouteFilters> sub = container.listen(
        routeFiltersProvider(null),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(myTeamsProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(sub.read().minRole, isNull);
    });

    test('la section Parcours d\'une équipe n\'a pas de rôle à choisir', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          myTeamsProvider.overrideWith(
            (ref) async => <TeamDetailDto>[fixtureTeam()],
          ),
        ],
      );
      addTearDown(container.dispose);

      final RouteFilters filters = container.read(routeFiltersProvider('vcm'));
      expect(filters.teamSlug, 'vcm');
      expect(filters.minRole, isNull);
    });
  });
}
