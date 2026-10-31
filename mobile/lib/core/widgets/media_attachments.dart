import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/generated/export.dart';
import '../../api/pedalons_api_client.dart';
import '../pdl/pdl.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import '../utils/api_error_handler.dart';
import '../utils/formatters.dart';
import '../utils/share_file.dart';
import '../utils/share_link.dart';
import 'authenticated_image.dart';

/// Les fichiers joints à un contenu — facture, notice, fiche technique, road
/// book —, avec de quoi les regarder et de quoi les emporter.
///
/// Un seul rendu pour les huit écrans qui portent un `MediaDto` : sortie,
/// publication, annonce, parcours, voyage, étape, page d'équipe et « à propos ».
/// Les trois copies qui existaient divergeaient déjà — celle des sorties
/// listait les fichiers **sans bouton**, donc sans moyen de les ouvrir.
///
/// Le bloc **n'existe pas** quand il n'y a aucune pièce jointe : ni titre, ni
/// espace réservé. Un écran peut donc le poser sans condition — sauf s'il
/// l'enveloppe lui-même dans un `Padding`, dont les marges, elles, se
/// dessineraient autour de rien.
///
/// `attachments` n'arrive qu'en vue complète : une liste chargée en `COMPACT`
/// ne le porte pas, ce qui est voulu — une carte ne montre pas de fichiers.
///
/// **Le téléchargement passe par le `Dio` authentifié, jamais par le
/// navigateur.** `AssetDto.url` sort sur `/api/download/{visibilité}/…`, et
/// l'autorisation y est celle du contenu porteur : pour une équipe, une sortie
/// ou une annonce visibles des seuls membres, une requête sans jeton est
/// refusée. Confier l'URL au système ouvrirait un onglet sur une erreur 403.
/// Le fichier est donc rapporté puis remis au système par
/// `downloadAndShareAsset`, le même chemin que l'export GPX d'un parcours.
class MediaAttachments extends ConsumerStatefulWidget {
  const MediaAttachments({
    super.key,
    required this.attachments,
    this.spacingBefore = PdlSpacing.section,
  });

  final List<AssetDto> attachments;

  /// L'espace posé au-dessus du titre, absent avec le bloc lui-même.
  final double spacingBefore;

  @override
  ConsumerState<MediaAttachments> createState() => _MediaAttachmentsState();
}

class _MediaAttachmentsState extends ConsumerState<MediaAttachments> {
  /// L'identifiant du fichier en cours de rapatriement, nul au repos.
  String? _busyId;

  Object? _error;

  @override
  Widget build(BuildContext context) {
    final List<AssetDto> attachments = widget.attachments;
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(height: widget.spacingBefore),
        PdlSectionHeader(title: 'media.attachments'.tr()),
        // Un bandeau, pas un `SnackBar` : posé en bas d'écran il passerait sous
        // la barre d'onglets, comme pour les exports d'un parcours.
        if (_error != null) ...<Widget>[
          PdlBanner(
            tone: PdlBannerTone.danger,
            message: getErrorMessage(_error!),
            onDismiss: () => setState(() => _error = null),
            dismissSemanticLabel: 'common.close'.tr(),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
        ],
        if (_busyId != null) ...<Widget>[
          PdlBanner(
            tone: PdlBannerTone.info,
            message: 'media.downloading'.tr(),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
        ],
        for (int i = 0; i < attachments.length; i++)
          _AttachmentRow(
            asset: attachments[i],
            showDivider: i < attachments.length - 1,
            onDownload: () => _download(attachments[i]),
          ),
      ],
    );
  }

  /// Rapporte le fichier d'origine, puis le remet au système.
  ///
  /// Le partage est ce que la plateforme offre de plus proche d'un
  /// « enregistrer » : il mène à Fichiers, à une autre application, ou à un
  /// envoi. Un chemin dans un dossier temporaire, lui, ne mènerait nulle part.
  Future<void> _download(AssetDto asset) async {
    if (_busyId != null) return;
    setState(() {
      _busyId = asset.id;
      _error = null;
    });
    try {
      await downloadAndShareAsset(ref, asset, origin: shareOriginOf(context));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

/// Une ligne de fichier.
///
/// **Une image se regarde dans l'application**, pas dans le navigateur : le
/// serveur en sert des variantes redimensionnées par `imageUrl`, la visionneuse
/// est zoomable, et sortir de l'app pour voir une photo qu'on vient d'y charger
/// n'a pas de sens. Le bouton reste là pour ce que la visionneuse ne donne
/// pas : **le fichier d'origine**, dans sa définition entière.
///
/// Un fichier qui n'est pas une image n'a rien à afficher : sa ligne n'est pas
/// tapable, et seul son bouton agit.
///
/// Le sous-titre porte le poids puis, pour une image, ses dimensions :
/// « PDF · 240 ko », « JPG · 1,2 Mo · 1920 × 1080 » — de quoi choisir sans
/// ouvrir, et savoir avant de lancer un téléchargement en 3G.
/// `AssetDto.size` est nul tant que le serveur ne l'a pas relevé (ledger
/// `API-7`) : le poids est alors omis, jamais estimé.
class _AttachmentRow extends ConsumerWidget {
  const _AttachmentRow({
    required this.asset,
    required this.showDivider,
    required this.onDownload,
  });

  final AssetDto asset;
  final bool showDivider;
  final VoidCallback onDownload;

  bool get _isImage => asset.imageUrl != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PdlAttachmentRow(
      name: asset.fileName,
      type: _extension(asset.fileName) ?? asset.contentType,
      thumbnailUrl: asset.imageUrl,
      subtitle: _subtitle,
      icon: _isImage ? PdlIcons.image : PdlIcons.attachment,
      onTap: _isImage ? () => _view(context, ref) : null,
      onAction: onDownload,
      // **Le libellé nomme le fichier** : « Télécharger » répété douze fois
      // dans un lecteur d'écran ne permet pas de choisir. Et il dit
      // *l'originale* sur une image, puisque la ligne en montre déjà une
      // variante réduite et que la visionneuse en montre une autre.
      actionSemanticLabel:
          (_isImage ? 'media.downloadOriginal' : 'media.downloadAttachment').tr(
            namedArgs: <String, String>{'file': asset.fileName},
          ),
      showDivider: showDivider,
    );
  }

  /// « 240 ko · 1920 × 1080 », ce qui en est connu, ou rien.
  String? get _subtitle {
    final List<String> parts = <String>[
      if (asset.size case final int size) AppFormatters.formatFileSize(size),
      ?_dimensions,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// « 1920 × 1080 », ou rien : le contrat rend les deux côtés nullables
  /// séparément, et une moitié de dimension ne se montre pas.
  String? get _dimensions {
    final int? width = asset.imageDimensions?.width;
    final int? height = asset.imageDimensions?.height;
    if (width == null || height == null) return null;
    return '$width × $height';
  }

  void _view(BuildContext context, WidgetRef ref) {
    final ImageProvider? provider = AuthenticatedDecorationImage.fromUrl(
      asset.imageUrl,
      ref.read(accessTokenHolderProvider),
      // La plus grande variante : la visionneuse zoome, donc la vignette de la
      // ligne étirée sur toute la dalle se verrait.
      size: 1920,
    );
    if (provider == null) return;
    PdlImageViewer.show(
      context,
      imageProvider: provider,
      closeSemanticLabel: 'links.imageClose'.tr(),
      // La légende nomme le fichier : plusieurs photos se suivent souvent, et
      // rien d'autre à l'écran ne dit laquelle est ouverte. Elle se pose sur le
      // voile sombre de la visionneuse, dans les deux thèmes — d'où `onPrimary`
      // et non la couleur de texte courante, qui disparaîtrait en clair.
      caption: Text(
        asset.fileName,
        textAlign: TextAlign.center,
        style: context.pdlText.sub.copyWith(color: context.pdl.onPrimary),
      ),
    );
  }

  String? _extension(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    return fileName.substring(dot + 1);
  }
}
