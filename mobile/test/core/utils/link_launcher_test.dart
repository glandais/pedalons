import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/pdl/pdl_image_viewer.dart';
import 'package:pedalons/core/pdl/pdl_markdown_body.dart';
import 'package:pedalons/core/pdl/pdl_banner.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/link_launcher.dart';
import 'package:pedalons/core/widgets/authenticated_image.dart';
import 'package:pedalons/core/widgets/markdown_content.dart';
import 'package:photo_view/photo_view.dart';

/// F-TE-10 / F-DE-6 — le lien markdown était **stylé mais inerte** :
/// `LinkConfig` sans `onTap` n'attache aucun `TapGestureRecognizer`, et
/// `markdown_widget` se contentait de souligner en bleu une inscription qui
/// n'ouvrait rien.
///
/// Ce fichier prouve trois choses, dans cet ordre de sévérité :
///
/// 1. **aucun lien n'est inerte** — le recognizer est bien attaché, et le tap
///    produit un effet observable ;
/// 2. la résolution suit les trois temps du plan §1.3.5 — interne, système,
///    bandeau — et **jamais rien de silencieux** ;
/// 3. la feuille de style tient ses promesses vérifiables : table de 4 colonnes
///    qui défile sans faire déborder la page, emoji préservés, code copiable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final Map<String, dynamic> fr =
        json.decode(File('assets/l10n/fr.json').readAsStringSync())
            as Map<String, dynamic>;
    Localization.load(
      const Locale('fr'),
      translations: Translations(fr),
      fallbackTranslations: Translations(fr),
    );
  });

  tearDown(() => debugLinkOpener = null);

  group('internalLocationFor', () {
    test('reconnaît une route du domaine courant, dans les deux locales', () {
      expect(
        internalLocationFor('https://www.pedalons.fr/equipes/vc/sorties/rando'),
        '/equipes/vc/sorties/rando',
      );
      expect(
        internalLocationFor('https://www.pedalons.fr/teams/vc/rides/ride'),
        '/teams/vc/rides/ride',
      );
      // Le `www.` n'est pas une différence de domaine.
      expect(
        internalLocationFor('https://pedalons.fr/equipes/vc'),
        '/equipes/vc',
      );
    });

    test('reconnaît un lien relatif, écrit sans domaine', () {
      expect(
        internalLocationFor('/equipes/vc/articles/mon-article'),
        '/equipes/vc/articles/mon-article',
      );
      expect(internalLocationFor('/'), '/');
    });

    test('conserve la requête et le fragment', () {
      expect(
        internalLocationFor('/parcours?tri=distance#haut'),
        '/parcours?tri=distance#haut',
      );
    });

    test('un autre domaine reste externe, même sur un chemin connu', () {
      expect(
        internalLocationFor('https://strava.com/equipes/vc/sorties/rando'),
        isNull,
      );
    });

    test('un chemin inconnu du contrat reste externe', () {
      expect(
        internalLocationFor('https://www.pedalons.fr/blog/2026/juillet'),
        isNull,
      );
    });

    test('les schémas non http ne sont jamais internes', () {
      for (final String href in const <String>[
        'mailto:contact@pedalons.fr',
        'tel:+33600000000',
        'webcal://www.pedalons.fr/api/calendar/ics',
      ]) {
        expect(internalLocationFor(href), isNull, reason: href);
      }
    });

    test('une page du site sans écran dans l\'app part dans le navigateur', () {
      for (final String path in PathVariants.features().values) {
        expect(
          internalLocationFor('https://www.pedalons.fr$path'),
          isNull,
          reason: path,
        );
      }
    });

    test('une ancre seule ne renvoie pas à l\'accueil', () {
      // Sans garde-fou, `#section` se résout en chemin vide, donc en `/` : un
      // lien intra-page éjecterait le lecteur vers l'accueil.
      expect(internalLocationFor('#section'), isNull);
      expect(internalLocationFor(''), isNull);
    });

    test('couvre toutes les entrées de PathVariants', () {
      // `paths.generated.dart` est régénéré depuis `contracts/routes.yaml` :
      // une route ajoutée au contrat et oubliée ici partirait dans le
      // navigateur au lieu de s'ouvrir dans l'app. Le test lit la source.
      final String source = File(
        'lib/config/paths.generated.dart',
      ).readAsStringSync();
      final String variants = source.substring(
        source.indexOf('class PathVariants'),
      );
      final Set<String> declared = RegExp(
        r'static Map<String, String> (\w+)\(',
      ).allMatches(variants).map((RegExpMatch m) => m.group(1)!).toSet();

      expect(declared, isNotEmpty);
      expect(
        <String>{...internalRouteTemplates.keys, ...webOnlyRouteIds},
        declared,
        reason:
            'Toute entrée de PathVariants doit avoir son motif dans '
            'internalRouteTemplates, sinon le lien interne part dehors.',
      );
    });
  });

  group('isSitePageLocation', () {
    // Les pages du site qu'ouvre le tableau de bord, dans les deux locales :
    // `/equipes/.*` les donne à l'app sous Android (docs/LEDGER_*.md MOB-59).
    final List<String> sitePages = <String>[
      ...PathVariants.teamAdminMembers('vc').values,
      ...PathVariants.teamAdminReports('vc').values,
      ...PathVariants.teamSettings('vc').values,
      ...PathVariants.tripEdit('vc', 'ete').values,
      ...PathVariants.postNew('vc').values,
      ...PathVariants.postEdit('vc', 'news').values,
    ];

    test('reconnaît les pages du site sans écran, requête comprise', () {
      for (final String page in sitePages) {
        expect(isSitePageLocation(page), isTrue, reason: page);
        expect(isSitePageLocation('$page?invite=1'), isTrue, reason: page);
        expect(internalLocationFor(page), isNull, reason: page);
      }
    });

    test('l\'éditeur de sortie s\'ouvre dans l\'app (MOB-76)', () {
      for (final String page in <String>[
        ...PathVariants.rideNew('vc').values,
        ...PathVariants.rideEdit('vc', 'rando').values,
      ]) {
        expect(isSitePageLocation(page), isFalse, reason: page);
        expect(internalLocationFor(page), page, reason: page);
      }
    });

    test('l\'éditeur de parcours s\'ouvre dans l\'app (MOB-79)', () {
      for (final String page in <String>[
        ...PathVariants.routeNew('vc').values,
        ...PathVariants.routeEdit('vc', 'boucle').values,
      ]) {
        expect(isSitePageLocation(page), isFalse, reason: page);
        expect(internalLocationFor(page), page, reason: page);
      }
    });

    test('les modèles de sortie s\'ouvrent dans l\'app (MOB-78)', () {
      for (final String page in <String>[
        ...PathVariants.rideTemplates('vc').values,
        ...PathVariants.rideTemplateNew('vc').values,
        ...PathVariants.rideTemplateEdit('vc', 'samedi').values,
      ]) {
        expect(isSitePageLocation(page), isFalse, reason: page);
        expect(internalLocationFor(page), page, reason: page);
      }
    });

    test('ne prend aucune route de l\'app pour une page du site', () {
      for (final MapEntry<String, List<String>> entry
          in internalRouteTemplates.entries) {
        for (final String template in entry.value) {
          final String location = template.split('\u0001').join('x');
          expect(
            isSitePageLocation(location),
            isFalse,
            reason: '${entry.key} : $location',
          );
        }
      }
    });
  });

  group('aucun lien inerte', () {
    testWidgets('chaque span de lien porte un TapGestureRecognizer', (
      WidgetTester tester,
    ) async {
      await _pumpMarkdown(
        tester,
        'Inscrivez-vous [ici](https://www.pedalons.fr/equipes/vc/sorties/r) '
        'ou écrivez à [contact](mailto:contact@pedalons.fr).',
      );

      final List<InlineSpan> withRecognizer = <InlineSpan>[];
      final List<String> texts = <String>[];
      for (final Element element in find.byType(RichText).evaluate()) {
        (element.widget as RichText).text.visitChildren((InlineSpan span) {
          if (span is TextSpan && (span.text?.isNotEmpty ?? false)) {
            texts.add(span.text!);
            if (span.recognizer is TapGestureRecognizer) {
              withRecognizer.add(span);
            }
          }
          return true;
        });
      }

      expect(texts.join(), contains('ici'));
      // Deux liens dans le texte, deux recognizers : c'est exactement ce que
      // `LinkConfig` sans `onTap` ne produisait pas.
      expect(
        withRecognizer.length,
        greaterThanOrEqualTo(2),
        reason: 'Un lien sans recognizer est un lien inerte.',
      );
    });

    testWidgets('un lien interne pousse la route, sans navigateur', (
      WidgetTester tester,
    ) async {
      final List<Uri> launched = <Uri>[];
      debugLinkOpener = (Uri url) async {
        launched.add(url);
        return true;
      };

      final GoRouter router = await _pumpMarkdown(
        tester,
        'Voir la [sortie](https://www.pedalons.fr/equipes/vc/sorties/rando).',
      );

      await _tapLink(tester, 'sortie');

      // L'écran de la sortie est **affiché** : c'est l'effet observable, là où
      // `currentConfiguration.uri` reste sur la base après un `push`
      // impératif.
      expect(find.text('page de la sortie'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.matches,
        hasLength(2),
        reason: 'Le lien interne empile, il ne remplace pas.',
      );
      expect(launched, isEmpty, reason: 'Une route interne ne sort pas.');
    });

    // `…/sorties/nouvelle` était l'exemple jusqu'à `MOB-76`, qui en a fait
    // un écran de l'app ; `…/articles/nouveau` a la même ambiguïté avec
    // l'article de slug `nouveau` et reste une page du site.
    testWidgets('une page du site part au navigateur, pas sur l\'article '
        '« nouveau » (MOB-59)', (WidgetTester tester) async {
      final List<Uri> launched = <Uri>[];
      debugLinkOpener = (Uri url) async {
        launched.add(url);
        return true;
      };

      final GoRouter router = await _pumpMarkdown(
        tester,
        'Proposez un [article](https://www.pedalons.fr/equipes/vc/articles/nouveau).',
      );

      await _tapLink(tester, 'article');

      expect(find.text('page de l\'article'), findsNothing);
      expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
      expect(launched.single.path, '/equipes/vc/articles/nouveau');
    });

    testWidgets('un lien externe part au système, jamais dans le routeur', (
      WidgetTester tester,
    ) async {
      final List<Uri> launched = <Uri>[];
      debugLinkOpener = (Uri url) async {
        launched.add(url);
        return true;
      };

      await _pumpMarkdown(
        tester,
        'Le tracé est sur [Strava](https://www.strava.com/routes/42), '
        'écrivez à [nous](mailto:contact@pedalons.fr) '
        'ou appelez le [06](tel:+33600000000), '
        'et abonnez-vous en [ICS](webcal://www.pedalons.fr/ics).',
      );

      for (final String label in const <String>[
        'Strava',
        'nous',
        '06',
        'ICS',
      ]) {
        await _tapLink(tester, label);
      }

      expect(launched.map((Uri u) => u.scheme).toList(), <String>[
        'https',
        'mailto',
        'tel',
        'webcal',
      ]);
      expect(launched.first.host, 'www.strava.com');
      expect(find.text('page de la sortie'), findsNothing);
      expect(find.byType(PdlBanner), findsNothing);
    });

    testWidgets('un lancement refusé rend un bandeau, jamais rien', (
      WidgetTester tester,
    ) async {
      debugLinkOpener = (Uri url) async => false;

      await _pumpMarkdown(
        tester,
        'Ouvrez [le fichier](zoiberg://ouvre/moi) pour continuer.',
      );

      await _tapLink(tester, 'le fichier');

      expect(find.byType(PdlBanner), findsOneWidget);
      // L'URL est en clair : sans elle, l'utilisateur ne peut rien faire de
      // l'échec.
      expect(find.textContaining('zoiberg://ouvre/moi'), findsOneWidget);
      expect(find.text('Copier le lien'), findsOneWidget);

      // Et l'action copie vraiment.
      final List<MethodCall> clipboard = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') clipboard.add(call);
          return null;
        },
      );
      await tester.tap(find.text('Copier le lien'));
      await tester.pumpAndSettle();
      expect(clipboard.single.arguments['text'], 'zoiberg://ouvre/moi');
    });

    testWidgets('un schéma qui lève aboutit au même bandeau', (
      WidgetTester tester,
    ) async {
      debugLinkOpener = (Uri url) async => throw const _PlatformRefusal();

      await _pumpMarkdown(tester, 'Essayez [ceci](inconnu:cible).');
      await _tapLink(tester, 'ceci');

      expect(find.byType(PdlBanner), findsOneWidget);
    });
  });

  group('feuille de style §1.3.5', () {
    testWidgets('une table de 4 colonnes défile sans déborder la page', (
      WidgetTester tester,
    ) async {
      await _pumpMarkdown(tester, _tableMarkdown);

      // Aucune exception de dépassement : `pumpAndSettle` les aurait levées.
      expect(tester.takeException(), isNull);

      // La table a son propre défilement horizontal, distinct de celui de la
      // page — sinon le glissement latéral emporterait le défilement vertical.
      final Finder horizontal = find.byWidgetPredicate(
        (Widget w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(horizontal, findsWidgets);

      // Emoji préservés : la troncature naïve par `substring` les coupe en
      // deux unités UTF-16 et rend un losange.
      expect(find.textContaining('🚴'), findsWidgets);

      // Le conteneur reste dans la page (390 px de large) alors que la table
      // impose 430 px : c'est bien elle qui défile, pas la page.
      final Finder tableScroller = horizontal.last;
      expect(
        tester.getSize(tableScroller).width,
        lessThanOrEqualTo(390),
        reason: 'La table ne doit pas élargir la page.',
      );
      expect(
        tester
            .widgetList<ConstrainedBox>(
              find.descendant(
                of: tableScroller,
                matching: find.byType(ConstrainedBox),
              ),
            )
            .any(
              (ConstrainedBox b) =>
                  b.constraints.minWidth == PdlMarkdownBody.tableMinWidth,
            ),
        isTrue,
      );
    });

    testWidgets('une image d\'article s\'ouvre en plein écran avec un Hero', (
      WidgetTester tester,
    ) async {
      await _pumpMarkdown(
        tester,
        '![Le col](https://exemple.test/col.png)',
        settle: false,
      );

      final Finder image = find.byType(AuthenticatedImage);
      expect(image, findsOneWidget);
      // La vignette est bien la source d'un Hero — sans lui, la visionneuse
      // s'ouvre en fondu et l'image saute d'un coin à l'autre.
      expect(find.ancestor(of: image, matching: find.byType(Hero)), findsOne);
      expect(tester.getSize(image).height, PdlMarkdownBody.imageHeight);

      await tester.tap(image, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PdlImageViewer), findsOneWidget);
      expect(find.byType(PhotoView), findsOneWidget);
    });

    testWidgets('un appui long sur un bloc de code le copie', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> clipboard = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') clipboard.add(call);
          return null;
        },
      );

      await _pumpMarkdown(tester, '```\nflutter test\n```');

      await tester.longPress(find.textContaining('flutter test').first);
      await tester.pumpAndSettle();

      expect(clipboard, hasLength(1));
      expect(clipboard.single.arguments['text'], contains('flutter test'));
    });
  });
}

/// Un refus de plateforme, joué sans dépendre de `PlatformException`.
class _PlatformRefusal implements Exception {
  const _PlatformRefusal();
}

const String _tableMarkdown = '''
| Sortie | Distance | Dénivelé | Groupe |
|---|---|---|---|
| 🚴 Rando du dimanche | 82 km | 1 240 m | A |
| 🚵 Sortie gravel | 64 km | 980 m | B |
''';

/// Monte [markdown] dans un `MarkdownContent` — la façade, celle que les
/// écrans emploient — sous un `GoRouter` réel, sur une page étroite.
Future<GoRouter> _pumpMarkdown(
  WidgetTester tester,
  String markdown, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: SingleChildScrollView(child: MarkdownContent(data: markdown)),
        ),
      ),
      GoRoute(
        path: PathVariants.ride(':teamSlug', ':rideSlug')['fr']!,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('page de la sortie')),
      ),
      GoRoute(
        path: PathVariants.post(':teamSlug', ':postSlug')['fr']!,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('page de l\'article')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        theme: PedalonsTheme.build(Brightness.light),
      ),
    ),
  );
  // Une image de contenu ne se stabilise jamais : `CachedNetworkImage`
  // retente, et `pumpAndSettle` expirerait sur ce seul motif.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
  return router;
}

/// Tape le lien dont le libellé est [label], en visant son span.
Future<void> _tapLink(WidgetTester tester, String label) async {
  final Finder rich = find
      .byWidgetPredicate(
        (Widget w) => w is RichText && w.text.toPlainText().contains(label),
      )
      .first;
  _fireRecognizer(tester.widget<RichText>(rich).text, label);
  await tester.pumpAndSettle();
}

/// Déclenche le `TapGestureRecognizer` du span portant [label].
///
/// Taper aux coordonnées serait plus proche du geste réel, mais un lien
/// inline n'a pas de boîte propre : viser le span est la seule façon fiable
/// d'atteindre *ce* lien-là et pas son voisin.
void _fireRecognizer(InlineSpan root, String label) {
  InlineSpan? found;
  root.visitChildren((InlineSpan span) {
    if (found != null) return false;
    if (span is TextSpan && span.text == label) found = span;
    return true;
  });
  final TextSpan? span = found as TextSpan?;
  if (span == null) {
    fail('Aucun span « $label » dans « ${root.toPlainText()} »');
  }
  final GestureRecognizer? recognizer = span.recognizer;
  if (recognizer is! TapGestureRecognizer) {
    fail('Le lien « $label » est inerte : aucun TapGestureRecognizer.');
  }
  recognizer.onTap!();
}
