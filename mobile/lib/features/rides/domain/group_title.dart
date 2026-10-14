/// Le titre d'un groupe de sortie à partir du gabarit traduit [template]
/// (« Groupe {name} ») : le nom seul quand il commence déjà par le mot du
/// gabarit — un club qui nomme ses groupes « Groupe A » ne lit pas
/// « Groupe Groupe A ». La comparaison ignore la casse et exige un mot
/// entier : « Groupement » garde son préfixe.
String groupTitle(String name, String template) {
  final String prefix = template.split('{name}').first.trim();
  final String trimmed = name.trim();
  if (prefix.isNotEmpty) {
    final String head = trimmed.toLowerCase();
    final String word = prefix.toLowerCase();
    if (head == word || head.startsWith('$word ')) return trimmed;
  }
  return template.replaceAll('{name}', trimmed);
}
