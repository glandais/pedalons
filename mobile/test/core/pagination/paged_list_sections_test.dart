import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pagination/pagination.dart';

/// Règle RL15 des listes (KIT §10) : une liste servie en deux sections
/// (`when=UPCOMING_FIRST`) place sa frontière **d'après la position de chaque
/// ligne dans la liste entière** — `page * size + i < firstSectionTotal` —, et
/// non d'après son rang à l'écran : un doublon écarté entre deux pages ne la
/// décale pas.
void main() {
  test('sans section, rien n\'est compté', () async {
    final _Pages notifier = _Pages(<int, List<String>>{
      0: <String>['a', 'b'],
    }, total: 2);
    await _settle();
    expect(notifier.state.isSectioned, isFalse);
    expect(notifier.state.firstSectionLoaded, 0);
  });

  test('une première page entièrement « À venir »', () async {
    final _Pages notifier = _Pages(
      <int, List<String>>{
        0: <String>['u1', 'u2', 'u3'],
      },
      total: 10,
      firstSectionTotal: 5,
      pageSize: 3,
    );
    await _settle();
    expect(notifier.state.firstSectionTotal, 5);
    expect(notifier.state.firstSectionLoaded, 3);
  });

  test('la frontière au milieu de la deuxième page', () async {
    final _Pages notifier = _Pages(
      <int, List<String>>{
        0: <String>['u1', 'u2', 'u3'],
        1: <String>['u4', 'u5', 'p1'],
      },
      total: 10,
      firstSectionTotal: 5,
      pageSize: 3,
    );
    await _settle();
    await notifier.loadNextPage();
    expect(notifier.state.items, <String>['u1', 'u2', 'u3', 'u4', 'u5', 'p1']);
    expect(notifier.state.firstSectionLoaded, 5);
  });

  test('un doublon écarté ne décale pas la frontière', () async {
    // « u3 » revient en tête de la page 1 (un élément ajouté entre deux
    // appels) : il est écarté, et seules les lignes de position < 5 comptent.
    final _Pages notifier = _Pages(
      <int, List<String>>{
        0: <String>['u1', 'u2', 'u3'],
        1: <String>['u3', 'u4', 'p1'],
      },
      total: 10,
      firstSectionTotal: 5,
      pageSize: 3,
    );
    await _settle();
    await notifier.loadNextPage();
    expect(notifier.state.items, <String>['u1', 'u2', 'u3', 'u4', 'p1']);
    expect(notifier.state.firstSectionLoaded, 4);
    expect(notifier.state.items[notifier.state.firstSectionLoaded], 'p1');
  });

  test('aucune ligne « À venir » : la frontière est en tête', () async {
    final _Pages notifier = _Pages(
      <int, List<String>>{
        0: <String>['p1', 'p2'],
      },
      total: 2,
      firstSectionTotal: 0,
    );
    await _settle();
    expect(notifier.state.isSectioned, isTrue);
    expect(notifier.state.firstSectionLoaded, 0);
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _Pages extends PagedListNotifier<String> {
  _Pages(
    this.pages, {
    required this.total,
    this.firstSectionTotal,
    super.pageSize,
  });

  final Map<int, List<String>> pages;
  final int total;
  final int? firstSectionTotal;

  @override
  Future<PageResult<String>> fetchPage(int page) async => PageResult<String>(
    items: pages[page] ?? const <String>[],
    total: total,
    firstSectionTotal: firstSectionTotal,
  );

  @override
  Object? itemKey(String item) => item;
}
