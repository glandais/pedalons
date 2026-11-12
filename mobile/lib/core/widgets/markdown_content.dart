import 'dart:async';

import 'package:easy_localization/easy_localization.dart';

import '../../api/generated/models/asset_dto.dart';
import '../material.dart';
import '../pdl/pdl_markdown_body.dart';
import '../utils/link_launcher.dart';

/// Pre-processes markdown by resolving `::asset{id="..." size="..." alt="..."}`
/// directives into standard `![alt](url)` markdown image syntax.
String _resolveAssetDirectives(String data, List<AssetDto> images) {
  return data.replaceAllMapped(RegExp(r'::asset\{([^}]+)\}'), (match) {
    final attrs = _parseAttrs(match.group(1) ?? '');
    final id = attrs['id'];
    if (id == null || id.isEmpty) return '';

    final alt = attrs['alt'] ?? '';

    final asset = _findAsset(images, id);
    if (asset == null) return alt;

    // **Le gabarit `{size}` est laissé intact.** Le figer ici à la largeur
    // rédigée coûtait le plein écran : la visionneuse redemande la variante
    // 1920 en substituant `{size}`, et sur une URL déjà résolue en 448 elle
    // reservait ce même 448, étiré sur toute la dalle. Le rendu en ligne
    // résout le gabarit de son côté (`AuthenticatedImage`), et la hauteur de
    // 160 px de `PdlMarkdownBody` rend de toute façon la largeur rédigée sans
    // effet visible sur mobile.
    final url = asset.imageUrl ?? asset.url;
    return '![$alt]($url)';
  });
}

Map<String, String> _parseAttrs(String input) {
  final result = <String, String>{};
  for (final m in RegExp(r'(\w+)="([^"]*)"').allMatches(input)) {
    result[m.group(1)!] = m.group(2)!;
  }
  return result;
}

AssetDto? _findAsset(List<AssetDto> images, String id) {
  for (final asset in images) {
    if (asset.id == id) return asset;
  }
  return null;
}

/// Rend un contenu markdown avec la feuille de style unique de la charte.
///
/// Ce n'est plus qu'une **façade** : le rendu appartient à [PdlMarkdownBody]
/// (B24). Ce qui reste ici est ce que `core/pdl` ne peut pas connaître — les
/// directives `::asset{id="..." size="..." alt="..."}`, qui se résolvent
/// contre des [AssetDto].
///
/// Comme [PdlMarkdownBody], il se dimensionne à son contenu et ne défile
/// jamais : le défilement appartient à la page, ce qui garde son
/// `ScrollController` attaché au `PrimaryScrollController` — iOS en a besoin
/// pour le tap sur la barre d'état (`Scaffold.handleStatusBarTap`).
///
/// C'est **ici** que les liens deviennent actifs (F-TE-10) : la façade branche
/// `onLinkTap` sur `openLink`, qui sait pousser une route interne, passer la
/// main au système, et — jamais silencieusement — afficher un bandeau quand ni
/// l'un ni l'autre n'est possible. Aucun écran ne doit instancier
/// [PdlMarkdownBody] directement, sous peine de retrouver le lien inerte que
/// cette tâche corrige.
class MarkdownContent extends StatelessWidget {
  final String data;
  final List<AssetDto> images;

  const MarkdownContent({
    super.key,
    required this.data,
    this.images = const [],
  });

  @override
  Widget build(BuildContext context) {
    final processedData = images.isEmpty
        ? data
        : _resolveAssetDirectives(data, images);

    return PdlMarkdownBody(
      data: processedData,
      onLinkTap: (String href) => unawaited(openLink(context, href)),
      codeCopiedLabel: 'links.codeCopied'.tr(),
      imageCloseLabel: 'links.imageClose'.tr(),
    );
  }
}
