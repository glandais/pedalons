import '../../../api/generated/export.dart';

/// Les fichiers d'un aperçu des outils GPX, sous la forme d'une pièce jointe
/// (docs/LEDGER_*.md MOB-178) : la feuille GPS et `deliverAsset` ne
/// connaissent que [AssetDto]. L'URL est celle du contrat (`gpxUrl`,
/// `fitUrl`), téléchargée par le Dio authentifié comme toute pièce jointe ;
/// le nom du fichier porte l'extension qui donne son vrai type MIME
/// (`application/gpx+xml`, `application/vnd.ant.fit`).
extension GpxPreviewAssets on GpxPreviewDto {
  AssetDto get gpxAsset => AssetDto(
    id: '$id-gpx',
    fileName: '${previewFileStem(name)}.gpx',
    contentType: 'application/gpx+xml',
    url: gpxUrl,
  );

  AssetDto get fitAsset => AssetDto(
    id: '$id-fit',
    fileName: '${previewFileStem(name)}.fit',
    contentType: 'application/vnd.ant.fit',
    url: fitUrl,
  );
}

/// Le nom d'un aperçu, privé de ce qu'un système de fichiers refuse ;
/// « parcours » s'il n'en reste rien.
String previewFileStem(String name) {
  final String stem = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return stem.isEmpty ? 'parcours' : stem;
}
