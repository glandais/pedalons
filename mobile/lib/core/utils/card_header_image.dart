import '../../api/generated/export.dart';

/// La première photo d'un contenu (`media.assets.images`), ou `null`.
///
/// Une ligne de liste, même compacte, porte cette première image : la carte
/// n'a besoin de rien d'autre. Une image sans variante affichable
/// (`imageUrl` absent) ne compte pas.
String? firstPhotoUrl(MediaDto? media) {
  if (media == null) return null;
  for (final AssetDto image in media.assets.images) {
    final String? url = image.imageUrl;
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}

/// Ce qu'une carte montre en tête, et la vignette du tracé qu'elle garde
/// (règle R10, KIT §9, docs/LEDGER_*.md MOB-139).
///
/// * [banner] : la photo du contenu si elle existe, sinon la carte du tracé,
///   sinon `null` — la carte pose alors son dégradé.
/// * [trackThumbnail] : la carte du tracé en vignette, **seulement** quand le
///   bandeau est une photo. Quand le bandeau est déjà la carte du tracé, la
///   vignette la répéterait.
typedef CardHeaderImage = ({String? banner, String? trackThumbnail});

/// Résout la règle R10 pour une carte : [photo] (la première photo,
/// [firstPhotoUrl]) puis [trackMap] (la vignette thémée du tracé).
CardHeaderImage cardHeaderImage({String? photo, String? trackMap}) =>
    photo != null
    ? (banner: photo, trackThumbnail: trackMap)
    : (banner: trackMap, trackThumbnail: null);
