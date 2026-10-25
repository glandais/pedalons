import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/features/ads/data/ad_repository.dart';
import 'package:pedalons/features/ads/domain/ad_filters.dart';
import 'package:pedalons/features/ads/presentation/widgets/ad_sort_sheet.dart';
import 'package:pedalons/features/ads/providers/ad_list_provider.dart';

import 'ad_fixtures.dart';

/// S32-2 et S32-3 — la liste d'annonces ne tronque plus en silence.
///
/// Le défaut corrigé est nommément l'appel `listAds` **sans `page` ni `size`**
/// de l'ancien `ads_page.dart:19` : le mobile affichait la première page du
/// serveur et s'arrêtait là, sans jamais dire combien d'annonces restaient.
class _RecordingAdsClient implements AdsClient {
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  /// Total annoncé par le serveur, indépendant du nombre d'éléments rendus.
  int total = 57;

  @override
  Future<AdListResponse> listAds({
    required String teamSlug,
    int? page = 0,
    int? size = 20,
    AdType? adType,
    String? from,
    num? maxPrice,
    num? minPrice,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    String? search,
    AdSortBy? sortBy,
    SortDirection? sortDir,
    List<String>? tags,
    String? to,
    ListViewMode? view,
  }) async {
    calls.add(<String, Object?>{
      'teamSlug': teamSlug,
      'page': page,
      'size': size,
      'adType': adType,
      'search': search,
      'sortBy': sortBy,
      'sortDir': sortDir,
      'view': view,
    });
    final int offset = (page ?? 0) * (size ?? 20);
    final int remaining = (total - offset).clamp(0, size ?? 20);
    return AdListResponse(
      ads: fixtureAds(remaining, from: offset),
      total: total,
      page: page ?? 0,
      size: size ?? 20,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const AdFilters base = AdFilters(teamSlug: 'n-peloton');

  group('AdRepository.fetchAds', () {
    test('transmet toujours page et size, plus les filtres', () async {
      final _RecordingAdsClient client = _RecordingAdsClient();
      final AdRepository repository = AdRepository(client);

      await repository.fetchAds(
        filters: base.copyWith(search: 'gravel', adType: AdType.rental),
        page: 2,
        size: 20,
        view: ListViewMode.compact,
      );

      expect(client.calls.single, <String, Object?>{
        'teamSlug': 'n-peloton',
        'page': 2,
        'size': 20,
        'adType': AdType.rental,
        'search': 'gravel',
        'sortBy': AdSortBy.dateTime,
        'sortDir': SortDirection.desc,
        'view': ListViewMode.compact,
      });
    });

    test('une recherche blanche ne part pas comme filtre', () async {
      final _RecordingAdsClient client = _RecordingAdsClient();
      await AdRepository(client)
          .fetchAds(filters: base.copyWith(search: '   '));
      expect(client.calls.single['search'], isNull);
    });

    test('rend le total du serveur, pas la taille de la page', () async {
      final _RecordingAdsClient client = _RecordingAdsClient()..total = 57;
      final PageResult<AdDto> page = await AdRepository(client)
          .fetchAds(filters: base);
      expect(page.items, hasLength(20));
      expect(page.total, 57);
    });
  });

  group('adListProvider', () {
    ProviderContainer boot(AdsClient client) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          adRepositoryProvider.overrideWithValue(AdRepository(client)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('enchaîne les pages et connaît ce qui reste', () async {
      final _RecordingAdsClient client = _RecordingAdsClient()..total = 57;
      final ProviderContainer container = boot(client);

      // La famille est `autoDispose` : sans abonnement, chaque lecture
      // construirait — et jetterait — un notifier neuf.
      container.listen(adListProvider(base), (_, _) {});
      final AdListNotifier notifier = container.read(
        adListProvider(base).notifier,
      );
      await pumpEventQueue();
      expect(container.read(adListProvider(base)).items, hasLength(20));
      expect(container.read(adListProvider(base)).total, 57);
      expect(container.read(adListProvider(base)).hasMore, isTrue);

      await notifier.loadNextPage();
      await notifier.loadNextPage();
      final PagedListState<AdDto> state = container.read(adListProvider(base));
      expect(state.items, hasLength(57));
      expect(state.hasMore, isFalse);
      expect(client.calls.map((Map<String, Object?> c) => c['page']), <int>[
        0,
        1,
        2,
      ]);
    });

    test('changer un filtre crée un notifier neuf', () async {
      final _RecordingAdsClient client = _RecordingAdsClient();
      final ProviderContainer container = boot(client);

      final AdListNotifier first = container.read(
        adListProvider(base).notifier,
      );
      final AdListNotifier second = container.read(
        adListProvider(base.copyWith(adType: AdType.wanted)).notifier,
      );
      expect(identical(first, second), isFalse);

      // Et le tri en fait partie : il change l'ordre, donc la page 0.
      final AdListNotifier third = container.read(
        adListProvider(base.copyWith(sortBy: AdSortBy.price)).notifier,
      );
      expect(identical(first, third), isFalse);
    });
  });

  group('AdFilters', () {
    test('le tri ne compte pas comme un filtre', () {
      expect(base.copyWith(sortBy: AdSortBy.name).isFiltered, isFalse);
      expect(base.copyWith(search: 'x').isFiltered, isTrue);
      expect(base.copyWith(adType: AdType.sale).isFiltered, isTrue);
    });

    test('« Tout réinitialiser » lève les filtres et garde le tri', () {
      final AdFilters dirty = base.copyWith(
        search: 'gravel',
        adType: AdType.sale,
        sortBy: AdSortBy.price,
        sortDir: SortDirection.asc,
      );
      expect(dirty.cleared.isFiltered, isFalse);
      expect(dirty.cleared.sortBy, AdSortBy.price);
      expect(dirty.cleared.sortDir, SortDirection.asc);
    });
  });

  group('AdSortOption', () {
    test(
      'chaque couple colonne/sens a son option, défaut « plus récentes »',
      () {
        for (final AdSortOption option in AdSortOption.values) {
          expect(
            AdSortOption.of(
              base.copyWith(sortBy: option.sortBy, sortDir: option.sortDir),
            ),
            option,
          );
        }
        expect(AdSortOption.of(base), AdSortOption.newest);
      },
    );
  });
}
