import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart' hide Visibility;
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/visibility/domain/content_visibility.dart';
import 'package:pedalons/features/visibility/domain/incompatible_visibility.dart';
import 'package:pedalons/features/visibility/presentation/visibility_field.dart';
import 'package:pedalons/keys.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// Le champ « Visibilité » partagé des éditeurs (docs/LEDGER_*.md MOB-137) :
/// il montre ce que le backend permet, et rien d'autre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  const List<Visibility> all = <Visibility>[
    Visibility.team,
    Visibility.publicUnlisted,
    Visibility.public,
  ];

  Future<List<Visibility>> pump(
    WidgetTester tester, {
    required List<Visibility> allowed,
    required Visibility value,
    bool teamPrivate = false,
  }) async {
    final List<Visibility> picked = <Visibility>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisibilityField(
              title: 'Visibilité',
              allowed: allowed,
              value: value,
              onChanged: picked.add,
              teamPrivate: teamPrivate,
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  group('VisibilityField', () {
    testWidgets('une seule valeur, celle du contenu : pas de champ', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        allowed: <Visibility>[Visibility.team],
        value: Visibility.team,
      );

      expect(find.text('Visibilité'), findsNothing);
      expect(find.byKey(keys.visibility.option('TEAM')), findsNothing);
    });

    testWidgets('les valeurs permises, dans l\'ordre de l\'enum', (
      WidgetTester tester,
    ) async {
      final List<Visibility> picked = await pump(
        tester,
        allowed: all,
        value: Visibility.team,
      );

      expect(find.text('Équipe uniquement'), findsOneWidget);
      expect(find.text('Non répertorié'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.byKey(keys.visibility.privateTeamHint), findsNothing);
      expect(find.byKey(keys.visibility.notAllowed), findsNothing);

      await tester.tap(find.byKey(keys.visibility.option('PUBLIC')));
      expect(picked, <Visibility>[Visibility.public]);
    });

    testWidgets('équipe privée : l\'aide dit « par lien, hors des listes »', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        allowed: all,
        value: Visibility.team,
        teamPrivate: true,
      );

      expect(find.byKey(keys.visibility.privateTeamHint), findsOneWidget);
      expect(
        find.textContaining('lisible par toute personne qui a le lien'),
        findsOneWidget,
      );
    });

    testWidgets('une valeur qui n\'est plus permise se montre comme telle', (
      WidgetTester tester,
    ) async {
      // L'équipe a perdu le droit de publier hors de l'équipe ; la sortie
      // est restée « Public ».
      final List<Visibility> picked = await pump(
        tester,
        allowed: <Visibility>[Visibility.team],
        value: Visibility.public,
        teamPrivate: true,
      );

      expect(find.byKey(keys.visibility.option('TEAM')), findsOneWidget);
      expect(find.byKey(keys.visibility.option('PUBLIC')), findsOneWidget);
      expect(
        find.byKey(keys.visibility.option('PUBLIC_UNLISTED')),
        findsNothing,
      );
      expect(find.byKey(keys.visibility.notAllowed), findsOneWidget);
      // Rien hors de l'équipe n'est proposé : pas d'aide sur le lien.
      expect(find.byKey(keys.visibility.privateTeamHint), findsNothing);

      // Elle ne se choisit pas ; seule son abandon compte.
      await tester.tap(find.byKey(keys.visibility.option('PUBLIC')));
      await tester.tap(find.byKey(keys.visibility.option('TEAM')));
      expect(picked, <Visibility>[Visibility.team]);
    });

    testWidgets('aucune valeur : une explication, pas un sélecteur vide', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        allowed: const <Visibility>[],
        value: Visibility.publicUnlisted,
      );

      expect(find.byKey(keys.visibility.noneAllowed), findsOneWidget);
      expect(find.byKey(keys.visibility.option('TEAM')), findsNothing);
      expect(
        find.textContaining('Aucune visibilité ne peut être enregistrée'),
        findsOneWidget,
      );
    });
  });

  group('allowedVisibilitiesFor', () {
    test('la création lit la liste de l\'équipe pour le type', () {
      final TeamDetailDto team = fixtureTeam(visibility: 'TEAM');
      expect(allowedVisibilitiesFor(team, VisibilityKind.ride), <Visibility>[
        Visibility.team,
      ]);
      expect(allowedVisibilitiesFor(fixtureTeam(), VisibilityKind.route), all);
    });

    test('la modification lit celle de l\'entité, même vide', () {
      final TeamDetailDto team = fixtureTeam();
      expect(
        allowedVisibilitiesFor(
          team,
          VisibilityKind.route,
          permissions: kNoPermissions.copyWith(
            allowedVisibilities: <Visibility>[
              Visibility.public,
              Visibility.publicUnlisted,
            ],
          ),
        ),
        // L'ordre de l'enum, quel que soit celui reçu.
        <Visibility>[Visibility.publicUnlisted, Visibility.public],
      );
      expect(
        allowedVisibilitiesFor(
          team,
          VisibilityKind.route,
          permissions: kNoPermissions.copyWith(
            allowedVisibilities: const <Visibility>[],
          ),
        ),
        isEmpty,
      );
    });

    test(
      'un bloc sans liste (liste, résumé) retombe sur celle de l\'équipe',
      () {
        expect(
          allowedVisibilitiesFor(
            fixtureTeam(visibility: 'TEAM'),
            VisibilityKind.ride,
            permissions: kNoPermissions,
          ),
          <Visibility>[Visibility.team],
        );
      },
    );
  });

  group('defaultContentVisibilityOf', () {
    test('la valeur du backend, jamais la visibilité de l\'équipe', () {
      // Une équipe publique qui démarre ses formulaires en « Équipe » : le
      // champ calculé gagne.
      expect(
        defaultContentVisibilityOf(
          fixtureTeam().copyWith(defaultContentVisibility: 'TEAM'),
        ),
        Visibility.team,
      );
      expect(
        defaultContentVisibilityOf(
          fixtureTeam().copyWith(defaultContentVisibility: 'PUBLIC_UNLISTED'),
        ),
        Visibility.publicUnlisted,
      );
    });

    test('une valeur inconnue retombe sur « Équipe »', () {
      expect(
        defaultContentVisibilityOf(
          fixtureTeam().copyWith(defaultContentVisibility: 'SOMEDAY'),
        ),
        Visibility.team,
      );
    });
  });

  group('incompatibleVisibilityOf', () {
    DioException failure(Object? data) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 400,
        data: data,
      ),
    );

    test('lit les parcours et les usages', () {
      final IncompatibleVisibility? refusal = incompatibleVisibilityOf(
        failure(<String, dynamic>{
          'code': 'INCOMPATIBLE_VISIBILITY',
          'errorDetails': <String, dynamic>{
            'type': 'INCOMPATIBLE_VISIBILITY',
            'routes': <Map<String, dynamic>>[],
            'usages': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'TRIP',
                'slug': 'grand-tour',
                'name': 'Grand tour',
                'visibility': 'PUBLIC_UNLISTED',
              },
            ],
          },
        }),
      );

      expect(refusal, isNotNull);
      expect(refusal!.routes, isEmpty);
      expect(refusal.usages.single.slug, 'grand-tour');
    });

    test('sans détail lisible, le refus reste reconnu', () {
      final IncompatibleVisibility? refusal = incompatibleVisibilityOf(
        failure(<String, dynamic>{'code': 'INCOMPATIBLE_VISIBILITY'}),
      );

      expect(refusal, isNotNull);
      expect(refusal!.routes, isEmpty);
      expect(refusal.usages, isEmpty);
    });

    test('nul pour tout autre échec', () {
      expect(
        incompatibleVisibilityOf(
          failure(<String, dynamic>{'code': 'INVALID_VISIBILITY'}),
        ),
        isNull,
      );
      expect(incompatibleVisibilityOf(StateError('x')), isNull);
    });
  });
}
