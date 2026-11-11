import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/zone_mention_line.dart';
import 'package:pedalons/features/posts/data/post_repository.dart';
import 'package:pedalons/features/posts/domain/post_neighbours.dart';
import 'package:pedalons/features/posts/presentation/pages/post_detail_page.dart';

import '../../support/localization.dart';
import '../../support/content_permissions.dart';

/// S31-1 à S31-3 — l'écran d'une publication.
///
/// Ce qui compte ici est autant ce qui est rendu que **ce qui ne l'est pas** :
/// l'auteur seulement quand le contrat le nomme (ledger `API-6` : une
/// publication signée par l'équipe le tait aux lecteurs), et aucun bloc de
/// navigation en ouverture froide.
const TeamPublicationDto _team = TeamPublicationDto(
  accessible: true,
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  visibility: 'PUBLIC',
);

PostDto _post({
  String slug = 'sortie-du-dimanche',
  String name = 'Le compte rendu',
  String markdown = 'Un corps de publication.',
  List<AssetDto> attachments = const <AssetDto>[],
  int? commentCount = 0,
  TeamPublicationDto team = _team,
  bool signedAsTeam = true,
  PublicUserDto? createdBy,
  String timezone = 'Europe/Paris',
}) => PostDto(
  permissions: kNoPermissions,
  timezone: timezone,
  tags: const [],
  type: 'POST',
  team: team,
  id: 'p-$slug',
  slug: slug,
  name: name,
  media: MediaDto(
    markdown: markdown,
    assets: AssetsDto(images: const <AssetDto>[], attachments: attachments),
  ),
  dateTime: '2026-05-03T09:00:00Z',
  status: 'PUBLISHED',
  visibility: 'TEAM',
  deleted: false,
  commentCount: commentCount,
  signedAsTeam: signedAsTeam,
  createdBy: createdBy,
);

class _StubPostRepository implements PostRepository {
  _StubPostRepository(this.post);

  final PostDto post;

  @override
  Future<PostDto> getPost(String teamSlug, String postSlug) async => post;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> openPost(
    WidgetTester tester,
    PostDto post, {
    PostNeighbours? neighbours,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postRepositoryProvider.overrideWithValue(_StubPostRepository(post)),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: PostDetailPage(
            teamSlug: post.team.slug,
            postSlug: post.slug,
            neighbours: neighbours,
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets(
    'signée par l\'équipe : le titre, la date et l\'équipe, sans auteur',
    (WidgetTester tester) async {
      await openPost(tester, _post());

      expect(find.text('Le compte rendu'), findsOneWidget);
      expect(find.text('N-Peloton'), findsOneWidget);
      expect(find.textContaining('3 mai'), findsOneWidget);
      // `createdBy` nul : la ligne d'équipe signe, rien n'invente un auteur.
      expect(find.byType(PdlPersonRow), findsNothing);
    },
  );

  // docs/LEDGER_*.md API-60 : la date d'une publication est un rendez-vous,
  // lu dans son fuseau, avec l'heure et la mention — la règle du web.
  group('lue d\'un autre fuseau', () {
    setUp(() => AppFormatters.setDisplayTimezone('Europe/Paris'));
    tearDown(() => AppFormatters.setDisplayTimezone(null));

    testWidgets('date et heure de Tokyo, puis la mention', (
      WidgetTester tester,
    ) async {
      await openPost(tester, _post(timezone: 'Asia/Tokyo'));

      expect(find.textContaining('3 mai à 18:00'), findsOneWidget);
      expect(find.byType(ZoneMentionLine), findsOneWidget);
      expect(find.textContaining('heure de Tokyo'), findsOneWidget);
    });

    testWidgets('au décalage du lecteur, ni mention ni icône', (
      WidgetTester tester,
    ) async {
      await openPost(tester, _post());

      expect(find.textContaining('3 mai à 11:00'), findsOneWidget);
      expect(find.byType(ZoneMentionLine), findsNothing);
    });
  });

  testWidgets('signée par son auteur : avatar, nom et date', (
    WidgetTester tester,
  ) async {
    await openPost(
      tester,
      _post(
        signedAsTeam: false,
        createdBy: const PublicUserDto(id: 'u1', displayName: 'Camille Martin'),
      ),
    );

    final PdlPersonRow row = tester.widget<PdlPersonRow>(
      find.byType(PdlPersonRow),
    );
    expect(row.name, 'Camille Martin');
    expect(row.subtitle, contains('3 mai'));
    expect(row.subtitle, isNot(contains('Au nom de l\'équipe')));
  });

  testWidgets('un administrateur voit l\'auteur, et que l\'équipe signe', (
    WidgetTester tester,
  ) async {
    await openPost(
      tester,
      _post(
        createdBy: const PublicUserDto(id: 'u1', displayName: 'Camille Martin'),
      ),
    );

    final PdlPersonRow row = tester.widget<PdlPersonRow>(
      find.byType(PdlPersonRow),
    );
    expect(row.name, 'Camille Martin');
    expect(row.subtitle, contains('Au nom de l\'équipe'));
  });

  testWidgets('la ligne d\'équipe porte le logo, les initiales sans logo', (
    WidgetTester tester,
  ) async {
    await openPost(tester, _post());
    expect(
      tester.widget<PdlTeamLine>(find.byType(PdlTeamLine)).imageUrl,
      isNull,
    );

    const String logo = '/api/download/public/images/n-peloton/l1/{size}';
    await openPost(
      tester,
      _post(
        team: const TeamPublicationDto(
          accessible: true,
          id: 't1',
          slug: 'n-peloton',
          name: 'N-Peloton',
          visibility: 'PUBLIC',
          logoUrl: logo,
        ),
      ),
    );
    expect(tester.widget<PdlTeamLine>(find.byType(PdlTeamLine)).imageUrl, logo);
  });

  testWidgets('une pièce jointe nomme son fichier dans son action', (
    WidgetTester tester,
  ) async {
    await openPost(
      tester,
      _post(
        attachments: const <AssetDto>[
          AssetDto(
            id: 'a1',
            fileName: 'compte-rendu.pdf',
            contentType: 'application/pdf',
            url: 'https://example.org/a1',
          ),
        ],
      ),
    );

    expect(find.text('Pièces jointes'), findsOneWidget);
    expect(find.text('compte-rendu.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    // Pas de « PDF · 240 Ko » : `AssetDto` ne porte pas d'octets.
    expect(find.textContaining('Ko'), findsNothing);

    final PdlAttachmentRow row = tester.widget<PdlAttachmentRow>(
      find.byType(PdlAttachmentRow),
    );
    expect(row.actionSemanticLabel, contains('compte-rendu.pdf'));
  });

  testWidgets('sans voisins, aucun bloc de navigation et aucun vide', (
    WidgetTester tester,
  ) async {
    await openPost(tester, _post());

    // Ni bloc, ni filet, ni espace : le composant rend `SizedBox.shrink()`
    // quand il n'a aucun voisin, plutôt qu'un bloc désactivé qui donnerait à
    // croire à un chargement.
    expect(find.text('Publication précédente'), findsNothing);
    expect(find.text('Publication suivante'), findsNothing);
    for (final PdlPrevNextNav nav in tester.widgetList<PdlPrevNextNav>(
      find.byType(PdlPrevNextNav),
    )) {
      expect(nav.isEmpty, isTrue);
    }
  });

  testWidgets('ouverte depuis un fil, elle connaît ses deux voisins', (
    WidgetTester tester,
  ) async {
    await openPost(
      tester,
      _post(slug: 'b', name: 'B'),
      neighbours: const PostNeighbours(
        posts: <PostNeighbour>[
          PostNeighbour(slug: 'a', name: 'A'),
          PostNeighbour(slug: 'b', name: 'B'),
          PostNeighbour(slug: 'c', name: 'C'),
        ],
        index: 1,
      ),
    );

    expect(find.text('Publication précédente'), findsOneWidget);
    expect(find.text('Publication suivante'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('les commentaires sont réservés aux membres', (
    WidgetTester tester,
  ) async {
    // `commentCount` nul = pas le droit de lire : le fil ne se monte pas, un
    // bandeau explique.
    await openPost(tester, _post(commentCount: null));

    expect(find.textContaining('réservés aux membres'), findsOneWidget);
    expect(find.text('Voir l\'équipe'), findsOneWidget);
  });

  testWidgets('équipe non consultable : ni lien vers elle, ni « Voir '
      'l\'équipe » (MOB-137)', (WidgetTester tester) async {
    await openPost(
      tester,
      _post(
        commentCount: null,
        team: _team.copyWith(accessible: false, visibility: 'TEAM'),
      ),
    );

    expect(
      find.textContaining('membres de cette équipe privée'),
      findsOneWidget,
    );
    expect(find.text('Voir l\'équipe'), findsNothing);
    expect(tester.widget<PdlTeamLine>(find.byType(PdlTeamLine)).onTap, isNull);
  });

  testWidgets('le mode sombre rend le même écran', (WidgetTester tester) async {
    await openPost(tester, _post(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Le compte rendu'), findsOneWidget);
  });

  group('PostNeighbours', () {
    const PostNeighbours position = PostNeighbours(
      posts: <PostNeighbour>[
        PostNeighbour(slug: 'a', name: 'A'),
        PostNeighbour(slug: 'b', name: 'B'),
        PostNeighbour(slug: 'c', name: 'C'),
      ],
      index: 1,
    );

    test('les bords du fil n\'ont qu\'un voisin', () {
      expect(position.movedTo('a')!.previous, isNull);
      expect(position.movedTo('a')!.next?.slug, 'b');
      expect(position.movedTo('c')!.next, isNull);
    });

    test('passer au voisin recentre la liste sur lui', () {
      final PostNeighbours moved = position.movedTo('c')!;
      expect(moved.index, 2);
      expect(moved.previous?.slug, 'b');
    });

    test('un slug étranger au fil ne rend rien', () {
      expect(position.movedTo('inconnu'), isNull);
    });
  });
}
