import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/tags/domain/tag_form.dart';

import '../teams/team_fixtures.dart';

/// Le formulaire d'un tag et les types que l'écran propose (ledger
/// `MOB-169`).
void main() {
  TagWithUsageDto tag(String id, String type, {String color = 'GRAY'}) =>
      TagWithUsageDto(
        id: id,
        label: 'Tag $id',
        color: color,
        type: type,
        usageCount: 0,
      );

  group('TagForm', () {
    test('vide : gris par défaut, invalide tant que le libellé manque', () {
      const TagForm form = TagForm.initial();
      expect(form.color, TagColor.gray);
      expect(form.labelValid, isFalse);
      expect(form.isValid, isFalse);
    });

    test('le libellé se juge rogné : 1 à 32 caractères', () {
      const TagForm form = TagForm.initial();
      expect(form.copyWith(label: '   ').labelValid, isFalse);
      expect(form.copyWith(label: 'a').labelValid, isTrue);
      expect(form.copyWith(label: 'a' * 32).labelValid, isTrue);
      expect(form.copyWith(label: 'a' * 33).labelValid, isFalse);
      // Les espaces autour ne comptent pas : c'est le libellé rogné qui part.
      expect(form.copyWith(label: '  ${'a' * 32}  ').labelValid, isTrue);
    });

    test('création : type, libellé rogné, couleur', () {
      final TagForm form = const TagForm.initial().copyWith(
        label: '  Gravel ',
        color: TagColor.teal,
      );
      expect(form.toCreateRequest(TagTarget.route).toJson(), <String, Object?>{
        'type': 'ROUTE',
        'label': 'Gravel',
        'color': 'TEAL',
      });
    });

    test('modification : libellé et couleur, jamais le type', () {
      final TagForm form = TagForm.fromTag(tag('t1', 'RIDE', color: 'RED'))
          .copyWith(label: 'Sortie longue');
      expect(form.toUpdateRequest().toJson(), <String, Object?>{
        'label': 'Sortie longue',
        'color': 'RED',
      });
    });

    test('une couleur inconnue de cette version retombe sur le gris', () {
      expect(
        TagForm.fromTag(tag('t1', 'RIDE', color: 'MAGENTA')).color,
        TagColor.gray,
      );
    });
  });

  group('types proposés', () {
    test('toutes les sections actives : les cinq, dans l\'ordre du site', () {
      expect(
        offeredTagKinds(fixtureTeam(), tagsByKind(const <TagWithUsageDto>[])),
        <TagTarget>[
          TagTarget.ride,
          TagTarget.post,
          TagTarget.trip,
          TagTarget.route,
          TagTarget.ad,
        ],
      );
    });

    test('une section désactivée sans tag n\'est pas proposée ; avec un tag, '
        'elle le reste', () {
      final TeamDetailDto team = fixtureTeam().copyWith(
        enableAds: false,
        enableTrips: false,
      );
      expect(
        offeredTagKinds(team, tagsByKind(<TagWithUsageDto>[tag('t1', 'AD')])),
        <TagTarget>[
          TagTarget.ride,
          TagTarget.post,
          TagTarget.route,
          TagTarget.ad,
        ],
      );
    });

    test('aucune section, aucun tag : rien à proposer', () {
      final TeamDetailDto team = fixtureTeam().copyWith(
        enableRides: false,
        enablePosts: false,
        enableTrips: false,
        enableRoutes: false,
        enableAds: false,
      );
      expect(
        offeredTagKinds(team, tagsByKind(const <TagWithUsageDto>[])),
        isEmpty,
      );
    });

    test('un tag d\'un type inconnu est écarté', () {
      final Map<TagTarget, List<TagWithUsageDto>> byKind = tagsByKind(
        <TagWithUsageDto>[tag('t1', 'RIDE'), tag('t2', 'PODCAST')],
      );
      expect(byKind[TagTarget.ride], hasLength(1));
      expect(
        byKind.values.expand((List<TagWithUsageDto> l) => l),
        hasLength(1),
      );
    });

    test('`?type=` : la valeur du site, en minuscules ; inconnue, rien', () {
      expect(tagKindFromQuery('route'), TagTarget.route);
      expect(tagKindFromQuery('AD'), TagTarget.ad);
      expect(tagKindFromQuery('podcast'), isNull);
      expect(tagKindFromQuery(null), isNull);
    });
  });
}
