import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/utils/api_error_handler.dart';
import '../../../data/ride_editor_repository.dart';
import '../../../domain/markdown_edit.dart';

/// Les gestes sur les médias d'un contenu édité — logo, images, pièces
/// jointes, image insérée dans le texte —, partagés par l'éditeur de sortie
/// (ledger `MOB-76`) et celui de parcours (`MOB-79`) : même `MediaDto`, même
/// `POST …/assets` de l'équipe, mêmes messages.
///
/// L'écran qui l'adopte dit où vivent le formulaire et le texte (les crochets
/// abstraits) ; le mixin porte les sélecteurs, les envois et la mise à jour de
/// `media.assets`. Chaque ajout est un envoi immédiat : l'asset rendu n'est
/// rattaché au contenu qu'à l'enregistrement.
mixin EditorMediaActions<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  /// L'équipe qui reçoit les envois.
  String get mediaTeamSlug;

  /// Les médias du formulaire en cours.
  MediaDto get editedMedia;

  /// Remplace les médias du formulaire.
  void applyMedia(MediaDto media);

  /// Le contrôleur du texte markdown : une image retirée en efface les
  /// directives, une image ajoutée y est insérée.
  TextEditingController get markdownController;

  /// Un envoi commence ou finit. Au début, l'écran efface aussi son erreur.
  void setMediaUploading(bool uploading);

  /// Un envoi ou un sélecteur a échoué : l'écran affiche [message].
  void showMediaError(String message);

  void _setAssets(AssetsDto assets) =>
      applyMedia(editedMedia.copyWith(assets: assets));

  Future<AssetDto?> _upload(
    String path,
    AssetTypeRequest type, {
    String? name,
  }) async {
    setMediaUploading(true);
    try {
      return await ref
          .read(rideEditorRepositoryProvider)
          .uploadAsset(
            mediaTeamSlug,
            filePath: path,
            type: type,
            fileName: name,
          );
    } catch (error, stackTrace) {
      if (mounted) {
        showMediaError(
          '${'rides.editor.uploadFailed'.tr()} : ${getErrorMessage(error, stackTrace)}',
        );
      }
      return null;
    } finally {
      if (mounted) setMediaUploading(false);
    }
  }

  Future<XFile?> _pickImage() async {
    try {
      // 1920 px : la plus grande variante que le serveur sert (visionneuse).
      return await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2560,
        maxHeight: 2560,
      );
    } on PlatformException catch (error, stackTrace) {
      if (mounted) showMediaError(getErrorMessage(error, stackTrace));
      return null;
    }
  }

  Future<void> pickLogo() async {
    final XFile? file = await _pickImage();
    if (file == null) return;
    final AssetDto? asset = await _upload(
      file.path,
      AssetTypeRequest.logo,
      name: file.name,
    );
    if (asset == null || !mounted) return;
    _setAssets(editedMedia.assets.copyWith(logo: asset));
  }

  /// Retire le logo.
  void removeLogo() => _setAssets(editedMedia.assets.copyWith(logo: null));

  /// Une image envoyée rejoint `assets.images` **et** rend sa directive,
  /// pour la barre d'outils qui l'insère dans le texte — le geste du site.
  Future<String?> addImage() async {
    final XFile? file = await _pickImage();
    if (file == null) return null;
    final AssetDto? asset = await _upload(
      file.path,
      AssetTypeRequest.image,
      name: file.name,
    );
    if (asset == null || !mounted) return null;
    final AssetsDto assets = editedMedia.assets;
    _setAssets(assets.copyWith(images: <AssetDto>[...assets.images, asset]));
    return assetDirective(asset.id);
  }

  /// Le bouton « Ajouter une image » de la section Médias : envoie l'image et
  /// l'insère au curseur du texte.
  Future<void> addImageFromSection() async {
    final TextEditingValue before = markdownController.value;
    final String? directive = await addImage();
    if (directive == null) return;
    markdownController.value = insertBlock(
      before.selection.isValid
          ? before
          : before.copyWith(
              selection: TextSelection.collapsed(offset: before.text.length),
            ),
      directive,
    );
  }

  void removeImage(AssetDto image) {
    final AssetsDto assets = editedMedia.assets;
    _setAssets(
      assets.copyWith(
        images: <AssetDto>[
          for (final AssetDto a in assets.images)
            if (a.id != image.id) a,
        ],
      ),
    );
    markdownController.text = removeAssetDirectives(
      markdownController.text,
      image.id,
    );
  }

  Future<void> addAttachments() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles();
    } on PlatformException catch (error, stackTrace) {
      if (mounted) showMediaError(getErrorMessage(error, stackTrace));
      return;
    }
    final List<AssetDto> added = <AssetDto>[];
    for (final PlatformFile file in files) {
      final String? path = file.path;
      if (path == null) continue;
      final AssetDto? asset = await _upload(
        path,
        AssetTypeRequest.attachment,
        name: file.name,
      );
      if (asset == null) break;
      added.add(asset);
    }
    if (added.isEmpty || !mounted) return;
    final AssetsDto assets = editedMedia.assets;
    _setAssets(
      assets.copyWith(attachments: <AssetDto>[...assets.attachments, ...added]),
    );
  }

  void removeAttachment(AssetDto file) {
    final AssetsDto assets = editedMedia.assets;
    _setAssets(
      assets.copyWith(
        attachments: <AssetDto>[
          for (final AssetDto a in assets.attachments)
            if (a.id != file.id) a,
        ],
      ),
    );
  }
}
