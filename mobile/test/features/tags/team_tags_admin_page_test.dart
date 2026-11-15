import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/tags/presentation/pages/team_tags_admin_page.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// « Tags » (ledger `MOB-169`) : qui y entre — et qu'aucune requête de tags
/// ne part pour les autres —, les types proposés et leurs comptes, le
/// formulaire (requêtes exactes de création et de modification, erreurs du
/// serveur feuille ouverte), la limite de 100, la suppression et son compte,
/// et ce qui est relu après une écriture.
class _Teams implements TeamRepository {
  _Teams({this.role, this.refusedWith, this.gate, this.team});

  final String? role;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  final int? refusedWith;

  /// Si posé, `getTeam` attend qu'il soit complété.
  final Completer<void>? gate;

  /// Réécrit la fiche rendue (modules désactivés…).
  final TeamDetailDto Function(TeamDetailDto team)? team;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    await gate?.future;
    final int? status = refusedWith;
    if (status != null) throw _apiError(status, 'NOT_FOUND');
    final TeamDetailDto base = fixtureTeam(slug: slug, role: role);
    return team?.call(base) ?? base;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tags implements TagsClient {
  _Tags([List<TagWithUsageDto>? tags])
    : tags = tags ?? <TagWithUsageDto>[_gravel, _longue, _col];

  List<TagWithUsageDto> tags;
  Object? writeError;
  Object? deleteError;
  int detachedCount = 0;

  /// Si posé, `deleteTeamTag` attend qu'il soit complété.
  Completer<void>? deleteGate;

  /// Les lectures : l'équipe et le type demandé (`null` : tous).
  final List<({String slug, TagTarget? type})> listCalls =
      <({String slug, TagTarget? type})>[];
  final List<({String slug, Map<String, Object?> body})> created =
      <({String slug, Map<String, Object?> body})>[];
  final List<({String slug, String id, Map<String, Object?> body})> updated =
      <({String slug, String id, Map<String, Object?> body})>[];
  final List<({String slug, String id})> deleted =
      <({String slug, String id})>[];

  @override
  Future<List<TagWithUsageDto>> listTeamTags({
    required String teamSlug,
    TagTarget? type,
  }) async {
    listCalls.add((slug: teamSlug, type: type));
    return <TagWithUsageDto>[
      for (final TagWithUsageDto tag in tags)
        if (type == null || tag.type == type.json) tag,
    ];
  }

  @override
  Future<TagWithUsageDto> createTeamTag({
    required String teamSlug,
    required TagCreateRequest body,
  }) async {
    final Object? error = writeError;
    if (error != null) throw error;
    created.add((slug: teamSlug, body: body.toJson()));
    final TagWithUsageDto tag = TagWithUsageDto(
      id: 'new',
      label: body.label,
      color: body.color,
      type: body.type,
      usageCount: 0,
    );
    tags = <TagWithUsageDto>[...tags, tag];
    return tag;
  }

  @override
  Future<TagWithUsageDto> updateTeamTag({
    required String tagId,
    required String teamSlug,
    required TagUpdateRequest body,
  }) async {
    final Object? error = writeError;
    if (error != null) throw error;
    updated.add((slug: teamSlug, id: tagId, body: body.toJson()));
    final TagWithUsageDto before = tags.firstWhere(
      (TagWithUsageDto t) => t.id == tagId,
    );
    final TagWithUsageDto tag = before.copyWith(
      label: body.label ?? before.label,
      color: body.color ?? before.color,
    );
    tags = <TagWithUsageDto>[
      for (final TagWithUsageDto t in tags) t.id == tagId ? tag : t,
    ];
    return tag;
  }

  @override
  Future<TagDeletedDto> deleteTeamTag({
    required String tagId,
    required String teamSlug,
  }) async {
    await deleteGate?.future;
    final Object? error = deleteError;
    if (error != null) throw error;
    deleted.add((slug: teamSlug, id: tagId));
    tags = <TagWithUsageDto>[
      for (final TagWithUsageDto t in tags)
        if (t.id != tagId) t,
    ];
    return TagDeletedDto(detachedCount: detachedCount);
  }
}

const TagWithUsageDto _gravel = TagWithUsageDto(
  id: 't1',
  label: 'Gravel',
  color: 'TEAL',
  type: 'RIDE',
  usageCount: 3,
);

const TagWithUsageDto _longue = TagWithUsageDto(
  id: 't2',
  label: 'Sortie longue',
  color: 'GRAY',
  type: 'RIDE',
  usageCount: 0,
);

const TagWithUsageDto _col = TagWithUsageDto(
  id: 't3',
  label: 'Col',
  color: 'RED',
  type: 'ROUTE',
  usageCount: 1,
);

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton/tags'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton/tags'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));

  final k = keys.teamTags;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> open(
    WidgetTester tester, {
    required _Teams teams,
    _Tags? tags,
    bool platformAdmin = false,
    String? type,
  }) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('hub'),
        ),
        GoRoute(
          path: '/tags',
          builder: (BuildContext _, GoRouterState state) => TeamTagsAdminPage(
            teamSlug: 'n-peloton',
            type: state.uri.queryParameters['type'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams),
          tagsClientProvider.overrideWithValue(tags ?? _Tags()),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push(type == null ? '/tags' : '/tags?type=$type');
    await settle(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(TeamTagsAdminPage)),
      listen: false,
    );
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<PdlButton>(find.byKey(key)).enabled;

  bool actionEnabled(WidgetTester tester, Key key) =>
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed !=
      null;

  String chipLabel(WidgetTester tester, String type) =>
      tester.widget<PdlChip>(find.byKey(k.kind(type))).label;

  bool chipSelected(WidgetTester tester, String type) =>
      tester.widget<PdlChip>(find.byKey(k.kind(type))).selected;

  /// Touche la puce d'un type — amenée à l'écran d'abord : la rangée défile.
  Future<void> tapKind(WidgetTester tester, String type) async {
    await tester.ensureVisible(find.byKey(k.kind(type)));
    await tester.pump();
    await tester.tap(find.byKey(k.kind(type)));
    await settle(tester);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(k.formSubmit));
    await settle(tester);
  }

  group('accès', () {
    for (final String? role in <String?>['ORGANIZER', 'MEMBER', null]) {
      testWidgets('rôle $role : un refus, et aucune requête de tags', (
        WidgetTester tester,
      ) async {
        final _Tags tags = _Tags();
        await open(
          tester,
          teams: _Teams(role: role),
          tags: tags,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.text('Réservé au rôle Administrateur'), findsOneWidget);
        expect(tags.listCalls, isEmpty);
        expect(find.byKey(k.addButton), findsNothing);
        expect(find.text('Gravel'), findsNothing);

        await tester.tap(find.byKey(k.forbiddenBack));
        await settle(tester);
        expect(find.text('hub'), findsOneWidget);
      });
    }

    for (final int status in <int>[403, 404]) {
      testWidgets('une équipe que le serveur refuse ($status) : le refus, '
          'aucune requête de tags', (WidgetTester tester) async {
        final _Tags tags = _Tags();
        await open(
          tester,
          teams: _Teams(refusedWith: status),
          tags: tags,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.byKey(k.loadError), findsNothing);
        expect(tags.listCalls, isEmpty);
      });
    }

    testWidgets('tant que la fiche charge : ni liste, ni refus, ni requête', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN', gate: gate),
        tags: tags,
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(tags.listCalls, isEmpty);

      gate.complete();
      await settle(tester);
      expect(tags.listCalls, hasLength(1));
    });

    testWidgets('rôle ADMIN : tout le vocabulaire, lu une fois, sans type', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(tags.listCalls, <({String slug, TagTarget? type})>[
        (slug: 'n-peloton', type: null),
      ]);
      expect(find.byKey(k.row('t1')), findsOneWidget);
      expect(find.byKey(k.addButton), findsOneWidget);
    });

    testWidgets('admin de plateforme non membre : le vocabulaire', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      await open(tester, teams: _Teams(), tags: tags, platformAdmin: true);

      expect(find.byKey(k.forbidden), findsNothing);
      expect(find.byKey(k.row('t1')), findsOneWidget);
      expect(tags.listCalls, hasLength(1));
    });
  });

  group('types', () {
    testWidgets('une puce par type, avec son compte ; le premier est ouvert', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      expect(chipLabel(tester, 'RIDE'), 'Sorties (2)');
      expect(chipLabel(tester, 'POST'), 'Publications (0)');
      expect(chipLabel(tester, 'TRIP'), 'Voyages (0)');
      expect(chipLabel(tester, 'ROUTE'), 'Parcours (1)');
      expect(chipLabel(tester, 'AD'), 'Annonces (0)');
      expect(chipSelected(tester, 'RIDE'), isTrue);
      expect(find.byKey(k.row('t1')), findsOneWidget);
      expect(find.byKey(k.row('t2')), findsOneWidget);
      expect(find.byKey(k.row('t3')), findsNothing);
    });

    testWidgets('changer de type ne coûte aucune requête', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tapKind(tester, 'ROUTE');

      expect(chipSelected(tester, 'ROUTE'), isTrue);
      expect(find.byKey(k.row('t3')), findsOneWidget);
      expect(find.byKey(k.row('t1')), findsNothing);
      expect(find.text('1 / 100 tags pour ce type'), findsOneWidget);
      expect(tags.listCalls, hasLength(1));
    });

    testWidgets('`?type=route` ouvre les parcours, comme au site', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        type: 'route',
      );

      expect(chipSelected(tester, 'ROUTE'), isTrue);
      expect(find.byKey(k.row('t3')), findsOneWidget);
    });

    testWidgets('un `?type=` inconnu ouvre le premier type', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        type: 'podcast',
      );

      expect(chipSelected(tester, 'RIDE'), isTrue);
    });

    testWidgets('une section désactivée n\'est proposée que si elle porte '
        'encore des tags', (WidgetTester tester) async {
      await open(
        tester,
        teams: _Teams(
          role: 'ADMIN',
          team: (TeamDetailDto t) => t.copyWith(
            enableRoutes: false,
            enableRides: false,
            enableTrips: false,
            enableAds: false,
          ),
        ),
        tags: _Tags(<TagWithUsageDto>[_col]),
      );

      // Les parcours sont désactivés mais portent un tag : la puce reste.
      expect(find.byKey(k.kind('ROUTE')), findsOneWidget);
      expect(find.byKey(k.kind('POST')), findsOneWidget);
      expect(find.byKey(k.kind('RIDE')), findsNothing);
      expect(find.byKey(k.kind('TRIP')), findsNothing);
      expect(find.byKey(k.kind('AD')), findsNothing);
    });

    testWidgets('aucune section, aucun tag : « Aucune section active »', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(
          role: 'ADMIN',
          team: (TeamDetailDto t) => t.copyWith(
            enableRoutes: false,
            enableRides: false,
            enableTrips: false,
            enableAds: false,
            enablePosts: false,
          ),
        ),
        tags: _Tags(<TagWithUsageDto>[]),
      );

      expect(find.byKey(k.noKind), findsOneWidget);
      expect(find.text('Aucune section active'), findsOneWidget);
      expect(find.byKey(k.addButton), findsNothing);
      expect(find.byKey(k.limit), findsNothing);
    });

    testWidgets('un type sans tag : l\'état vide du site, et son bouton', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        type: 'post',
      );

      expect(find.byKey(k.empty), findsOneWidget);
      expect(find.text('Aucun tag'), findsOneWidget);
      expect(
        find.text(
          'Créez des tags pour classer les publications et les filtrer dans '
          'leur liste.',
        ),
        findsOneWidget,
      );
      expect(find.text('0 / 100 tags pour ce type'), findsOneWidget);

      await tester.tap(find.byKey(k.emptyAddButton));
      await settle(tester);
      expect(find.byKey(k.formSheet), findsOneWidget);
    });
  });

  group('liste', () {
    testWidgets('une ligne : la puce du tag et son usage, au bon pluriel', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      expect(
        tester.widget<PdlTag>(find.byKey(k.rowChip('t1'))).label,
        'Gravel',
      );
      expect(
        tester.widget<Text>(find.byKey(k.rowUsage('t1'))).data,
        '3 contenus',
      );
      expect(
        tester.widget<Text>(find.byKey(k.rowUsage('t2'))).data,
        'Inutilisé',
      );
      expect(find.text('2 / 100 tags pour ce type'), findsOneWidget);

      await tapKind(tester, 'ROUTE');
      expect(
        tester.widget<Text>(find.byKey(k.rowUsage('t3'))).data,
        '1 contenu',
      );
    });

    testWidgets('à 100 tags, « Nouveau tag » est inactif', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags(<TagWithUsageDto>[
        for (int i = 0; i < 100; i++)
          TagWithUsageDto(
            id: 'r$i',
            label: 'Tag $i',
            color: 'GRAY',
            type: 'RIDE',
            usageCount: 0,
          ),
      ]);
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      expect(find.text('100 / 100 tags pour ce type'), findsOneWidget);
      expect(enabled(tester, k.addButton), isFalse);

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      expect(find.byKey(k.formSheet), findsNothing);

      // Un autre type n'est pas plein.
      await tapKind(tester, 'POST');
      expect(enabled(tester, k.addButton), isTrue);
    });

    testWidgets('le vocabulaire en échec : une erreur, et « Réessayer » le '
        'relit', (WidgetTester tester) async {
      final _FailingOnce tags = _FailingOnce();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      expect(find.byKey(k.tagsError), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(find.byKey(k.tagsError), findsNothing);
      expect(find.byKey(k.row('t1')), findsOneWidget);
    });
  });

  group('formulaire', () {
    testWidgets('création : la requête exacte — type de la puce ouverte, '
        'libellé rogné, gris par défaut', (WidgetTester tester) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
        type: 'route',
      );

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      expect(find.text('Nouveau tag'), findsWidgets);
      // Les neuf couleurs du contrat.
      for (final TagColor color in TagColor.$valuesDefined) {
        expect(find.byKey(k.formColor(color.json!)), findsOneWidget);
      }
      // Pas d'aperçu tant que le libellé est vide.
      expect(find.byKey(k.formPreview), findsNothing);

      await tester.enterText(find.byKey(k.formLabel), '  Vallonné ');
      await settle(tester);
      expect(
        tester.widget<PdlTag>(find.byKey(k.formPreview)).label,
        'Vallonné',
      );
      await submit(tester);

      expect(tags.created.single.slug, 'n-peloton');
      expect(tags.created.single.body, <String, Object?>{
        'type': 'ROUTE',
        'label': 'Vallonné',
        'color': 'GRAY',
      });
      expect(find.byKey(k.formSheet), findsNothing);
      expect(find.text('Tag créé'), findsOneWidget);
      expect(find.byKey(k.row('new')), findsOneWidget);
      expect(chipLabel(tester, 'ROUTE'), 'Parcours (2)');
    });

    testWidgets('création : la couleur choisie part', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      await tester.enterText(find.byKey(k.formLabel), 'Route');
      await tester.tap(find.byKey(k.formColor('ORANGE')));
      await settle(tester);
      await submit(tester);

      expect(tags.created.single.body, <String, Object?>{
        'type': 'RIDE',
        'label': 'Route',
        'color': 'ORANGE',
      });
    });

    testWidgets('modification : libellé et couleur, jamais le type', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.rowEdit('t1')));
      await settle(tester);
      expect(find.text('Modifier le tag'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(k.formLabel)).controller!.text,
        'Gravel',
      );

      await tester.enterText(find.byKey(k.formLabel), 'Gravier');
      await tester.tap(find.byKey(k.formColor('GREEN')));
      await settle(tester);
      await submit(tester);

      expect(tags.updated.single.slug, 'n-peloton');
      expect(tags.updated.single.id, 't1');
      expect(tags.updated.single.body, <String, Object?>{
        'label': 'Gravier',
        'color': 'GREEN',
      });
      expect(tags.created, isEmpty);
      expect(find.text('Tag modifié'), findsOneWidget);
      expect(
        tester.widget<PdlTag>(find.byKey(k.rowChip('t1'))).label,
        'Gravier',
      );
    });

    testWidgets(
      'un formulaire intact renvoie le libellé et la couleur du tag',
      (WidgetTester tester) async {
        final _Tags tags = _Tags();
        await open(
          tester,
          teams: _Teams(role: 'ADMIN'),
          tags: tags,
        );

        await tester.tap(find.byKey(k.rowEdit('t1')));
        await settle(tester);
        await submit(tester);

        expect(tags.updated.single.body, <String, Object?>{
          'label': 'Gravel',
          'color': 'TEAL',
        });
      },
    );

    for (final String label in <String>['', '   ', 'a' * 33]) {
      testWidgets('un libellé de ${label.length} caractères n\'envoie rien, '
          'et le champ le dit', (WidgetTester tester) async {
        final _Tags tags = _Tags();
        await open(
          tester,
          teams: _Teams(role: 'ADMIN'),
          tags: tags,
        );

        await tester.tap(find.byKey(k.addButton));
        await settle(tester);
        expect(find.text('Entre 1 et 32 caractères'), findsNothing);
        await tester.enterText(find.byKey(k.formLabel), label);
        await submit(tester);

        expect(tags.created, isEmpty);
        expect(find.byKey(k.formSheet), findsOneWidget);
        expect(find.text('Entre 1 et 32 caractères'), findsOneWidget);
        // La saisie n'a pas été coupée.
        expect(
          tester.widget<TextField>(find.byKey(k.formLabel)).controller!.text,
          label,
        );
      });
    }

    for (final (String code, String message) in <(String, String)>[
      (
        'TAG_LABEL_TAKEN',
        'Un tag porte déjà ce libellé pour ce type de contenu.',
      ),
      (
        'TAG_LABEL_INVALID',
        'Le libellé d\'un tag doit faire entre 1 et 32 caractères.',
      ),
      (
        'TAG_LIMIT_REACHED',
        'Cette équipe a atteint le maximum de 100 tags pour ce type de '
            'contenu.',
      ),
    ]) {
      testWidgets('$code : un bandeau, la feuille ouverte, la saisie gardée', (
        WidgetTester tester,
      ) async {
        final _Tags tags = _Tags()..writeError = _apiError(409, code);
        await open(
          tester,
          teams: _Teams(role: 'ADMIN'),
          tags: tags,
        );

        await tester.tap(find.byKey(k.addButton));
        await settle(tester);
        await tester.enterText(find.byKey(k.formLabel), 'gravel');
        await submit(tester);

        expect(find.byKey(k.formSheet), findsOneWidget);
        expect(find.byKey(k.formErrorBanner), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byKey(k.formLabel)).controller!.text,
          'gravel',
        );

        // La correction repart.
        tags.writeError = null;
        await tester.enterText(find.byKey(k.formLabel), 'Gravel 2');
        await submit(tester);
        expect(tags.created.single.body['label'], 'Gravel 2');
        expect(find.byKey(k.formSheet), findsNothing);
      });
    }

    testWidgets(
      'un double appui sur « Nouveau tag » n\'ouvre qu\'une feuille',
      (WidgetTester tester) async {
        await open(tester, teams: _Teams(role: 'ADMIN'));

        await tester.tap(find.byKey(k.addButton));
        await tester.tap(find.byKey(k.addButton), warnIfMissed: false);
        await settle(tester);

        expect(find.byKey(k.formSheet), findsOneWidget);
      },
    );
  });

  group('suppression', () {
    testWidgets('la confirmation montre la puce et le nombre de contenus ; '
        'le message dit combien en ont été détachés', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags()..detachedCount = 3;
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.rowDelete('t1')));
      await settle(tester);

      expect(find.text('Supprimer le tag ?'), findsOneWidget);
      expect(tester.widget<PdlTag>(find.byKey(k.deleteChip)).label, 'Gravel');
      expect(
        find.text(
          'Il sera retiré des 3 contenus qui le portent. Cette suppression '
          'est définitive.',
        ),
        findsOneWidget,
      );
      expect(tags.deleted, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(tags.deleted.single, (slug: 'n-peloton', id: 't1'));
      expect(find.text('Tag supprimé et retiré de 3 contenus'), findsOneWidget);
      expect(find.byKey(k.row('t1')), findsNothing);
      expect(chipLabel(tester, 'RIDE'), 'Sorties (1)');
    });

    testWidgets('un tag inutilisé : « Aucun contenu ne le porte », puis '
        '« Tag supprimé »', (WidgetTester tester) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.rowDelete('t2')));
      await settle(tester);
      expect(
        find.text(
          'Aucun contenu ne le porte. Cette suppression est définitive.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(find.text('Tag supprimé'), findsOneWidget);
    });

    testWidgets('un seul contenu : le singulier', (WidgetTester tester) async {
      final _Tags tags = _Tags()..detachedCount = 1;
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
        type: 'route',
      );

      await tester.tap(find.byKey(k.rowDelete('t3')));
      await settle(tester);
      expect(
        find.text(
          'Il sera retiré du contenu qui le porte. Cette suppression est '
          'définitive.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(find.text('Tag supprimé et retiré de 1 contenu'), findsOneWidget);
    });

    testWidgets('annuler n\'envoie rien, et rend les gestes', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.rowDelete('t1')));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(tags.deleted, isEmpty);
      expect(find.byKey(k.row('t1')), findsOneWidget);
      expect(actionEnabled(tester, k.rowDelete('t1')), isTrue);
      expect(enabled(tester, k.addButton), isTrue);
    });

    testWidgets('un double appui n\'ouvre qu\'une confirmation et n\'envoie '
        'qu\'une suppression', (WidgetTester tester) async {
      final _Tags tags = _Tags();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.rowDelete('t1')));
      await tester.tap(find.byKey(k.rowDelete('t1')), warnIfMissed: false);
      await settle(tester);

      expect(find.byKey(keys.profile.confirmDestructiveButton), findsOneWidget);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);
      expect(tags.deleted, hasLength(1));
    });

    testWidgets('pendant la suppression, les autres gestes attendent', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags()..deleteGate = Completer<void>();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.rowDelete('t1')));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(enabled(tester, k.addButton), isFalse);
      expect(actionEnabled(tester, k.rowEdit('t2')), isFalse);
      expect(actionEnabled(tester, k.rowDelete('t2')), isFalse);

      tags.deleteGate!.complete();
      await settle(tester);
      expect(enabled(tester, k.addButton), isTrue);
      expect(actionEnabled(tester, k.rowDelete('t2')), isTrue);
    });

    testWidgets('le serveur refuse : un bandeau, la ligne reste', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags()..deleteError = _apiError(403, 'FORBIDDEN');
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );

      await tester.tap(find.byKey(k.rowDelete('t1')));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(find.byKey(k.row('t1')), findsOneWidget);
      expect(actionEnabled(tester, k.rowDelete('t1')), isTrue);
    });
  });

  group('après une écriture', () {
    testWidgets('le vocabulaire de l\'écran est relu sans repasser par un '
        'chargement, et celui des filtres et des éditeurs aussi', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      final ProviderContainer container = await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
      );
      // Un filtre de la liste des sorties, resté ouvert sous l'écran, et
      // celui des parcours.
      final ProviderSubscription<AsyncValue<List<TagWithUsageDto>>> rides =
          container.listen(
            teamTagsProvider((teamSlug: 'n-peloton', type: TagTarget.ride)),
            (_, _) {},
          );
      final ProviderSubscription<AsyncValue<List<TagWithUsageDto>>> routes =
          container.listen(
            teamTagsProvider((teamSlug: 'n-peloton', type: TagTarget.route)),
            (_, _) {},
          );
      addTearDown(rides.close);
      addTearDown(routes.close);
      await settle(tester);
      tags.listCalls.clear();

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      await tester.enterText(find.byKey(k.formLabel), 'Nocturne');
      await tester.tap(find.byKey(k.formSubmit));
      // Entre la réponse et la relecture, les lignes restent à l'écran.
      await tester.pump();
      expect(find.byKey(k.row('t1')), findsOneWidget);
      await settle(tester);

      expect(tags.listCalls, <({String slug, TagTarget? type})>[
        (slug: 'n-peloton', type: null),
        (slug: 'n-peloton', type: TagTarget.ride),
      ]);
      expect(
        rides.read().value!.map((TagWithUsageDto t) => t.label),
        contains('Nocturne'),
      );
    });

    testWidgets('une suppression relit le type du tag, pas les autres', (
      WidgetTester tester,
    ) async {
      final _Tags tags = _Tags();
      final ProviderContainer container = await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        tags: tags,
        type: 'route',
      );
      final ProviderSubscription<AsyncValue<List<TagWithUsageDto>>> rides =
          container.listen(
            teamTagsProvider((teamSlug: 'n-peloton', type: TagTarget.ride)),
            (_, _) {},
          );
      final ProviderSubscription<AsyncValue<List<TagWithUsageDto>>> routes =
          container.listen(
            teamTagsProvider((teamSlug: 'n-peloton', type: TagTarget.route)),
            (_, _) {},
          );
      addTearDown(rides.close);
      addTearDown(routes.close);
      await settle(tester);
      tags.listCalls.clear();

      await tester.tap(find.byKey(k.rowDelete('t3')));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(tags.listCalls, <({String slug, TagTarget? type})>[
        (slug: 'n-peloton', type: null),
        (slug: 'n-peloton', type: TagTarget.route),
      ]);
      expect(routes.read().value, isEmpty);
    });
  });
}

/// Un vocabulaire dont la première lecture échoue.
class _FailingOnce extends _Tags {
  bool _failed = false;

  @override
  Future<List<TagWithUsageDto>> listTeamTags({
    required String teamSlug,
    TagTarget? type,
  }) async {
    if (!_failed) {
      _failed = true;
      throw _apiError(500, 'UNKNOWN');
    }
    return super.listTeamTags(teamSlug: teamSlug, type: type);
  }
}
