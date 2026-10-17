import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import 'ride_form.dart';

/// Bornes de `RideTemplateRequest` au contrat. La description et les groupes
/// ont celles d'une sortie ([kRideMarkdownMaxLength], [kRideGroupNameMaxLength],
/// [kRideMaxTags]).
const int kRideTemplateNameMaxLength = 200;

/// Longueur de saisie du numéro de la prochaine sortie : neuf chiffres tiennent
/// toujours dans un entier 32 bits, le type du contrat.
const int kRideTemplateNextNumberMaxDigits = 9;

/// Le formulaire d'un modèle de sortie — la projection de
/// `RideTemplateRequest` que l'éditeur tient (ledger `MOB-78`).
///
/// Un modèle ne porte ni date, ni lieux, ni parcours, ni meneur, ni médias :
/// ses groupes sont des [RideGroupForm] dont `routeSlug` et `leaderId`
/// restent nuls.
@immutable
class RideTemplateForm {
  const RideTemplateForm({
    required this.name,
    required this.markdown,
    required this.visibility,
    required this.status,
    required this.groups,
    this.nextNumber,
    this.tagIds = const <String>[],
  });

  /// Le formulaire vide du site (`CreateRideTemplatePage`) : sans nom, la
  /// visibilité de l'équipe, publié, un groupe « Groupe 1 ».
  factory RideTemplateForm.initial(
    TeamDetailDto team, {
    required String firstGroupName,
  }) => RideTemplateForm(
    name: '',
    markdown: '',
    visibility: Visibility.fromJson(team.visibility),
    status: Status.published,
    groups: <RideGroupForm>[RideGroupForm(name: firstGroupName)],
  );

  /// Le modèle tel qu'il est, prêt à être réécrit : groupes dans l'ordre du
  /// serveur (`sortOrder`) **avec leur id**, tags en identifiants.
  factory RideTemplateForm.fromTemplate(RideTemplateDto template) {
    final List<RideTemplateGroupDto> groups = <RideTemplateGroupDto>[
      ...template.groups,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return RideTemplateForm(
      name: template.name,
      markdown: template.markdown,
      visibility: Visibility.fromJson(template.visibility),
      status: Status.fromJson(template.status),
      groups: <RideGroupForm>[
        for (final RideTemplateGroupDto group in groups)
          RideGroupForm.fromTemplateGroup(group),
      ],
      nextNumber: template.nextNumber,
      tagIds: <String>[for (final TagDto tag in template.tags) tag.id],
    );
  }

  final String name;
  final String markdown;
  final Visibility visibility;
  final Status status;
  final List<RideGroupForm> groups;

  /// Le numéro que prendra la prochaine sortie créée depuis ce modèle ; nul :
  /// le modèle ne numérote pas.
  final int? nextNumber;
  final List<String> tagIds;

  RideTemplateForm copyWith({
    String? name,
    String? markdown,
    Visibility? visibility,
    Status? status,
    List<RideGroupForm>? groups,
    int? Function()? nextNumber,
    List<String>? tagIds,
  }) => RideTemplateForm(
    name: name ?? this.name,
    markdown: markdown ?? this.markdown,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    groups: groups ?? this.groups,
    nextNumber: nextNumber == null ? this.nextNumber : nextNumber(),
    tagIds: tagIds ?? this.tagIds,
  );

  /// La requête, groupes sans nom écartés (le site les filtre aussi) ;
  /// [tagIds] part toujours, `[]` compris, qui veut dire « plus aucun ».
  RideTemplateRequest toRequest() => RideTemplateRequest(
    name: name.trim(),
    markdown: markdown,
    visibility: visibility.toJson(),
    status: status.toJson(),
    groups: <RideTemplateGroupRequest>[
      for (final RideGroupForm group in groups)
        if (group.hasName) group.toTemplateGroupRequest(),
    ],
    tagIds: tagIds,
    nextNumber: nextNumber,
  );

  // --- Validation : les contraintes de `RideTemplateRequest`, lues avant
  // d'envoyer.

  bool get nameValid {
    final int length = name.trim().length;
    return length >= 1 && length <= kRideTemplateNameMaxLength;
  }

  bool get markdownValid => markdown.length <= kRideMarkdownMaxLength;

  bool get nextNumberValid => nextNumber == null || nextNumber! >= 0;

  /// Contrairement à une sortie, **aucun** groupe n'est exigé : le site
  /// accepte un modèle sans groupe.
  bool get groupsValid => groups.every(
    (RideGroupForm g) =>
        g.name.trim().length <= kRideGroupNameMaxLength &&
        (g.averageSpeed == null || g.averageSpeed! > 0) &&
        (g.maxParticipants == null || g.maxParticipants! > 0),
  );

  bool get tagsValid => tagIds.length <= kRideMaxTags;

  bool get isValid =>
      nameValid && markdownValid && nextNumberValid && groupsValid && tagsValid;
}
