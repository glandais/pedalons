import 'package:flutter/widgets.dart';

class _TagKey extends ValueKey<String> {
  const _TagKey(String value) : super('tags_$value');
}

/// Le filtre par tag des listes d'équipe et sa feuille de choix.
class TagKeys {
  /// La puce « Tags » d'une barre de filtres.
  final filterChip = const _TagKey('filterChip');

  /// La ligne d'un tag dans la feuille de choix, par son id.
  ValueKey<String> pickerRow(String tagId) => _TagKey('pickerRow_$tagId');

  final pickerApply = const _TagKey('pickerApply');
  final pickerClear = const _TagKey('pickerClear');
}

class _TeamTagsKey extends ValueKey<String> {
  const _TeamTagsKey(String value) : super('teamTags_$value');
}

/// « Tags » de la gestion de l'équipe : le vocabulaire par type de contenu et
/// la feuille de son formulaire (ledger `MOB-169`).
class TeamTagsAdminKeys {
  final loadError = const _TeamTagsKey('loadError');

  /// Le refus rendu à qui n'administre pas l'équipe, et son « Retour ».
  final forbidden = const _TeamTagsKey('forbidden');
  final forbiddenBack = const _TeamTagsKey('forbiddenBack');

  /// « Créer un tag », en tête d'écran et dans l'état vide d'un type.
  final addButton = const _TeamTagsKey('addButton');
  final emptyAddButton = const _TeamTagsKey('emptyAddButton');

  /// Ce que le serveur a refusé à une suppression.
  final errorBanner = const _TeamTagsKey('errorBanner');

  /// La puce d'un type de contenu, par sa valeur au contrat (`RIDE`…).
  ValueKey<String> kind(String type) => _TeamTagsKey('kind_$type');

  /// « Aucune section active » : aucun type à proposer.
  final noKind = const _TeamTagsKey('noKind');

  /// L'état vide du type ouvert, l'échec de lecture du vocabulaire.
  final empty = const _TeamTagsKey('empty');
  final tagsError = const _TeamTagsKey('tagsError');

  /// « n / 100 tags pour ce type ».
  final limit = const _TeamTagsKey('limit');

  /// La ligne d'un tag, sa puce, son usage et ses deux gestes.
  ValueKey<String> row(String tagId) => _TeamTagsKey('row_$tagId');
  ValueKey<String> rowChip(String tagId) => _TeamTagsKey('rowChip_$tagId');
  ValueKey<String> rowUsage(String tagId) => _TeamTagsKey('rowUsage_$tagId');
  ValueKey<String> rowEdit(String tagId) => _TeamTagsKey('rowEdit_$tagId');
  ValueKey<String> rowDelete(String tagId) => _TeamTagsKey('rowDelete_$tagId');

  /// La puce du tag dans la confirmation de suppression.
  final deleteChip = const _TeamTagsKey('deleteChip');

  // ── Feuille du formulaire ──
  final formSheet = const _TeamTagsKey('formSheet');
  final formClose = const _TeamTagsKey('formClose');
  final formErrorBanner = const _TeamTagsKey('formErrorBanner');
  final formLabel = const _TeamTagsKey('formLabel');

  /// La pastille d'une couleur, par sa valeur au contrat (`GRAY`…).
  ValueKey<String> formColor(String color) => _TeamTagsKey('formColor_$color');
  final formPreview = const _TeamTagsKey('formPreview');
  final formSubmit = const _TeamTagsKey('formSubmit');
}
