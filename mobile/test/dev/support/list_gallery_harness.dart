import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/dev/list_gallery/gallery_api.dart';
import 'package:pedalons/dev/list_gallery/list_sections.dart';
import 'package:pedalons/dev/list_gallery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monte un cas de la galerie des listes sous un `GoRouter`, comme l'app le
/// fait à `/dev/listes/<section>/<cas>`, joue ses gestes, et rend son serveur
/// factice.
///
/// [images] et [prepareImages] : voir `ListGalleryPage`.
Future<GalleryApi> pumpListCase(
  WidgetTester tester, {
  required ListSection section,
  required ListCase item,
  required SharedPreferences prefs,
  bool images = false,
  Future<void> Function()? prepareImages,
  Widget Function(Widget app)? wrap,
  void Function(GalleryApi api)? beforeSteps,
}) async {
  GalleryApi? api;
  final GoRouter router = GoRouter(
    initialLocation: '$kListGalleryPath/${section.id}/${item.id}',
    routes: <RouteBase>[
      GoRoute(
        path: '$kListGalleryPath/:section/:case',
        builder: (BuildContext _, GoRouterState state) => ListGalleryPage(
          sectionId: state.pathParameters['section'],
          caseId: state.pathParameters['case'],
          images: images,
          prepareImages: prepareImages ?? () async {},
          scoped: false,
        ),
      ),
    ],
  );
  // Le conteneur du cas **au-dessus** de l'application : une feuille, qui
  // s'ouvre sur le navigateur racine, y lit les mêmes fournisseurs que la
  // page.
  final Widget app = ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: ListCaseScope(
      item: item,
      data: GalleryData(images: images),
      onApi: (GalleryApi a) => api = a,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: PedalonsTheme.build(Brightness.light),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await settleList(tester);
  beforeSteps?.call(api!);
  await playListSteps(tester, item.steps);
  return api!;
}

/// Joue les gestes d'un cas, par de vrais appuis et de vraies saisies.
Future<void> playListSteps(WidgetTester tester, List<ListStep> steps) async {
  for (final ListStep step in steps) {
    switch (step) {
      case ListTap(:final ListTarget target):
        final Finder f = listTargetFinder(target);
        expect(f, findsWidgets, reason: 'cible du geste : $target');
        await tester.ensureVisible(f.first);
        await tester.pump();
        await tester.tap(f.first);
      case ListScrollTo(:final ListTarget target):
        final Finder f = listTargetFinder(target);
        for (int i = 0; i < 30; i++) {
          if (f.evaluate().isNotEmpty && tester.getTopLeft(f.first).dy < 140) {
            break;
          }
          final Finder scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isEmpty) break;
          final ScrollableState state = tester.state<ScrollableState>(
            scrollable.first,
          );
          if (state.position.pixels >= state.position.maxScrollExtent) break;
          await tester.drag(scrollable.first, const Offset(0, -120));
          await tester.pump(const Duration(milliseconds: 100));
        }
      case ListEnterText(:final ListTarget target, :final String text):
        final Finder f = listTargetFinder(target);
        expect(f, findsWidgets, reason: 'champ du geste : $target');
        await tester.enterText(f.first, text);
    }
    await settleList(tester);
  }
}

Finder listTargetFinder(ListTarget t) {
  if (t.field) {
    return t.key == null
        ? find.byType(EditableText)
        : find.descendant(
            of: find.byKey(t.key!),
            matching: find.byType(EditableText),
          );
  }
  final Finder base = t.key != null
      ? find.byKey(t.key!)
      : t.icon != null
      ? find.byIcon(t.icon!)
      : t.tooltip != null
      ? find.byTooltip(t.tooltip!.tr())
      : find.text(t.text!);
  return t.within == null
      ? base
      : find.descendant(of: find.byType(t.within!), matching: base);
}

/// Laisse passer les réponses, les recherches débattues et les animations
/// d'entrée — pas de `pumpAndSettle`, qu'un squelette animé ferait tourner
/// sans fin.
Future<void> settleList(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
