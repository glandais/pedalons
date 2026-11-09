import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

/// Le fil d'accueil part sur « Membre », comme `useMembershipDefault` côté
/// web, sauf pour qui n'a aucune équipe.
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

    expect(container.read(homeFeedDefaultScopeProvider), MinRole.member);
  });

  test('sans aucune équipe, la portée de départ est « toutes »', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
      ],
    );
    addTearDown(container.dispose);
    final ProviderSubscription<MinRole?> sub = container.listen(
      homeFeedDefaultScopeProvider,
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(myTeamsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read(), isNull);
  });
}
