/// Un morceau du texte d'un commentaire : du texte brut, ou une adresse
/// complète à rendre en lien ([isLink]).
typedef CommentSegment = ({String text, bool isLink});

/// Une adresse complète : `http://` ou `https://`, jusqu'au premier blanc.
/// Rien d'autre ne se reconnaît — ni adresse sans schéma (« pedalons.fr »),
/// ni e-mail, ni mention (décision du 2026-11-12, KIT §9).
final RegExp _url = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// La ponctuation qui termine une phrase plutôt que l'adresse : « voir
/// https://x.fr. » ne lie pas le point.
const String _trailing = '.,;:!?\'"»”’…';

/// Découpe [content] en texte brut et en adresses complètes, dans l'ordre.
/// Concaténés, les morceaux redonnent [content] à l'identique : l'adresse
/// reste affichée en entier, rien n'est réécrit (règle R12, KIT §9).
List<CommentSegment> splitCommentLinks(String content) {
  final List<CommentSegment> out = <CommentSegment>[];
  int cursor = 0;
  for (final RegExpMatch m in _url.allMatches(content)) {
    final String url = _trimTrailing(m.group(0)!);
    // « https:// » seul n'est pas une adresse.
    if (url.length <= url.indexOf('//') + 2) continue;
    if (m.start > cursor) {
      out.add((text: content.substring(cursor, m.start), isLink: false));
    }
    out.add((text: url, isLink: true));
    cursor = m.start + url.length;
  }
  if (cursor < content.length) {
    out.add((text: content.substring(cursor), isLink: false));
  }
  return out;
}

String _trimTrailing(String url) {
  String s = url;
  while (s.isNotEmpty) {
    final String last = s[s.length - 1];
    if (_trailing.contains(last)) {
      s = s.substring(0, s.length - 1);
    } else if (last == ')' &&
        ')'.allMatches(s).length > '('.allMatches(s).length) {
      // « (voir https://x.fr) » : la parenthèse fermante est celle de la
      // phrase ; celle d'une adresse Wikipédia, appariée, reste.
      s = s.substring(0, s.length - 1);
    } else {
      break;
    }
  }
  return s;
}
