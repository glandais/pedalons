import 'package:flutter/services.dart';

/// Les gestes de la barre d'outils markdown de l'éditeur de sortie, en
/// fonctions pures sur un [TextEditingValue] (docs/LEDGER_*.md MOB-76).
///
/// **Le texte reste du markdown brut**, celui que le site écrit avec Tiptap :
/// un éditeur riche mobile passerait par son propre modèle et réécrirait, à
/// l'enregistrement, ce que le site a produit — tableaux, et surtout les
/// directives `::asset{id="…"}` qui placent les images dans le texte.

/// Entoure la sélection de [marker] (`**`, `_`) ; sans sélection, insère la
/// paire et place le curseur entre les deux.
TextEditingValue wrapSelection(TextEditingValue value, String marker) {
  final TextSelection sel = _normalized(value);
  final String text = value.text;
  final String selected = sel.textInside(text);
  final String next =
      sel.textBefore(text) + marker + selected + marker + sel.textAfter(text);
  final int start = sel.start + marker.length;
  return TextEditingValue(
    text: next,
    selection: selected.isEmpty
        ? TextSelection.collapsed(offset: start)
        : TextSelection(
            baseOffset: start,
            extentOffset: start + selected.length,
          ),
  );
}

/// Préfixe de [prefix] (`## `, `- `, `1. `, `> `) chaque ligne touchée par la
/// sélection ; une ligne qui le porte déjà le perd — le bouton bascule.
TextEditingValue toggleLinePrefix(TextEditingValue value, String prefix) {
  final TextSelection sel = _normalized(value);
  final String text = value.text;
  final int lineStart = sel.start == 0
      ? 0
      : text.lastIndexOf('\n', sel.start - 1) + 1;
  int lineEnd = text.indexOf('\n', sel.end);
  if (lineEnd < 0) lineEnd = text.length;

  final List<String> lines = text.substring(lineStart, lineEnd).split('\n');
  final bool remove = lines.every((String l) => l.startsWith(prefix));
  final List<String> changed = <String>[
    for (final String line in lines)
      remove ? line.substring(prefix.length) : prefix + line,
  ];
  final String block = changed.join('\n');
  final int delta = block.length - (lineEnd - lineStart);
  final String next =
      text.substring(0, lineStart) + block + text.substring(lineEnd);
  // Le curseur suit la première ligne : décalé d'un préfixe, pas plus.
  final int shift = remove ? -prefix.length : prefix.length;
  final int base = (sel.start + shift).clamp(
    lineStart,
    lineStart + block.length,
  );
  final int extent = (sel.end + delta).clamp(base, next.length);
  return TextEditingValue(
    text: next,
    selection: TextSelection(baseOffset: base, extentOffset: extent),
  );
}

/// Remplace la sélection par `[texte](url)` — le texte sélectionné, sinon
/// [label] — et place le curseur après.
TextEditingValue insertLink(
  TextEditingValue value, {
  required String url,
  String label = '',
}) {
  final TextSelection sel = _normalized(value);
  final String selected = sel.textInside(value.text);
  final String shown = selected.isNotEmpty
      ? selected
      : (label.isNotEmpty ? label : url);
  return insertText(value, '[$shown]($url)');
}

/// Insère [snippet] à la place de la sélection, curseur après.
TextEditingValue insertText(TextEditingValue value, String snippet) {
  final TextSelection sel = _normalized(value);
  final String text = value.text;
  final String next = sel.textBefore(text) + snippet + sel.textAfter(text);
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: sel.start + snippet.length),
  );
}

/// Insère [directive] (`::asset{…}`) **sur sa propre ligne** : une directive
/// de feuille doit tenir seule sur la sienne pour que `remark-directive` la
/// lise au site.
TextEditingValue insertBlock(TextEditingValue value, String directive) {
  final TextSelection sel = _normalized(value);
  final String before = sel.textBefore(value.text);
  final String after = sel.textAfter(value.text);
  final String lead = before.isEmpty || before.endsWith('\n') ? '' : '\n';
  final String trail = after.startsWith('\n') ? '' : '\n';
  return insertText(value, '$lead$directive$trail');
}

/// La directive d'une image envoyée, au format du site
/// (`createAssetDirective` : `size` omis quand c'est le défaut `medium`).
/// [alt] est rendu sûr comme au site (`directiveValue`) : aucun lecteur ne
/// décode d'échappement, les caractères qui fermeraient la valeur ou la
/// directive sont remplacés par des sosies.
String assetDirective(String assetId, {String alt = ''}) {
  final String safeAlt = alt
      .replaceAll('"', "'")
      .replaceAll('{', '(')
      .replaceAll('}', ')')
      .replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ')
      .trim();
  return safeAlt.isEmpty
      ? '::asset{id="$assetId"}'
      : '::asset{id="$assetId" alt="$safeAlt"}';
}

/// Retire du texte toute directive qui nomme [assetId] — une image ôtée de
/// la liste ne doit pas laisser de référence morte dans la description.
String removeAssetDirectives(String markdown, String assetId) {
  return markdown.replaceAll(
    RegExp(
      r'[ \t]*::asset\{[^}]*id="' +
          RegExp.escape(assetId) +
          r'"[^}]*\}[ \t]*\n?',
    ),
    '',
  );
}

/// Une sélection invalide (champ jamais focalisé : -1) vaut « à la fin ».
TextSelection _normalized(TextEditingValue value) {
  final TextSelection sel = value.selection;
  if (!sel.isValid) return TextSelection.collapsed(offset: value.text.length);
  return TextSelection(
    baseOffset: sel.start.clamp(0, value.text.length),
    extentOffset: sel.end.clamp(0, value.text.length),
  );
}
