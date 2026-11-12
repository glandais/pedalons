import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/providers/route_list_provider.dart';

void main() {
  group('portée', () {
    // RL4 (KIT §10) : la pastille compte exactement ce que « Effacer les
    // filtres » lève. Ces tests codaient l'ancien compte — l'équipe de la
    // page comptait, la recherche non — et la portée gardée par `cleared`.
    test('l\'équipe de la page ne compte pas ; une portée écartée de son '
        'défaut, si', () {
      expect(const RouteFilters().activeCount, 0);
      expect(const RouteFilters(teamSlug: 'n-peloton').activeCount, 0);
      expect(
        const RouteFilters(
          minRole: MinRole.member,
          defaultMinRole: MinRole.member,
        ).activeCount,
        0,
      );
      expect(const RouteFilters(defaultMinRole: MinRole.member).activeCount, 1);
      expect(const RouteFilters(minRole: MinRole.admin).activeCount, 1);
      expect(
        const RouteFilters(
          teamSlug: 'n-peloton',
          surfaceType: SurfaceType.gravel,
        ).activeCount,
        1,
      );
    });

    test('la recherche compte : « Effacer les filtres » la lève', () {
      expect(const RouteFilters(search: 'ventoux').activeCount, 1);
    });

    test('le tri ne compte jamais', () {
      expect(
        const RouteFilters(
          sortBy: RouteSortBy.distance,
          sortDir: SortDirection.asc,
        ).activeCount,
        0,
      );
    });

    test('« Effacer les filtres » remet la portée à son défaut, garde le tri '
        'et l\'équipe de la page', () {
      const RouteFilters filters = RouteFilters(
        teamSlug: 'n-peloton',
        search: 'ventoux',
        surfaceType: SurfaceType.gravel,
        sortBy: RouteSortBy.distance,
      );
      final RouteFilters cleared = filters.cleared;
      expect(cleared.teamSlug, 'n-peloton');
      expect(cleared.search, isNull);
      expect(cleared.surfaceType, isNull);
      expect(cleared.sortBy, RouteSortBy.distance);
      expect(cleared.activeCount, 0);

      const RouteFilters explorer = RouteFilters(
        minRole: MinRole.admin,
        defaultMinRole: MinRole.member,
      );
      expect(explorer.cleared.minRole, MinRole.member);
      expect(explorer.cleared.scopeIsDefault, isTrue);
    });
  });

  group('tags (MOB-39)', () {
    test('un tag choisi est un filtre actif, qui se retire seul', () {
      const RouteFilters filters = RouteFilters(
        teamSlug: 'n-peloton',
        tagIds: <String>['a1', 'b2'],
      );
      expect(filters.activeFields, contains(RouteFilterField.tags));
      // Les tags seuls : l'équipe de la page n'est pas un filtre (RL4).
      expect(filters.activeCount, 1);
      final RouteFilters without = filters.without(RouteFilterField.tags);
      expect(without.tagIds, isEmpty);
      expect(without.teamSlug, 'n-peloton');
    });

    test('changer d\'équipe lève les tags, pas le reste', () {
      final RouteFilters filters = const RouteFilters(
        teamSlug: 'n-peloton',
        tagIds: <String>['a1'],
      ).copyWith(surfaceType: SurfaceType.gravel);
      expect(filters.tagIds, <String>['a1']);

      final RouteFilters moved = filters.copyWith(teamSlug: 'autre-equipe');
      expect(moved.tagIds, isEmpty);
      expect(moved.surfaceType, SurfaceType.gravel);
    });

    test('deux sélections égales désignent le même jeu de résultats', () {
      // Deux listes distinctes mais égales : la clé de famille ne doit pas
      // construire deux notifiers.
      final RouteFilters a = RouteFilters(
        teamSlug: 'n-peloton',
        tagIds: List<String>.of(<String>['a1', 'b2']),
      );
      final RouteFilters b = RouteFilters(
        teamSlug: 'n-peloton',
        tagIds: List<String>.of(<String>['a1', 'b2']),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const RouteFilters(teamSlug: 'n-peloton'), isFalse);
    });

    test('« Effacer les filtres » lève les tags', () {
      const RouteFilters filters = RouteFilters(
        teamSlug: 'n-peloton',
        tagIds: <String>['a1'],
      );
      expect(filters.cleared.tagIds, isEmpty);
    });
  });

  group('proximité', () {
    test('une latitude seule n\'est pas une position', () {
      expect(const RouteFilters(nearLat: 47.2).hasProximity, isFalse);
      expect(
        const RouteFilters(nearLat: 47.2, nearLon: -1.5).hasProximity,
        isTrue,
      );
    });

    test('la retirer efface la position et le rayon', () {
      const RouteFilters armed = RouteFilters(
        nearLat: 47.2,
        nearLon: -1.5,
        nearRadius: 50000,
      );
      final RouteFilters off = armed.without(RouteFilterField.proximity);
      expect(off.hasProximity, isFalse);
      expect(off.nearRadius, isNull);
    });
  });

  group('ordre d\'ajout', () {
    test('il suit les filtres posés, et oublie ceux qu\'on retire', () {
      final RouteFilters a = const RouteFilters().copyWith(
        surfaceType: SurfaceType.gravel,
      );
      final RouteFilters b = a.copyWith(hilliness: Hilliness.hilly);
      expect(b.activeFieldsNewestFirst, <RouteFilterField>[
        RouteFilterField.hilliness,
        RouteFilterField.surfaceType,
      ]);

      final RouteFilters c = b.without(RouteFilterField.surfaceType);
      expect(c.activeFieldsNewestFirst, <RouteFilterField>[
        RouteFilterField.hilliness,
      ]);
    });

    test('il ne participe pas à l\'identité du jeu de résultats', () {
      // Deux mêmes filtres posés dans deux ordres désignent la même liste et
      // doivent partager le même notifier : sinon changer l'ordre relancerait
      // une pagination complète pour rien.
      final RouteFilters ab = const RouteFilters()
          .copyWith(surfaceType: SurfaceType.gravel)
          .copyWith(hilliness: Hilliness.hilly);
      final RouteFilters ba = const RouteFilters()
          .copyWith(hilliness: Hilliness.hilly)
          .copyWith(surfaceType: SurfaceType.gravel);
      expect(ab, ba);
      expect(ab.hashCode, ba.hashCode);
      expect(ab.activeFieldsNewestFirst, isNot(ba.activeFieldsNewestFirst));
    });
  });

  group('densité', () {
    test('201 résultats basculent d\'office en compact', () {
      expect(effectiveRouteDensity(null, 200), RouteListDensity.cards);
      expect(effectiveRouteDensity(null, 201), RouteListDensity.compact);
    });

    test('le choix manuel écrase la règle', () {
      expect(
        effectiveRouteDensity(RouteListDensity.cards, 5000),
        RouteListDensity.cards,
      );
      expect(
        effectiveRouteDensity(RouteListDensity.compact, 3),
        RouteListDensity.compact,
      );
    });

    test('un total inconnu retombe sur les vignettes', () {
      expect(effectiveRouteDensity(null, null), RouteListDensity.cards);
    });
  });
}
