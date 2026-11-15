import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// La longueur d'un libellé **une fois rogné** (plan des tags, D16). Le
/// serveur rogne puis vérifie (`TAG_LABEL_INVALID`) ; le formulaire fait de
/// même pour ne pas envoyer ce qu'il sait refusé.
const int kTagLabelMaxLength = 32;

/// Le nombre de tags d'une équipe pour un type de contenu, au plus — le
/// serveur refuse au-delà (D16, `TAG_LIMIT_REACHED`).
const int kTagLimitPerKind = 100;

/// Les types de contenu qui portent des tags, dans l'ordre des onglets du
/// site (`TeamTagsPage`).
const List<TagTarget> kTagKinds = <TagTarget>[
  TagTarget.ride,
  TagTarget.post,
  TagTarget.trip,
  TagTarget.route,
  TagTarget.ad,
];

/// L'équipe a-t-elle la section à laquelle [kind] s'applique ?
bool tagKindEnabled(TeamDetailDto team, TagTarget kind) => switch (kind) {
  TagTarget.ride => team.enableRides,
  TagTarget.post => team.enablePosts,
  TagTarget.trip => team.enableTrips,
  TagTarget.route => team.enableRoutes,
  TagTarget.ad => team.enableAds,
  TagTarget.$unknown => false,
};

/// Les tags de [tags] rangés par type, dans l'ordre où le serveur les rend
/// (par libellé). Un type que cette version ne connaît pas est écarté.
Map<TagTarget, List<TagWithUsageDto>> tagsByKind(List<TagWithUsageDto> tags) {
  final Map<TagTarget, List<TagWithUsageDto>> grouped =
      <TagTarget, List<TagWithUsageDto>>{
        for (final TagTarget kind in kTagKinds) kind: <TagWithUsageDto>[],
      };
  for (final TagWithUsageDto tag in tags) {
    grouped[TagTarget.fromJson(tag.type)]?.add(tag);
  }
  return grouped;
}

/// Les types que l'écran propose : ceux dont la section est active, **et**
/// ceux qui portent encore des tags — une section désactivée garde sa puce
/// tant qu'il lui reste des tags, pour qu'ils restent gérables.
List<TagTarget> offeredTagKinds(
  TeamDetailDto team,
  Map<TagTarget, List<TagWithUsageDto>> byKind,
) => <TagTarget>[
  for (final TagTarget kind in kTagKinds)
    if (tagKindEnabled(team, kind) || (byKind[kind]?.isNotEmpty ?? false)) kind,
];

/// Le type que nomme le `?type=` de la route (`ride`, `post`, `trip`,
/// `route`, `ad`, comme au site), ou `null` — absent ou inconnu, l'écran
/// ouvre son premier type.
TagTarget? tagKindFromQuery(String? value) {
  if (value == null) return null;
  final TagTarget kind = TagTarget.fromJson(value.toUpperCase());
  return kind == TagTarget.$unknown ? null : kind;
}

/// Le formulaire d'un tag : son libellé et sa couleur. Le **type** n'en fait
/// pas partie — il est celui de la puce ouverte à la création, et ne change
/// jamais ensuite.
@immutable
class TagForm {
  const TagForm({required this.label, required this.color});

  /// Le formulaire vide du site (`TagFormModal`) : gris par défaut.
  const TagForm.initial() : label = '', color = TagColor.gray;

  /// Le tag tel qu'il est. Une couleur que cette version ne connaît pas
  /// retombe sur le gris, comme à l'affichage (`tagFamily`).
  factory TagForm.fromTag(TagWithUsageDto tag) {
    final TagColor color = TagColor.fromJson(tag.color);
    return TagForm(
      label: tag.label,
      color: color == TagColor.$unknown ? TagColor.gray : color,
    );
  }

  final String label;
  final TagColor color;

  TagForm copyWith({String? label, TagColor? color}) =>
      TagForm(label: label ?? this.label, color: color ?? this.color);

  /// Le libellé qui part, et celui que l'aperçu montre : rogné, comme le
  /// serveur le fait (D17).
  String get trimmedLabel => label.trim();

  /// 1 à [kTagLabelMaxLength] caractères, comptés **après** rognage.
  bool get labelValid {
    final int length = trimmedLabel.length;
    return length >= 1 && length <= kTagLabelMaxLength;
  }

  bool get isValid => labelValid;

  TagCreateRequest toCreateRequest(TagTarget type) => TagCreateRequest(
    type: type.toJson(),
    label: trimmedLabel,
    color: color.toJson(),
  );

  /// Libellé et couleur, tous deux : un champ absent serait laissé tel quel,
  /// et le formulaire les montre tous les deux.
  TagUpdateRequest toUpdateRequest() =>
      TagUpdateRequest(label: trimmedLabel, color: color.toJson());
}
