import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/ride_form.dart';
import 'package:pedalons/features/rides/domain/ride_template_form.dart';

import 'ride_template_fixtures.dart';

/// Le formulaire d'un modèle de sortie (ledger `MOB-78`) : ce qu'il envoie doit
/// être ce que le site envoie, parce que le PUT réécrit **tous** les champs,
/// absents compris — `tagIds: []` est « plus aucun tag », un groupe sans id
/// est supprimé puis recréé.
void main() {
  RideTemplateForm valid() => RideTemplateForm(
    name: 'Sortie du dimanche',
    markdown: '',
    visibility: Visibility.public,
    status: Status.published,
    groups: const <RideGroupForm>[RideGroupForm(name: 'A')],
  );

  group('initial', () {
    test('publié, visibilité de l\'équipe, un « Groupe 1 » sans id', () {
      final RideTemplateForm form = RideTemplateForm.initial(
        fixtureTemplateTeamDetail(visibility: 'TEAM'),
        firstGroupName: 'Groupe 1',
      );

      expect(form.name, isEmpty);
      expect(form.status, Status.published);
      expect(form.visibility, Visibility.team);
      expect(form.nextNumber, isNull);
      expect(form.tagIds, isEmpty);
      expect(form.groups.single.name, 'Groupe 1');
      expect(form.groups.single.id, isNull);
    });
  });

  group('fromTemplate', () {
    test('garde les ids des groupes, les trie par sortOrder, lit tags et '
        'numéro', () {
      final RideTemplateDto template = fixtureTemplate(
        status: 'DRAFT',
        visibility: 'TEAM',
        nextNumber: 7,
        // Dans le désordre : le serveur ne garantit pas l'ordre.
        groups: <RideTemplateGroupDto>[
          fixtureTemplateGroup(id: 'b', name: 'B', sortOrder: 1),
          fixtureTemplateGroup(
            id: 'a',
            name: 'A',
            time: '08:30',
            averageSpeed: 25,
            maxParticipants: 12,
          ),
        ],
        tags: const <TagDto>[
          TagDto(id: 'tag1', label: 'Route', color: 'teal'),
          TagDto(id: 'tag2', label: 'Gravel', color: 'teal'),
        ],
      );

      final RideTemplateForm form = RideTemplateForm.fromTemplate(template);

      expect(form.name, 'Sortie du dimanche');
      expect(form.status, Status.draft);
      expect(form.visibility, Visibility.team);
      expect(form.nextNumber, 7);
      expect(form.tagIds, <String>['tag1', 'tag2']);
      expect(form.groups.map((RideGroupForm g) => g.id), <String?>['a', 'b']);
      expect(form.groups.first.time, '08:30');
      expect(form.groups.first.averageSpeed, 25);
      expect(form.groups.first.maxParticipants, 12);
    });
  });

  group('toRequest', () {
    test('écarte les groupes sans nom et rogne le nom', () {
      final RideTemplateRequest request = valid()
          .copyWith(
            name: '  Sortie du dimanche  ',
            groups: const <RideGroupForm>[
              RideGroupForm(name: 'A'),
              RideGroupForm(name: '   '),
            ],
          )
          .toRequest();

      expect(request.name, 'Sortie du dimanche');
      expect(
        request.groups.map((RideTemplateGroupRequest g) => g.name),
        <String>['A'],
      );
    });

    test('envoie toujours tagIds, vide compris', () {
      final RideTemplateRequest request = valid().toRequest();

      expect(request.tagIds, isNotNull);
      expect(request.tagIds, isEmpty);
      expect(request.toJson()['tagIds'], <Object?>[]);
    });

    test('sans numéro, nextNumber part nul ; avec, il part tel quel', () {
      expect(valid().toRequest().nextNumber, isNull);
      expect(valid().copyWith(nextNumber: () => 41).toRequest().nextNumber, 41);
      expect(
        valid()
            .copyWith(nextNumber: () => 41)
            .copyWith(nextNumber: () => null)
            .toRequest()
            .nextNumber,
        isNull,
      );
    });

    test('renvoie l\'id des groupes d\'un modèle relu', () {
      final RideTemplateRequest request = RideTemplateForm.fromTemplate(
        fixtureTemplate(),
      ).toRequest();

      expect(
        request.groups.map((RideTemplateGroupRequest g) => g.id),
        <String?>['tg1', 'tg2', 'tg3'],
      );
    });
  });

  group('validation', () {
    test('le nom : 1 à 200 caractères une fois rogné', () {
      expect(valid().copyWith(name: '').nameValid, isFalse);
      expect(valid().copyWith(name: '    ').nameValid, isFalse);
      expect(valid().copyWith(name: 'a').nameValid, isTrue);
      expect(valid().copyWith(name: 'a' * 200).nameValid, isTrue);
      expect(valid().copyWith(name: 'a' * 201).nameValid, isFalse);
      expect(valid().copyWith(name: '').isValid, isFalse);
    });

    test('aucun groupe n\'est exigé, comme au site', () {
      final RideTemplateForm form = valid().copyWith(
        groups: const <RideGroupForm>[],
      );

      expect(form.groupsValid, isTrue);
      expect(form.isValid, isTrue);
    });

    test('une vitesse ou des places nulles sont refusées', () {
      expect(
        valid()
            .copyWith(
              groups: const <RideGroupForm>[
                RideGroupForm(name: 'A', averageSpeed: 0),
              ],
            )
            .groupsValid,
        isFalse,
      );
      expect(
        valid()
            .copyWith(
              groups: const <RideGroupForm>[
                RideGroupForm(name: 'A', maxParticipants: 0),
              ],
            )
            .groupsValid,
        isFalse,
      );
      expect(
        valid()
            .copyWith(
              groups: const <RideGroupForm>[
                RideGroupForm(name: 'A', averageSpeed: 25, maxParticipants: 12),
              ],
            )
            .groupsValid,
        isTrue,
      );
    });

    test('dix tags au plus', () {
      List<String> tags(int n) => <String>[for (int i = 0; i < n; i++) 't$i'];

      expect(valid().copyWith(tagIds: tags(10)).tagsValid, isTrue);
      expect(valid().copyWith(tagIds: tags(11)).tagsValid, isFalse);
      expect(valid().copyWith(tagIds: tags(11)).isValid, isFalse);
    });

    test('un numéro négatif est refusé, zéro et l\'absence passent', () {
      expect(valid().copyWith(nextNumber: () => -1).nextNumberValid, isFalse);
      expect(valid().copyWith(nextNumber: () => 0).nextNumberValid, isTrue);
      expect(valid().nextNumberValid, isTrue);
    });

    test('la description : au plus kRideMarkdownMaxLength', () {
      expect(
        valid().copyWith(markdown: 'a' * kRideMarkdownMaxLength).markdownValid,
        isTrue,
      );
      expect(
        valid()
            .copyWith(markdown: 'a' * (kRideMarkdownMaxLength + 1))
            .markdownValid,
        isFalse,
      );
    });
  });

  group('RideGroupForm', () {
    final RideTemplateGroupDto group = fixtureTemplateGroup(
      id: 'tg9',
      name: ' Groupe 9 ',
      time: '07:45',
      averageSpeed: 28,
      maxParticipants: 10,
    );

    test('fromTemplateGroup garde l\'id que fromTemplate vide', () {
      expect(RideGroupForm.fromTemplateGroup(group).id, 'tg9');
      expect(RideGroupForm.fromTemplate(group).id, isNull);
    });

    test('toTemplateGroupRequest renvoie id, nom rogné, heure, vitesse, '
        'places', () {
      final RideTemplateGroupRequest request = RideGroupForm.fromTemplateGroup(
        group,
      ).toTemplateGroupRequest();

      expect(request.id, 'tg9');
      expect(request.name, 'Groupe 9');
      expect(request.time, '07:45');
      expect(request.averageSpeed, 28);
      expect(request.maxParticipants, 10);
    });
  });
}
