import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/home/presentation/widgets/next_ride_card.dart';
import 'package:pedalons/features/home/providers/next_ride_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';

/// Règles R5, R6 et R7 des cartes (KIT §9, docs/LEDGER_*.md MOB-139) sur
/// « Ma prochaine sortie » : la grappe et « 11/12 personnes » avec la barre de
/// places, la personne qui lit en primaire, « Se désinscrire » en lien rouge
/// et « GPS » jusqu'à la fin de la sortie, jamais sur une sortie annulée.

class _NoAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Me extends AuthNotifier {
  _Me(Ref ref) : super(_NoAuth(), _NoStorage(), ref) {
    state = const AuthState(
      isInitialized: true,
      accessToken: 'token',
      user: UserDto(
        plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
        id: 'u1',
        email: 'moi@example.org',
        displayName: 'Membre 1',
        contactableByMembers: true,
        emailVerified: true,
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, RideDto ride, RideGroupDto g) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unitSystemProvider.overrideWithValue(UnitSystem.metric),
        authProvider.overrideWith((Ref ref) => _Me(ref)),
      ],
      child: MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NextRideCard(
              next: NextRide(ride: ride, group: g),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Une sortie partie depuis [startedAgo], qui dure trois heures.
RideDto _ride({
  Duration startedAgo = const Duration(days: -2),
  String status = 'PUBLISHED',
  RideGroupDto? group,
}) {
  final RideGroupDto g = group ?? _group();
  return fixtureRide(
    status: status,
    dateTime: DateTime.now().toUtc().subtract(startedAgo).toIso8601String(),
    registered: true,
    registeredGroupId: g.id,
    groups: <RideGroupDto>[g],
  ).copyWith(routeSlug: 'court');
}

RideGroupDto _group({int count = 11, int? max = 12, bool full = false}) =>
    fixtureGroup(
      registered: true,
      countParticipants: count,
      maxParticipants: max,
      full: full,
    );

void main() {
  setUpAll(loadTestTranslations);

  group('personnes (R5)', () {
    testWidgets('« 11/12 personnes » à côté de la grappe, la barre dessous en '
        'primaire ; plus de compte dans les chiffres', (
      WidgetTester tester,
    ) async {
      final RideGroupDto g = _group();
      await _pump(tester, _ride(group: g), g);
      expect(
        tester.widget<Text>(find.byKey(keys.home.nextRideCount)).data,
        '11/12 personnes',
      );
      expect(find.text('11/12'), findsNothing);
      final PdlProgressBar bar = tester.widget(
        find.byKey(keys.home.nextRideSeatsBar),
      );
      expect(bar.color, PdlColors.light.primary);
      expect(
        tester.getTopLeft(find.byKey(keys.home.nextRideSeatsBar)).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(keys.home.nextRideAvatars)).dy,
        ),
      );
    });

    testWidgets('groupe plein : barre rouge', (WidgetTester tester) async {
      final RideGroupDto g = _group(count: 12, full: true);
      await _pump(tester, _ride(group: g), g);
      final PdlProgressBar bar = tester.widget(
        find.byKey(keys.home.nextRideSeatsBar),
      );
      expect(bar.color, PdlColors.light.danger);
    });

    testWidgets('sans maximum : « 11 personnes », sans barre', (
      WidgetTester tester,
    ) async {
      final RideGroupDto g = _group(max: null);
      await _pump(tester, _ride(group: g), g);
      expect(
        tester.widget<Text>(find.byKey(keys.home.nextRideCount)).data,
        '11 personnes',
      );
      expect(find.byKey(keys.home.nextRideSeatsBar), findsNothing);
    });

    testWidgets('la personne qui lit est en primaire dans la grappe', (
      WidgetTester tester,
    ) async {
      final RideGroupDto g = _group();
      await _pump(tester, _ride(group: g), g);
      final PdlAvatarStack stack = tester.widget(
        find.byKey(keys.home.nextRideAvatars),
      );
      expect(
        stack.people
            .where((PdlAvatarEntry p) => p.isCurrentUser)
            .map((PdlAvatarEntry p) => p.name),
        <String>['Membre 1'],
      );
    });
  });

  group('se désinscrire (R6) et GPS (R7)', () {
    testWidgets('avant le départ : « Voir la sortie » en pleine largeur, '
        '« GPS », et « Se désinscrire » en lien rouge au pied', (
      WidgetTester tester,
    ) async {
      final RideGroupDto g = _group();
      await _pump(tester, _ride(group: g), g);
      final Finder leave = find.byKey(keys.home.nextRideLeaveButton);
      expect(leave, findsOneWidget);
      expect(find.byType(PdlButton).evaluate().length, greaterThan(0));
      final Text label = tester.widget<Text>(
        find.descendant(of: leave, matching: find.byType(Text)),
      );
      expect(label.data, 'Se désinscrire');
      expect(label.style!.color, PdlColors.light.danger);
      final Finder gps = find.byKey(keys.home.nextRideGps);
      expect(gps, findsOneWidget);
      expect(
        tester.getTopLeft(leave).dy,
        greaterThan(tester.getBottomLeft(gps).dy),
      );
    });

    testWidgets('sortie en cours : « Se désinscrire » et « GPS » restent', (
      WidgetTester tester,
    ) async {
      final RideGroupDto g = _group();
      await _pump(tester, _ride(startedAgo: const Duration(hours: 1)), g);
      expect(find.byKey(keys.home.nextRideLeaveButton), findsOneWidget);
      expect(find.byKey(keys.home.nextRideGps), findsOneWidget);
    });

    testWidgets('sortie terminée : ni l’un ni l’autre', (
      WidgetTester tester,
    ) async {
      final RideGroupDto g = _group();
      await _pump(tester, _ride(startedAgo: const Duration(hours: 4)), g);
      expect(find.byKey(keys.home.nextRideLeaveButton), findsNothing);
      expect(find.byKey(keys.home.nextRideGps), findsNothing);
    });

    testWidgets('sortie annulée : ni l’un ni l’autre', (
      WidgetTester tester,
    ) async {
      final RideGroupDto g = _group();
      await _pump(tester, _ride(status: 'CANCELLED'), g);
      expect(find.byKey(keys.home.nextRideLeaveButton), findsNothing);
      expect(find.byKey(keys.home.nextRideGps), findsNothing);
    });
  });
}
