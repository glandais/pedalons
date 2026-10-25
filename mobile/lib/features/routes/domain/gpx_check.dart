import 'package:flutter/foundation.dart';

import 'route_form.dart';

/// Taille maximale d'un GPX acceptée par le serveur
/// (`GpxLimits.MAX_GPX_SIZE_BYTES`) : 10 Mio. Au-delà, l'envoi serait refusé
/// (`FILE_TOO_LARGE`) après avoir coûté tout le téléversement.
const int kGpxMaxBytes = 10 * 1024 * 1024;

/// Combien d'octets du début du fichier on lit pour le reconnaître et en tirer
/// le nom : l'en-tête d'un GPX (balise `<gpx>`, `<metadata>`, début de la
/// première trace) tient très en deçà, et ce plafond évite de charger 10 Mio
/// en mémoire pour un contrôle local.
const int kGpxProbeBytes = 512 * 1024;

/// Un fichier choisi par l'utilisateur, avant tout envoi (docs/LEDGER_*.md
/// MOB-79).
@immutable
class GpxFile {
  const GpxFile({required this.path, required this.name, required this.size});

  /// Le chemin local, lisible par l'app (copie temporaire du sélecteur).
  final String path;

  /// Le nom d'origine, extension comprise — c'est lui qu'on montre et qu'on
  /// envoie.
  final String name;

  /// La taille en octets.
  final int size;

  @override
  bool operator ==(Object other) =>
      other is GpxFile &&
      other.path == path &&
      other.name == name &&
      other.size == size;

  @override
  int get hashCode => Object.hash(path, name, size);

  @override
  String toString() => 'GpxFile($name, $size o)';
}

/// Pourquoi un fichier n'est pas un GPX acceptable.
enum GpxRefusal {
  /// Ni l'extension ni le contenu d'un GPX.
  notGpx,

  /// Un GPX lisible, mais sans aucune trace (refus du serveur).
  empty,

  /// Plus gros que [kGpxMaxBytes].
  tooLarge,

  /// Un tracé trop long pour un parcours (refus du serveur).
  tooLong,
}

/// Le verdict du contrôle local d'un fichier.
sealed class GpxCheck {
  const GpxCheck();
}

/// Un fichier qui a l'air d'un GPX. [trackName] est le nom que le fichier se
/// donne (`<metadata>` ou première `<trk>`), `null` s'il n'en a pas.
final class GpxAccepted extends GpxCheck {
  const GpxAccepted(this.file, {this.trackName});

  final GpxFile file;
  final String? trackName;
}

/// Un fichier refusé, avec le nom à citer dans le message.
final class GpxRefused extends GpxCheck {
  const GpxRefused(this.fileName, this.refusal);

  final String fileName;
  final GpxRefusal refusal;
}

/// Une balise ouvrante `<gpx …>`, préfixe d'espace de noms toléré.
final RegExp _gpxRoot = RegExp(r'<(?:[A-Za-z_][\w.-]*:)?gpx[\s>/]');

/// Le contrôle local : extension `.gpx` (casse indifférente), taille, et un
/// contenu XML qui ouvre un élément `<gpx`. [head] est le début du fichier,
/// déjà décodé (voir `inspectGpxFile`).
///
/// Ce n'est qu'un garde-fou pour répondre tout de suite : le serveur reste
/// seul juge du contenu (`GPX_FAILURE`, `GPX_EMPTY`…).
GpxCheck checkGpx(GpxFile file, String head) {
  if (file.size > kGpxMaxBytes) {
    return GpxRefused(file.name, GpxRefusal.tooLarge);
  }
  if (!file.name.toLowerCase().endsWith('.gpx')) {
    return GpxRefused(file.name, GpxRefusal.notGpx);
  }
  if (!_gpxRoot.hasMatch(head)) {
    return GpxRefused(file.name, GpxRefusal.notGpx);
  }
  return GpxAccepted(file, trackName: gpxTrackName(head));
}

const String _ns = r'(?:[A-Za-z_][\w.-]*:)?';

final RegExp _metadataBlock = RegExp(
  '<${_ns}metadata[\\s>].*?</${_ns}metadata\\s*>',
  dotAll: true,
);

/// Dans `<metadata>`, les blocs dont le `<name>` n'est pas celui du fichier :
/// l'auteur, le copyright, les liens.
final RegExp _metadataForeignBlocks = RegExp(
  '<($_ns(?:author|copyright|link))[\\s>].*?</\\1\\s*>',
  dotAll: true,
);

final RegExp _trkOpen = RegExp('<${_ns}trk[\\s>]');
final RegExp _trkEnd = RegExp('<${_ns}trkseg[\\s>/]|</${_ns}trk\\s*>');

final RegExp _nameElement = RegExp(
  '<${_ns}name(?:\\s[^>]*?)?(?<!/)>(.*?)</${_ns}name\\s*>',
  dotAll: true,
);

final RegExp _cdata = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true);
final RegExp _entity = RegExp(
  r'&(amp|lt|gt|quot|apos|#\d+|#[xX][0-9a-fA-F]+);',
);

/// Le nom que le GPX se donne : le `<name>` de son bloc `<metadata>`, sinon
/// celui de sa première `<trk>` (entre l'ouverture de la trace et son premier
/// segment). Jamais le nom d'un `<wpt>` ou d'une `<rte>` qui précéderait.
/// `null` si aucun, ou s'il est vide.
String? gpxTrackName(String head) {
  final RegExpMatch? metadata = _metadataBlock.firstMatch(head);
  if (metadata != null) {
    final String own = metadata
        .group(0)!
        .replaceAll(_metadataForeignBlocks, '');
    final String? fromMetadata = _firstName(own);
    if (fromMetadata != null) return fromMetadata;
  }

  final RegExpMatch? trk = _trkOpen.firstMatch(head);
  if (trk == null) return null;
  final String afterTrk = head.substring(trk.end);
  final RegExpMatch? end = _trkEnd.firstMatch(afterTrk);
  return _firstName(end == null ? afterTrk : afterTrk.substring(0, end.start));
}

String? _firstName(String xml) {
  final RegExpMatch? match = _nameElement.firstMatch(xml);
  if (match == null) return null;
  final String name = _unescape(match.group(1)!)
      .replaceAll(RegExp(r'\s+'), ' ');
  final String trimmed = name.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Déroule les sections CDATA (contenu pris tel quel) et décode les entités du
/// reste.
String _unescape(String raw) {
  final StringBuffer out = StringBuffer();
  int cursor = 0;
  for (final RegExpMatch m in _cdata.allMatches(raw)) {
    out.write(_decodeEntities(raw.substring(cursor, m.start)));
    out.write(m.group(1));
    cursor = m.end;
  }
  out.write(_decodeEntities(raw.substring(cursor)));
  return out.toString();
}

String _decodeEntities(String text) =>
    text.replaceAllMapped(_entity, (Match m) {
      final String body = m.group(1)!;
      switch (body) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final bool hex = body.startsWith('#x') || body.startsWith('#X');
      final int? code = int.tryParse(
        body.substring(hex ? 2 : 1),
        radix: hex ? 16 : 10,
      );
      // Un point de code invalide reste tel quel plutôt que de lever.
      if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    });

/// Le nom à proposer pour le parcours : celui que le GPX se donne s'il fait au
/// moins [kRouteNameMinLength] caractères, sinon le nom du fichier sans son
/// extension `.gpx`. Tronqué à [kRouteNameMaxLength].
String suggestedRouteName(GpxAccepted accepted) {
  final String? track = accepted.trackName;
  String name;
  if (track != null && track.length >= kRouteNameMinLength) {
    name = track;
  } else {
    final String file = accepted.file.name;
    name = file.toLowerCase().endsWith('.gpx')
        ? file.substring(0, file.length - '.gpx'.length)
        : file;
    name = name.trim();
  }
  if (name.length <= kRouteNameMaxLength) return name;
  int end = kRouteNameMaxLength;
  // Ne pas couper une paire de substitution en deux.
  final int last = name.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return name.substring(0, end);
}

/// Le refus que dit un code d'erreur du serveur, `null` pour un autre échec
/// (réseau, droits…) qui n'est pas la faute du fichier.
GpxRefusal? gpxRefusalOfApiCode(String? code) => switch (code) {
  'GPX_FAILURE' ||
  'FILE_TYPE_REJECTED' ||
  'FILE_DETECTION_FAILED' => GpxRefusal.notGpx,
  'GPX_EMPTY' => GpxRefusal.empty,
  'GPX_TOO_LONG' => GpxRefusal.tooLong,
  'FILE_TOO_LARGE' => GpxRefusal.tooLarge,
  _ => null,
};
