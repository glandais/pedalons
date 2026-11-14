import 'package:flutter/widgets.dart';

class _PostDetailKey extends ValueKey<String> {
  const _PostDetailKey(String value) : super('postDetail_$value');
}

class PostDetailKeys {
  final loadError = const _PostDetailKey('loadError');
  final title = const _PostDetailKey('title');
  final moreButton = const _PostDetailKey('moreButton');
}

class _PostEditorKey extends ValueKey<String> {
  const _PostEditorKey(String value) : super('postEditor_$value');
}

/// L'éditeur de publication, création et modification (ledger `MOB-156`).
/// Les boutons de médias (logo, images, pièces jointes) gardent les clés de
/// `keys.rideEditor` : c'est le même widget.
class PostEditorKeys {
  final forbidden = const _PostEditorKey('forbidden');
  final loadError = const _PostEditorKey('loadError');
  final errorBanner = const _PostEditorKey('errorBanner');
  final nameField = const _PostEditorKey('nameField');
  final slugRow = const _PostEditorKey('slugRow');
  final slugField = const _PostEditorKey('slugField');
  final slugSave = const _PostEditorKey('slugSave');
  final markdownField = const _PostEditorKey('markdownField');
  final visibility = const _PostEditorKey('visibility');
  final tagsRow = const _PostEditorKey('tagsRow');
  final signedAsTeam = const _PostEditorKey('signedAsTeam');
  final status = const _PostEditorKey('status');

  /// Un segment du choix de statut (`DRAFT`, `PUBLISHED`).
  ValueKey<String> statusOption(String status) =>
      _PostEditorKey('status_$status');
  final dateRow = const _PostEditorKey('dateRow');
  final timeRow = const _PostEditorKey('timeRow');
  final publishAtRow = const _PostEditorKey('publishAtRow');
  final saveButton = const _PostEditorKey('saveButton');
}

class _PostManageKey extends ValueKey<String> {
  const _PostManageKey(String value) : super('postManage_$value');
}

/// Les gestes d'organisateur de l'écran d'une publication (ledger `MOB-156`).
class PostManageKeys {
  /// Le crayon de la barre : modifier la publication.
  final editButton = const _PostManageKey('editButton');

  // Les lignes du menu « Gérer la publication ».
  final publish = const _PostManageKey('publish');
  final unpublish = const _PostManageKey('unpublish');
  final cancel = const _PostManageKey('cancel');
  final reinstate = const _PostManageKey('reinstate');
  final delete = const _PostManageKey('delete');
  final restore = const _PostManageKey('restore');
  final report = const _PostManageKey('report');

  /// Le bandeau d'une publication supprimée.
  final deletedBanner = const _PostManageKey('deletedBanner');
}
