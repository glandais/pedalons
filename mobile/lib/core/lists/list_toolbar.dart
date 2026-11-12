import 'package:easy_localization/easy_localization.dart';

import '../material.dart';

import '../pdl/pdl.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import '../utils/formatters.dart';

// Les pièces de barre communes aux listes de l'app (règles RL8, RL9 et RL13,
// KIT §10) : le bouton « Créer » à droite de la recherche, le contrôle de vue
// à icônes sur la ligne du compteur, et cette ligne elle-même. Une liste ne
// compose plus les siennes : elle les prend ici, et c'est ce qui les garde
// semblables d'une liste à l'autre.

/// RL13 — le bouton court « Créer » de la barre, à droite de la recherche,
/// pour qui a le droit de créer l'objet de la liste.
///
/// Le texte visible reste court pour ne pas tronquer la recherche ; le lecteur
/// d'écran lit le nom complet ([semanticLabel] : « Créer une sortie »), le même
/// que porte le bouton de l'état vide.
class ListCreateButton extends StatelessWidget {
  const ListCreateButton({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
  });

  /// « Créer une sortie », « Créer un parcours », « Créer un modèle ».
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    button: true,
    onTap: onPressed,
    child: PdlButton(
      label: 'lists.create'.tr(),
      icon: PdlIcons.add,
      size: PdlButtonSize.sm,
      onPressed: onPressed,
    ),
  );
}

/// RL13 — le même geste dans le vide simple : bouton plein, nom complet.
class ListEmptyCreateButton extends StatelessWidget {
  const ListEmptyCreateButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      PdlButton(label: label, icon: PdlIcons.add, onPressed: onPressed);
}

/// Les vues qu'une liste peut offrir, sous les mêmes noms qu'au site
/// (`listView.*`) : « Vignettes · Lignes · Carte » aux parcours, « Vignettes ·
/// Lignes · Calendrier » à l'agenda.
enum ListViewKind { cards, rows, map, calendar }

IconData _viewIcon(ListViewKind kind) => switch (kind) {
  ListViewKind.cards => PdlIcons.cards,
  ListViewKind.rows => PdlIcons.list,
  ListViewKind.map => PdlIcons.map,
  ListViewKind.calendar => PdlIcons.calendar,
};

String listViewLabel(ListViewKind kind) => 'lists.view.${kind.name}'.tr();

/// RL9 — **le seul** contrôle de vue d'une liste : des icônes, chacune nommée
/// pour le lecteur d'écran, le groupe nommé « Affichage ».
class ListViewSwitch extends StatelessWidget {
  const ListViewSwitch({
    super.key,
    required this.views,
    required this.value,
    required this.onChanged,
    this.segmentKey,
  });

  final List<ListViewKind> views;
  final ListViewKind value;
  final ValueChanged<ListViewKind> onChanged;

  /// La clé du segment d'une vue, pour les tests.
  final Key Function(ListViewKind kind)? segmentKey;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'lists.view.label'.tr(),
    child: SizedBox(
      width:
          PdlMetrics.tapTarget * views.length +
          PdlSpacing.badgeGap * (views.length - 1) +
          6,
      child: PdlSegmented<ListViewKind>(
        value: value,
        onChanged: onChanged,
        segments: <PdlSegment<ListViewKind>>[
          for (final ListViewKind kind in views)
            PdlSegment<ListViewKind>(
              key: segmentKey?.call(kind),
              value: kind,
              label: listViewLabel(kind),
              icon: _viewIcon(kind),
              iconOnly: true,
            ),
        ],
      ),
    ),
  );
}

/// RL8 et RL9 — la ligne sous la barre : le compteur à gauche (« 47
/// parcours »), le contrôle de vue à droite. Sans compteur — à zéro, en vue
/// carte, ou quand des sections portent chacune le leur —, le contrôle reste
/// seul à droite.
class ListCountRow extends StatelessWidget {
  const ListCountRow({super.key, this.count, this.countKey, this.viewSwitch});

  final String? count;
  final Key? countKey;
  final Widget? viewSwitch;

  @override
  Widget build(BuildContext context) {
    if (count == null && viewSwitch == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.chipGap,
        PdlSpacing.section,
        4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: count == null
                ? const SizedBox.shrink()
                : Text(count!, key: countKey, style: context.pdlText.count),
          ),
          ?viewSwitch,
        ],
      ),
    );
  }
}

/// RL15 — l'en-tête d'une section d'une liste datée : « À venir » ou « Plus
/// tôt » à gauche, son compteur à droite (« 18 sorties et voyages »).
class ListSectionHeader extends StatelessWidget {
  const ListSectionHeader({
    super.key,
    required this.title,
    required this.nounKey,
    required this.total,
  });

  final String title;

  /// Le nom de ce qui est compté, à formes `one` / `other`.
  final String nounKey;
  final int total;

  @override
  Widget build(BuildContext context) => PdlSectionHeader(
    title: title,
    count: countWithNoun(nounKey, total),
    padding: const EdgeInsets.fromLTRB(
      PdlSpacing.section,
      PdlSpacing.section,
      PdlSpacing.section,
      PdlSpacing.chipGap,
    ),
  );
}

/// « 18 sorties et voyages » : le nombre formaté, le nom ([nounKey], à formes
/// `one` / `other`) accordé.
String countWithNoun(String nounKey, int total) => 'lists.countNamed'.tr(
  namedArgs: <String, String>{
    'count': AppFormatters.formatNumber(total),
    'noun': nounKey.plural(total),
  },
);
