import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/ads/domain/ad_filters.dart';
import 'package:pedalons/features/ads/presentation/widgets/ads_toolbar.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

TagWithUsageDto _tag(String id, String label, TagTarget type) =>
    TagWithUsageDto(
      id: id,
      label: label,
      color: 'TEAL',
      type: type.json!,
      usageCount: 3,
    );

/// Ledger `MOB-39` — la chip « Tags » dans les listes d'équipe : présente
/// seulement quand l'équipe a des tags pour ce type, et jamais sur le fil
/// mixte (plan des tags, D13).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  /// Le vocabulaire servi par type ; un type absent n'a aucun tag.
  Override tagsFor(Map<TagTarget, List<TagWithUsageDto>> byType) =>
      teamTagsProvider.overrideWith(
        (ref, key) async => byType[key.type] ?? const <TagWithUsageDto>[],
      );

  group('annonces', () {
    Future<void> pumpToolbar(
      WidgetTester tester, {
      required Map<TagTarget, List<TagWithUsageDto>> tags,
      required ValueChanged<AdFilters> onChanged,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tagsFor(tags)],
          child: MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: Scaffold(
              body: AdsToolbar(
                filters: const AdFilters(teamSlug: 'n-peloton'),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('sans tag d\'annonce, pas de chip', (
      WidgetTester tester,
    ) async {
      await pumpToolbar(
        tester,
        tags: <TagTarget, List<TagWithUsageDto>>{
          // Des tags d'un autre type ne comptent pas.
          TagTarget.route: <TagWithUsageDto>[
            _tag('r1', 'Col', TagTarget.route),
          ],
        },
        onChanged: (_) {},
      );

      expect(find.byKey(keys.tags.filterChip), findsNothing);
    });

    testWidgets('avec des tags, la chip pose le filtre', (
      WidgetTester tester,
    ) async {
      AdFilters? next;
      await pumpToolbar(
        tester,
        tags: <TagTarget, List<TagWithUsageDto>>{
          TagTarget.ad: <TagWithUsageDto>[
            _tag('a1', 'Vélo enfant', TagTarget.ad),
            _tag('a2', 'Route', TagTarget.ad),
          ],
        },
        onChanged: (AdFilters f) => next = f,
      );

      // La chip est la dernière de la rangée : on l'amène à l'écran.
      await tester.ensureVisible(find.byKey(keys.tags.filterChip));
      await tester.tap(find.byKey(keys.tags.filterChip));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(keys.tags.pickerRow('a2')));
      await tester.pump();
      await tester.tap(find.byKey(keys.tags.pickerApply));
      await tester.pumpAndSettle();

      expect(next?.tagIds, <String>['a2']);
      expect(next?.isFiltered, isTrue);
    });
  });

  group('fil d\'équipe', () {
    late List<PublicationFeedKey> requested;

    setUp(() => requested = <PublicationFeedKey>[]);

    Future<void> pumpFeed(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagsFor(<TagTarget, List<TagWithUsageDto>>{
              TagTarget.ride: <TagWithUsageDto>[
                _tag('t1', 'Café', TagTarget.ride),
                _tag('t2', 'Nocturne', TagTarget.ride),
              ],
            }),
            publicationFeedProvider.overrideWith((ref, key) {
              requested.add(key);
              return _StuckFeedNotifier(key);
            }),
          ],
          child: MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: const Scaffold(
              body: PublicationFeedView(
                teamSlug: 'n-peloton',
                emptyMessage: 'empty',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('le fil mixte n\'a pas de filtre par tag', (
      WidgetTester tester,
    ) async {
      await pumpFeed(tester);

      expect(find.byKey(keys.tags.filterChip), findsNothing);
    });

    testWidgets('la liste des sorties filtre par tag, et changer de type '
        'lève les tags', (WidgetTester tester) async {
      await pumpFeed(tester);

      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.ride)));
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(find.byKey(keys.tags.filterChip));
      await tester.tap(find.byKey(keys.tags.filterChip));
      // Les squelettes du fil s'animent sans fin : pas de `pumpAndSettle`.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(keys.tags.pickerRow('t2')));
      await tester.tap(find.byKey(keys.tags.pickerRow('t1')));
      await tester.pump();
      await tester.tap(find.byKey(keys.tags.pickerApply));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(requested.last.type, PublicationType.ride);
      expect(requested.last.tags, 't1,t2');

      // Les publications n'ont pas de tag ici : la chip disparaît, et les
      // tags de sortie ne suivent pas.
      await tester.ensureVisible(
        find.byKey(keys.feed.typeChip(PublicationType.post)),
      );
      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.post)));
      await tester.pump();
      await tester.pump();

      expect(requested.last.type, PublicationType.post);
      expect(requested.last.tags, isNull);
      expect(find.byKey(keys.tags.filterChip), findsNothing);
    });
  });

  test('feedTagsKey : seulement sur une liste dédiée d\'équipe', () {
    const List<String> ids = <String>['a', 'b'];
    expect(
      feedTagsKey(teamSlug: 't', type: PublicationType.ride, tagIds: ids),
      'a,b',
    );
    expect(feedTagsKey(teamSlug: 't', type: null, tagIds: ids), isNull);
    expect(
      feedTagsKey(teamSlug: null, type: PublicationType.ride, tagIds: ids),
      isNull,
    );
    expect(
      feedTagsKey(
        teamSlug: 't',
        type: PublicationType.ride,
        tagIds: const <String>[],
      ),
      isNull,
    );
  });
}

/// Ne répond jamais : aucun appel HTTP, le fil reste sur ses squelettes.
class _StuckFeedNotifier extends PublicationFeedNotifier {
  _StuckFeedNotifier(PublicationFeedKey key)
    : super(PublicationsClient(Dio()), key);

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) =>
      Completer<PageResult<PublicationDto>>().future;
}
