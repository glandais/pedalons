import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/models/asset_dto.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/widgets/authenticated_image.dart';
import 'package:pedalons/core/widgets/markdown_content.dart';

import '../../support/localization.dart';

/// Les directives `::asset{…}` du markdown, jusqu'à l'image affichée.
///
/// Quatre écrans — sortie, parcours, séjour, étape — rendaient leur
/// description avec `PdlMarkdownBody` nu, qui ne résout aucune directive : la
/// page d'une sortie montrait le texte `::asset{id="…"}` là où l'auteur avait
/// posé une image. Ce test tient la façade, seule à savoir les résoudre.
void main() {
  setUpAll(loadTestTranslations);

  AssetDto asset({required String id, String? imageUrl}) => AssetDto(
    id: id,
    fileName: 'photo.jpg',
    contentType: 'image/jpeg',
    url: '/api/download/team/$id',
    imageUrl: imageUrl,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('une directive devient une image, et non son texte brut', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      MarkdownContent(
        data: 'Avant\n\n::asset{id="a1" size="medium" alt="Le col"}\n\nAprès',
        images: <AssetDto>[
          asset(id: 'a1', imageUrl: '/api/images/a1/{size}.webp'),
        ],
      ),
    );

    expect(find.textContaining('::asset'), findsNothing);
    expect(find.byType(AuthenticatedImage), findsOneWidget);
  });

  testWidgets(
    'le gabarit {size} survit au markdown et se résout à l\'affichage',
    (WidgetTester tester) async {
      await pump(
        tester,
        MarkdownContent(
          data: '::asset{id="a1" size="icon" alt=""}',
          images: <AssetDto>[
            asset(id: 'a1', imageUrl: '/api/images/a1/{size}.webp'),
          ],
        ),
      );

      // Le gabarit doit arriver **intact** jusqu'au widget d'image : c'est lui
      // qui permet à la visionneuse plein écran de redemander la variante 1920.
      // Figé à la largeur rédigée, le plein écran reservait l'ignoble 32 px de
      // `size="icon"` étiré sur toute la dalle.
      final AuthenticatedImage image = tester.widget<AuthenticatedImage>(
        find.byType(AuthenticatedImage),
      );
      // `markdown_widget` encode les accolades : c'est cette forme-là qui
      // arrive au widget, et c'est `resolveImageUrl` qui doit la reconnaître.
      expect(image.imageUrl, contains('size'));
      expect(image.imageUrl, isNot(contains('448')));
      expect(
        resolveImageUrl(image.imageUrl, size: 1920),
        contains('/1920.webp'),
      );
      expect(resolveImageUrl(image.imageUrl), isNot(contains('size')));
    },
  );

  testWidgets('un asset introuvable laisse son texte de remplacement', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      MarkdownContent(
        data: '::asset{id="disparu" alt="Photo du départ"}',
        images: <AssetDto>[asset(id: 'a1')],
      ),
    );

    expect(find.textContaining('Photo du départ'), findsOneWidget);
    expect(find.byType(AuthenticatedImage), findsNothing);
  });
}
