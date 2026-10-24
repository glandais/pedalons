import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';

import 'ride_fixtures.dart';

const RideKey _key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

/// Expose le `WidgetRef` d'un `ConsumerWidget` pour appeler les fonctions de
/// sélection comme le fait l'écran.
class _Probe extends ConsumerWidget {
  const _Probe(this.onBuild);

  final void Function(WidgetRef ref) onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuild(ref);
    return const SizedBox.shrink();
  }
}

/// La sélection de l'écran d'une sortie : un parcours, pas un groupe.
void main() {
  late RideDto ride;
  late WidgetRef ref;

  setUp(() {
    ride = fixtureRide(
      groups: <RideGroupDto>[
        fixtureGroup(id: 'g1', routeSlug: 'court'),
        fixtureGroup(id: 'g2', routeSlug: 'court'),
        fixtureGroup(id: 'g3', routeSlug: 'long'),
      ],
    ).copyWith(routeSlug: 'principal');
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(child: _Probe((WidgetRef r) => ref = r)),
    );
  }

  testWidgets('toucher le parcours principal, que personne ne roule, '
      'le sélectionne seul, puis un groupe l\'efface', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    selectRideRoute(ref, _key, ride, 'principal');
    expect(ref.read(selectedRideRouteOverrideProvider(_key)), 'principal');
    expect(resolvedRideRouteSlug(ref, _key, ride), 'principal');

    selectRideGroup(ref, _key, 'g3');
    expect(ref.read(selectedRideRouteOverrideProvider(_key)), isNull);
    expect(resolvedRideRouteSlug(ref, _key, ride), 'long');
  });

  testWidgets('toucher un parcours roulé sélectionne un groupe qui le roule, '
      'en gardant le groupe courant s\'il en fait partie', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    selectRideGroup(ref, _key, 'g2');
    selectRideRoute(ref, _key, ride, 'court');
    expect(ref.read(selectedRideGroupProvider(_key)), 'g2');
    expect(ref.read(selectedRideRouteOverrideProvider(_key)), isNull);

    selectRideRoute(ref, _key, ride, 'long');
    expect(ref.read(selectedRideGroupProvider(_key)), 'g3');
    expect(resolvedRideRouteSlug(ref, _key, ride), 'long');
  });

  testWidgets('les parcours décochés se règlent par sortie', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(ref.read(hiddenRideRoutesProvider(_key)), isEmpty);
    ref.read(hiddenRideRoutesProvider(_key).notifier).state = <String>{'court'};
    expect(ref.read(hiddenRideRoutesProvider(_key)), <String>{'court'});
    expect(
      ref.read(
        hiddenRideRoutesProvider(
          const RideKey(teamSlug: 'n-peloton', rideSlug: 'autre'),
        ),
      ),
      isEmpty,
    );
  });
}
