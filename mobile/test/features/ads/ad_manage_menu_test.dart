import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/ads/data/ad_repository.dart';
import 'package:pedalons/features/ads/presentation/widgets/ad_manage_menu.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import 'ad_fixtures.dart';

/// Le menu « Gérer l'annonce » (ledger `MOB-158`).
class _StubAds implements AdRepository {
  final List<String> statuses = <String>[];
  final List<String> deleted = <String>[];
  final List<String> restored = <String>[];

  @override
  Future<AdDto> changeStatus(
    String teamSlug,
    String adSlug,
    Status status,
  ) async {
    statuses.add('$adSlug ${status.json}');
    return fixtureAd(slug: adSlug, status: status.json!);
  }

  @override
  Future<void> deleteAd(String teamSlug, String adSlug) async =>
      deleted.add('$teamSlug/$adSlug');

  @override
  Future<void> undeleteAd(String teamSlug, String adSlug) async =>
      restored.add('$teamSlug/$adSlug');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AdDto _mine({String status = 'PUBLISHED', bool deleted = false}) => fixtureAd(
  status: status,
  deleted: deleted,
  permissions: kAdOwnerPermissions,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  group('adManageActions', () {
    test('selon le statut, comme le menu du site', () {
      expect(
        adManageActions(_mine(status: 'DRAFT'), canReport: false),
        <AdManageAction>[AdManageAction.publish, AdManageAction.delete],
      );
      expect(adManageActions(_mine(), canReport: false), <AdManageAction>[
        AdManageAction.unpublish,
        AdManageAction.delete,
      ]);
    });

    test('l\'administration de l\'équipe peut aussi signaler', () {
      expect(adManageActions(_mine(), canReport: true), <AdManageAction>[
        AdManageAction.unpublish,
        AdManageAction.delete,
        AdManageAction.report,
      ]);
    });

    test("une annonce supprimée n'offre que sa restauration", () {
      expect(
        adManageActions(_mine(deleted: true), canReport: true),
        <AdManageAction>[AdManageAction.restore],
      );
    });

    // Les droits viennent du bloc `permissions` de l'annonce
    // (docs/LEDGER_*.md MOB-137).
    test('sans aucun droit : le signalement seul, et pas de « Gérer »', () {
      final AdDto ad = fixtureAd(permissions: kNoPermissions);
      expect(adManageActions(ad, canReport: true), <AdManageAction>[
        AdManageAction.report,
      ]);
      expect(adHasManageActions(ad), isFalse);
    });
  });

  group('la feuille', () {
    late SharedPreferences prefs;
    late _StubAds ads;

    setUp(() async {
      setCurrentLocale('fr');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      ads = _StubAds();
    });

    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester, {required AdDto ad}) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext _, GoRouterState _) => Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          showAdManageMenu(context, ref, ad, canReport: false),
                      child: const Text('ouvrir'),
                    ),
                  ),
            ),
          ),
          GoRoute(
            path: PathVariants.teamAds(':teamSlug')['fr']!,
            builder: (BuildContext _, GoRouterState _) =>
                const Text('annonces de l\'équipe'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            adRepositoryProvider.overrideWithValue(ads),
          ],
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await settle(tester);
    }

    testWidgets('un brouillon se publie sans confirmation', (
      WidgetTester tester,
    ) async {
      await pump(tester, ad: _mine(status: 'DRAFT'));

      expect(find.text('Gérer l\'annonce'), findsOneWidget);
      expect(find.byKey(keys.adManage.report), findsNothing);
      await tester.tap(find.byKey(keys.adManage.publish));
      await settle(tester);

      expect(ads.statuses, <String>['velo-a-vendre PUBLISHED']);
      expect(find.text('Annonce publiée'), findsOneWidget);
    });

    testWidgets('dépublier demande confirmation', (WidgetTester tester) async {
      await pump(tester, ad: _mine());

      await tester.tap(find.byKey(keys.adManage.unpublish));
      await settle(tester);
      expect(find.text('Dépublier l\'annonce ?'), findsOneWidget);
      expect(ads.statuses, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);
      expect(ads.statuses, <String>['velo-a-vendre DRAFT']);
    });

    testWidgets('une annonce supprimée : « Restaurer » seulement', (
      WidgetTester tester,
    ) async {
      await pump(tester, ad: _mine(deleted: true));

      expect(find.byKey(keys.adManage.delete), findsNothing);
      await tester.tap(find.byKey(keys.adManage.restore));
      await settle(tester);

      expect(ads.restored, <String>['n-peloton/velo-a-vendre']);
      expect(find.text('Annonce restaurée'), findsOneWidget);
    });

    testWidgets('la suppression demande confirmation, puis supprime', (
      WidgetTester tester,
    ) async {
      await pump(tester, ad: _mine());

      await tester.tap(find.byKey(keys.adManage.delete));
      await settle(tester);
      expect(find.text('Supprimer l\'annonce ?'), findsOneWidget);
      expect(ads.deleted, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(ads.deleted, <String>['n-peloton/velo-a-vendre']);
      // Rien dessous : retour aux annonces de l'équipe.
      expect(find.text('annonces de l\'équipe'), findsOneWidget);
    });
  });
}
