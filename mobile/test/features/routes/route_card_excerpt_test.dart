import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/features/routes/presentation/widgets/compact_route_row.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_card.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// Règle R12 (KIT §9, docs/LEDGER_*.md MOB-139) : la carte de parcours en
/// densité « vignettes » montre l'extrait sur deux lignes, sous le nom ; la
/// ligne compacte, non.
void main() {
  setUpAll(loadTestTranslations);

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSystemProvider.overrideWithValue(UnitSystem.metric)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  final GalleryData d = GalleryData(images: false);

  testWidgets('vignettes : l’extrait sur deux lignes, sous le nom', (
    WidgetTester tester,
  ) async {
    final RouteDto route = d.route();
    await pump(tester, RouteCard(route: route));

    final Finder excerpt = find.byKey(keys.routes.cardExcerpt(route.slug));
    final Text text = tester.widget<Text>(excerpt);
    expect(text.data, route.excerpt);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(
      tester.getTopLeft(excerpt).dy,
      greaterThan(tester.getTopLeft(find.text(route.name)).dy),
    );
  });

  testWidgets('sans extrait, rien n’est réservé', (WidgetTester tester) async {
    final RouteDto route = d.route().copyWith(excerpt: null);
    await pump(tester, RouteCard(route: route));
    expect(find.byKey(keys.routes.cardExcerpt(route.slug)), findsNothing);
  });

  testWidgets('la ligne compacte ne porte pas l’extrait', (
    WidgetTester tester,
  ) async {
    final RouteDto route = d.route();
    await pump(tester, CompactRouteRow(route: route));
    expect(find.text(route.excerpt!), findsNothing);
  });
}
