import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import 'paged_list_state.dart';

/// Default number of items requested per page.
const int kDefaultPageSize = 20;

/// How many items before the end of the list trigger the next page.
///
/// The design asks for the next page to start loading while about three cards
/// are still below the fold, not at the very last pixel.
const int kPrefetchDistance = 3;

/// Base class for a list that loads itself page by page.
///
/// Subclasses only implement [fetchPage]. Everything else — a single request
/// in flight at a time, discarding responses that belong to an abandoned
/// query, keeping loaded items on screen when a page fails — is handled here.
///
/// The set of results is identified by the provider family key (the filters),
/// so changing a filter builds a *new* notifier rather than merging into this
/// one. That is what keeps a filter change from mixing two result sets.
abstract class PagedListNotifier<T> extends StateNotifier<PagedListState<T>> {
  PagedListNotifier({this.pageSize = kDefaultPageSize})
    : super(PagedListState<T>()) {
    unawaited(loadFirstPage());
  }

  final int pageSize;

  bool _requestInFlight = false;

  /// Bumped whenever the list is reset, so a response from before the reset
  /// can be recognised as stale and dropped.
  int _generation = 0;

  /// Fetch [page] (0-indexed) with this notifier's filters applied.
  Future<PageResult<T>> fetchPage(int page);

  /// Stable identity of an item, used to drop duplicates when appending.
  ///
  /// The API paginates by offset, so a route created (or re-sorted) between
  /// two requests can show up on two consecutive pages. Returning a key here
  /// keeps such an item from being rendered twice. Return null to skip the
  /// check.
  Object? itemKey(T item) => null;

  /// Load page 0, replacing whatever is in the list.
  ///
  /// When [refreshing] is true the current items stay on screen while the
  /// request is in flight — the [RefreshIndicator] is the progress feedback.
  Future<void> loadFirstPage({bool refreshing = false}) async {
    final generation = ++_generation;
    _requestInFlight = true;

    state = state.copyWith(
      isLoadingInitial: !refreshing,
      isRefreshing: refreshing,
      initialError: null,
      nextError: null,
    );

    try {
      final (result, pages) = await _fetchFrom(0, generation);
      if (!mounted || generation != _generation) return;
      state = PagedListState<T>(
        items: result.items,
        total: result.total,
        loadedPages: pages,
        firstSectionTotal: result.firstSectionTotal,
        firstSectionLoaded: _inFirstSection(
          result,
          pages - 1,
          List<int>.generate(result.items.length, (int i) => i),
        ),
        hasMore: _hasMoreAfter(pages, result),
        isLoadingInitial: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      // A failed refresh must not wipe a list the user is already reading:
      // it degrades to a footer error instead.
      final keepsItems = refreshing && state.items.isNotEmpty;
      state = state.copyWith(
        isLoadingInitial: false,
        isRefreshing: false,
        initialError: keepsItems ? null : error,
        nextError: keepsItems ? error : null,
      );
    } finally {
      if (generation == _generation) _requestInFlight = false;
    }
  }

  /// Load the page after the last one loaded.
  ///
  /// No-op while another request is in flight, once the end is reached, or
  /// while a footer error is showing — in that last case the user has to tap
  /// retry, otherwise scrolling would hammer a failing endpoint.
  Future<void> loadNextPage() async {
    final current = state;
    if (_requestInFlight ||
        !current.hasMore ||
        current.isLoadingInitial ||
        current.nextError != null) {
      return;
    }

    final generation = _generation;
    _requestInFlight = true;
    state = current.copyWith(isLoadingNext: true, nextError: null);

    try {
      final (result, pages) = await _fetchFrom(current.loadedPages, generation);
      if (!mounted || generation != _generation) return;
      final loadedPages = state.loadedPages + pages;
      final List<int> kept = _keptIndexes(state.items, result.items);
      state = state.copyWith(
        items: <T>[...state.items, for (final int i in kept) result.items[i]],
        total: result.total,
        loadedPages: loadedPages,
        firstSectionTotal: result.firstSectionTotal,
        firstSectionLoaded:
            state.firstSectionLoaded +
            _inFirstSection(result, loadedPages - 1, kept),
        hasMore: _hasMoreAfter(loadedPages, result),
        isLoadingNext: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoadingNext: false, nextError: error);
    } finally {
      if (generation == _generation) _requestInFlight = false;
    }
  }

  /// Retry the page that just failed, from the footer.
  Future<void> retryNextPage() async {
    if (state.nextError == null) return;
    state = state.copyWith(nextError: null);
    await loadNextPage();
  }

  /// Pull-to-refresh: drop everything and reload from page 0.
  Future<void> refresh() => loadFirstPage(refreshing: true);

  /// Called from the item builder to start the next page early.
  ///
  /// The load is deferred to a microtask because the builder runs during
  /// `build`, where mutating provider state is not allowed.
  void onItemBuilt(int index) {
    final current = state;
    if (index < current.items.length - kPrefetchDistance) return;
    if (!current.hasMore ||
        current.isLoadingNext ||
        current.nextError != null) {
      return;
    }
    scheduleMicrotask(loadNextPage);
  }

  /// Fetch [page], then the pages after it for as long as they come back
  /// empty and the total says more remain.
  ///
  /// The server may filter a page after cutting it — the comments of a member
  /// the reader blocked, for one — so an empty page is not the end of the
  /// list, and stopping there would hide every page after it. Returns the
  /// last page fetched and how many pages were consumed.
  Future<(PageResult<T>, int)> _fetchFrom(int page, int generation) async {
    var next = page;
    while (true) {
      final result = await fetchPage(next++);
      final stale = !mounted || generation != _generation;
      if (stale || result.items.isNotEmpty || !_hasMoreAfter(next, result)) {
        return (result, next - page);
      }
    }
  }

  /// Whether pages remain after the first [loadedPages], counted in pages
  /// rather than items: the items shown can fall short of the total when the
  /// server filters a page, or when [_keptIndexes] drops a duplicate.
  bool _hasMoreAfter(int loadedPages, PageResult<T> result) =>
      loadedPages * pageSize < result.total;

  /// The indexes of [incoming] to append: those whose [itemKey] is not
  /// already on screen.
  List<int> _keptIndexes(List<T> existing, List<T> incoming) {
    final seen = <Object>{};
    for (final item in existing) {
      final key = itemKey(item);
      if (key != null) seen.add(key);
    }
    return <int>[
      for (int i = 0; i < incoming.length; i++)
        if (seen.isEmpty || _isNew(incoming[i], seen)) i,
    ];
  }

  bool _isNew(T item, Set<Object> seen) {
    final key = itemKey(item);
    return key == null || seen.add(key);
  }

  /// How many of the rows [kept] (indexes into the page [pageIndex]) belong
  /// to the first section: their position in the whole list, `pageIndex *
  /// pageSize + i`, is below [PageResult.firstSectionTotal].
  int _inFirstSection(PageResult<T> result, int pageIndex, List<int> kept) {
    final int? first = result.firstSectionTotal;
    if (first == null) return 0;
    return kept.where((int i) => pageIndex * pageSize + i < first).length;
  }
}
