import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pagination/pagination.dart';

/// A notifier whose pages are handed to it by the test.
class _FakeNotifier extends PagedListNotifier<String> {
  _FakeNotifier(this.responder, {super.pageSize = 3});

  final Future<PageResult<String>> Function(int page) responder;
  final List<int> requestedPages = [];

  @override
  Future<PageResult<String>> fetchPage(int page) {
    requestedPages.add(page);
    return responder(page);
  }

  @override
  Object? itemKey(String item) => item;
}

PageResult<String> _page(List<String> items, int total) =>
    PageResult(items: items, total: total);

void main() {
  group('PagedListNotifier', () {
    test('loads the first page on creation', () async {
      final notifier = _FakeNotifier((page) async => _page(['a', 'b', 'c'], 6));
      await pumpEventQueue();

      expect(notifier.requestedPages, [0]);
      expect(notifier.state.items, ['a', 'b', 'c']);
      expect(notifier.state.total, 6);
      expect(notifier.state.isLoadingInitial, isFalse);
      expect(notifier.state.hasMore, isTrue);
    });

    test('appends the next page and stops at the total', () async {
      final notifier = _FakeNotifier(
        (page) async =>
            page == 0 ? _page(['a', 'b', 'c'], 5) : _page(['d', 'e'], 5),
      );
      await pumpEventQueue();

      await notifier.loadNextPage();

      expect(notifier.requestedPages, [0, 1]);
      expect(notifier.state.items, ['a', 'b', 'c', 'd', 'e']);
      expect(notifier.state.hasMore, isFalse);
      expect(notifier.state.isLoadingNext, isFalse);
    });

    test('drops items already loaded, so an offset shift cannot duplicate '
        'them', () async {
      final notifier = _FakeNotifier(
        (page) async =>
            page == 0 ? _page(['a', 'b', 'c'], 9) : _page(['c', 'd'], 9),
      );
      await pumpEventQueue();

      await notifier.loadNextPage();

      expect(notifier.state.items, ['a', 'b', 'c', 'd']);
    });

    test('the end is where the pages cover the total, however few items '
        'came back', () async {
      final notifier = _FakeNotifier(
        (page) async => page == 0 ? _page(['a'], 6) : _page(['d'], 6),
      );
      await pumpEventQueue();
      expect(notifier.state.hasMore, isTrue);

      await notifier.loadNextPage();

      expect(notifier.requestedPages, [0, 1]);
      expect(notifier.state.items, ['a', 'd']);
      expect(notifier.state.hasMore, isFalse);
    });

    test('a page the server filtered down to nothing is skipped, not taken '
        'as the end', () async {
      final notifier = _FakeNotifier(
        (page) async => switch (page) {
          0 || 1 => _page([], 9),
          _ => _page(['g', 'h'], 9),
        },
      );
      await pumpEventQueue();

      expect(notifier.requestedPages, [0, 1, 2]);
      expect(notifier.state.items, ['g', 'h']);
      expect(notifier.state.loadedPages, 3);
      expect(notifier.state.hasMore, isFalse);
    });

    test('empty pages stop at the total', () async {
      final notifier = _FakeNotifier((page) async => _page([], 7));
      await pumpEventQueue();

      expect(notifier.requestedPages, [0, 1, 2]);
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.hasMore, isFalse);
    });

    test('a next-page failure keeps the loaded items and only fills '
        'nextError', () async {
      final notifier = _FakeNotifier((page) async {
        if (page == 0) return _page(['a', 'b', 'c'], 9);
        throw StateError('offline');
      });
      await pumpEventQueue();

      await notifier.loadNextPage();

      expect(notifier.state.items, ['a', 'b', 'c']);
      expect(notifier.state.nextError, isA<StateError>());
      expect(notifier.state.initialError, isNull);
    });

    test('scrolling does not retry a failed page; the retry does', () async {
      var failNext = true;
      final notifier = _FakeNotifier((page) async {
        if (page == 0) return _page(['a', 'b', 'c'], 9);
        if (failNext) throw StateError('offline');
        return _page(['d', 'e', 'f'], 9);
      });
      await pumpEventQueue();
      await notifier.loadNextPage();
      expect(notifier.requestedPages, [0, 1]);

      // Further scrolling must not hammer the failing endpoint.
      notifier.onItemBuilt(2);
      await notifier.loadNextPage();
      await pumpEventQueue();
      expect(notifier.requestedPages, [0, 1]);

      failNext = false;
      await notifier.retryNextPage();

      expect(notifier.requestedPages, [0, 1, 1]);
      expect(notifier.state.items, ['a', 'b', 'c', 'd', 'e', 'f']);
      expect(notifier.state.nextError, isNull);
    });

    test('a first-page failure surfaces as initialError', () async {
      final notifier = _FakeNotifier((page) async => throw StateError('boom'));
      await pumpEventQueue();

      expect(notifier.state.initialError, isA<StateError>());
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.isLoadingInitial, isFalse);
    });

    test('a failed refresh keeps the list on screen', () async {
      var fail = false;
      final notifier = _FakeNotifier((page) async {
        if (fail) throw StateError('offline');
        return _page(['a', 'b', 'c'], 9);
      });
      await pumpEventQueue();

      fail = true;
      await notifier.refresh();

      expect(notifier.state.items, ['a', 'b', 'c']);
      expect(notifier.state.initialError, isNull);
      expect(notifier.state.nextError, isA<StateError>());
    });

    test('only one request is in flight at a time', () async {
      final completers = <int, Completer<PageResult<String>>>{};
      final notifier = _FakeNotifier((page) {
        return (completers[page] ??= Completer<PageResult<String>>()).future;
      });
      await pumpEventQueue();

      // The first page has not landed yet: asking for the next one is a no-op.
      unawaited(notifier.loadNextPage());
      await pumpEventQueue();
      expect(notifier.requestedPages, [0]);

      completers[0]!.complete(_page(['a', 'b', 'c'], 9));
      await pumpEventQueue();

      unawaited(notifier.loadNextPage());
      unawaited(notifier.loadNextPage());
      await pumpEventQueue();
      expect(notifier.requestedPages, [0, 1]);
    });

    test('a response from before a refresh is discarded', () async {
      final completers = <int, Completer<PageResult<String>>>{};
      var attempt = 0;
      final notifier = _FakeNotifier((page) {
        return (completers[attempt++] ??= Completer<PageResult<String>>())
            .future;
      });
      await pumpEventQueue();

      // Refresh before the initial load answers.
      unawaited(notifier.refresh());
      await pumpEventQueue();

      completers[1]!.complete(_page(['fresh'], 1));
      await pumpEventQueue();
      completers[0]!.complete(_page(['stale'], 1));
      await pumpEventQueue();

      expect(notifier.state.items, ['fresh']);
    });

    test('prefetch fires within three items of the end, not before', () async {
      final notifier = _FakeNotifier(
        (page) async => _page(['a', 'b', 'c', 'd', 'e', 'f'], 20),
        pageSize: 6,
      );
      await pumpEventQueue();

      notifier.onItemBuilt(1);
      await pumpEventQueue();
      expect(notifier.requestedPages, [0]);

      notifier.onItemBuilt(3);
      await pumpEventQueue();
      expect(notifier.requestedPages, [0, 1]);
    });

    // Une écriture reportée dans la liste sans la recharger : la personne
    // garde sa place (docs/LEDGER_*.md MOB-168).
    group('in place', () {
      test('replaceItem swaps one loaded item and fetches nothing', () async {
        final notifier = _FakeNotifier(
          (page) async => _page(['a', 'b', 'c'], 3),
        );
        await pumpEventQueue();

        expect(notifier.replaceItem('b', 'B'), isTrue);

        expect(notifier.state.items, ['a', 'B', 'c']);
        expect(notifier.state.total, 3);
        expect(notifier.requestedPages, [0]);
      });

      test('replaceItem says so when the item is not loaded', () async {
        final notifier = _FakeNotifier(
          (page) async => _page(['a', 'b', 'c'], 3),
        );
        await pumpEventQueue();

        expect(notifier.replaceItem('z', 'Z'), isFalse);
        expect(notifier.state.items, ['a', 'b', 'c']);
      });

      test('removeItem drops the item and the total, with no request when '
          'everything is loaded', () async {
        final notifier = _FakeNotifier(
          (page) async => _page(['a', 'b', 'c'], 3),
        );
        await pumpEventQueue();

        expect(await notifier.removeItem('b'), isTrue);

        expect(notifier.state.items, ['a', 'c']);
        expect(notifier.state.total, 2);
        expect(notifier.state.hasMore, isFalse);
        expect(notifier.state.isLoadingInitial, isFalse);
        expect(notifier.requestedPages, [0]);
      });

      test('removeItem says so when the item is not loaded', () async {
        final notifier = _FakeNotifier(
          (page) async => _page(['a', 'b', 'c'], 3),
        );
        await pumpEventQueue();

        expect(await notifier.removeItem('z'), isFalse);
        expect(notifier.state.total, 3);
      });

      test('removeItem with pages left re-reads the last loaded page: the '
          'row that slid into it is not skipped', () async {
        // The server's list, one row shorter once 'b' is gone.
        var all = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
        final notifier = _FakeNotifier(
          (page) async =>
              _page(all.skip(page * 3).take(3).toList(), all.length),
        );
        await pumpEventQueue();
        expect(notifier.state.items, ['a', 'b', 'c']);

        all = ['a', 'c', 'd', 'e', 'f', 'g'];
        expect(await notifier.removeItem('b'), isTrue);

        // Page 0 again: 'd' slid from page 1 into it.
        expect(notifier.requestedPages, [0, 0]);
        expect(notifier.state.items, ['a', 'c', 'd']);
        expect(notifier.state.total, 6);
        expect(notifier.state.hasMore, isTrue);

        await notifier.loadNextPage();
        expect(notifier.state.items, ['a', 'c', 'd', 'e', 'f', 'g']);
        expect(notifier.state.hasMore, isFalse);
      });

      test('removeItem that brings the total down to exactly what is loaded '
          'still re-reads: the last row slid in and no next page would bring '
          'it', () async {
        var all = ['a', 'b', 'c', 'd'];
        final notifier = _FakeNotifier(
          (page) async =>
              _page(all.skip(page * 3).take(3).toList(), all.length),
        );
        await pumpEventQueue();
        expect(notifier.state.items, ['a', 'b', 'c']);
        expect(notifier.state.hasMore, isTrue);

        all = ['a', 'c', 'd'];
        expect(await notifier.removeItem('b'), isTrue);

        expect(notifier.requestedPages, [0, 0]);
        expect(notifier.state.items, ['a', 'c', 'd']);
        expect(notifier.state.total, 3);
        expect(notifier.state.hasMore, isFalse);
      });

      test('removeItem with two pages loaded and one row left: that row '
          'slides into the second page', () async {
        var all = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
        final notifier = _FakeNotifier(
          (page) async =>
              _page(all.skip(page * 3).take(3).toList(), all.length),
        );
        await pumpEventQueue();
        await notifier.loadNextPage();
        expect(notifier.state.items, ['a', 'b', 'c', 'd', 'e', 'f']);
        expect(notifier.state.hasMore, isTrue);

        all = ['a', 'b', 'c', 'd', 'f', 'g'];
        expect(await notifier.removeItem('e'), isTrue);

        // The last loaded page again, not the first.
        expect(notifier.requestedPages, [0, 1, 1]);
        expect(notifier.state.items, ['a', 'b', 'c', 'd', 'f', 'g']);
        expect(notifier.state.total, 6);
        expect(notifier.state.hasMore, isFalse);
      });

      test('removeItem keeps the removal when the re-read fails', () async {
        var fail = false;
        final notifier = _FakeNotifier((page) async {
          if (fail) throw StateError('offline');
          return _page(['a', 'b', 'c'], 7);
        });
        await pumpEventQueue();

        fail = true;
        expect(await notifier.removeItem('b'), isTrue);

        expect(notifier.state.items, ['a', 'c']);
        expect(notifier.state.total, 6);
        expect(notifier.state.initialError, isNull);
        expect(notifier.state.nextError, isNull);
      });

      test('removeItem while a page is in flight refreshes the list: that '
          'page was cut on the old offsets', () async {
        final completers = <int, Completer<PageResult<String>>>{};
        var call = 0;
        final notifier = _FakeNotifier((page) {
          final index = call++;
          if (index == 0) return Future.value(_page(['a', 'b', 'c'], 7));
          return (completers[index] = Completer()).future;
        });
        await pumpEventQueue();

        unawaited(notifier.loadNextPage());
        await pumpEventQueue();
        final removal = notifier.removeItem('b');
        await pumpEventQueue();
        // The stale next page, then the refresh.
        completers[1]!.complete(_page(['d', 'e', 'f'], 7));
        completers[2]!.complete(_page(['a', 'c', 'd'], 6));
        expect(await removal, isTrue);

        expect(notifier.requestedPages, [0, 1, 0]);
        expect(notifier.state.items, ['a', 'c', 'd']);
        expect(notifier.state.total, 6);
      });
    });
  });
}
