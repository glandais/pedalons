import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../domain/ad_filters.dart';

final adRepositoryProvider = Provider<AdRepository>((ref) {
  return AdRepository(ref.watch(adsClientProvider));
});

class AdRepository {
  final AdsClient _adsClient;

  AdRepository(this._adsClient);

  Future<AdDto> getAd(String teamSlug, String adSlug) {
    return _adsClient.getAd(teamSlug: teamSlug, slug: adSlug);
  }

  /// One page of ads, filtered and sorted.
  ///
  /// `page` et `size` sont **toujours** transmis : c'est le défaut central de
  /// S32-2 — l'ancien appel les omettait et la liste s'arrêtait en silence à
  /// la première page du serveur.
  Future<PageResult<AdDto>> fetchAds({
    required AdFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
    ListViewMode? view,
  }) async {
    final String? search = filters.search?.trim();
    final AdListResponse response = await _adsClient.listAds(
      teamSlug: filters.teamSlug,
      page: page,
      size: size,
      adType: filters.adType,
      search: search == null || search.isEmpty ? null : search,
      sortBy: filters.sortBy,
      sortDir: filters.sortDir,
      tags: filters.tagIds.isEmpty ? null : filters.tagIds,
      minPrice: filters.minPrice,
      maxPrice: filters.maxPrice,
      view: view,
    );
    return PageResult<AdDto>(items: response.ads, total: response.total);
  }

  /// Combien d'annonces répondent à [filters] — le bouton « Voir N annonces »
  /// de la feuille de prix.
  Future<int> countAds(AdFilters filters) async {
    final String? search = filters.search?.trim();
    final CountResponse response = await _adsClient.countAds(
      teamSlug: filters.teamSlug,
      adType: filters.adType,
      search: search == null || search.isEmpty ? null : search,
      tags: filters.tagIds.isEmpty ? null : filters.tagIds,
      minPrice: filters.minPrice,
      maxPrice: filters.maxPrice,
    );
    return response.total;
  }

  /// Relais d'un message vers l'auteur d'une annonce.
  ///
  /// Rend `void` sur un **204**, et laisse remonter la `DioException` sur les
  /// trois autres issues (`AD_CONTACT_OPTED_OUT`, `AD_CONTACT_RATE_LIMITED`,
  /// `AD_CONTACT_DELIVERY_FAILED`) : c'est l'écran qui les distingue, et il
  /// n'existe **aucun repli optimiste** — un relais qui avale le message est
  /// pire qu'un relais qui échoue.
  Future<void> contactSeller({
    required String teamSlug,
    required String adSlug,
    required String message,
  }) {
    return _adsClient.contactAdAuthor(
      teamSlug: teamSlug,
      slug: adSlug,
      body: AdContactRequest(message: message),
    );
  }
}
