import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../api/generated/export.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/enum_colors.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/theme/pdl_typography.dart';
import '../../../keys.dart';

/// Les ids choisis, triés : deux sélections identiques faites dans un ordre
/// différent doivent donner **la même** clé de famille de liste, sinon elles
/// construiraient deux notifiers pour un seul jeu de résultats.
List<String> normalizeTagSelection(Iterable<String> ids) =>
    List<String>.unmodifiable(ids.toSet().toList()..sort());

/// Le libellé de la puce de filtre : « Tags » sans sélection, le libellé du
/// tag quand il n'y en a qu'un, « 3 tags » au-delà.
///
/// Un id choisi qui n'est plus au vocabulaire — supprimé entre-temps par un
/// admin — n'est pas compté : le serveur l'ignore aussi (D18).
String tagFilterLabel(List<TagWithUsageDto> vocabulary, List<String> selected) {
  final List<TagWithUsageDto> chosen = <TagWithUsageDto>[
    for (final TagWithUsageDto tag in vocabulary)
      if (selected.contains(tag.id)) tag,
  ];
  if (chosen.isEmpty) return 'tags.filter'.tr();
  if (chosen.length == 1) return chosen.single.label;
  return 'tags.filterCount'.plural(chosen.length);
}

/// La puce « Tags » d'une barre de filtres d'équipe (ledger `MOB-39`).
///
/// Elle ouvre [showTagPickerSheet] ; le filtre est un **OU** (D6), ce que la
/// feuille dit en une ligne. L'appelant ne la pose que si [vocabulary] n'est
/// pas vide : sans tag pour ce type, pas de filtre (plan des tags §5).
class TagFilterChip extends StatelessWidget {
  const TagFilterChip({
    super.key,
    required this.vocabulary,
    required this.selected,
    required this.onChanged,
  });

  final List<TagWithUsageDto> vocabulary;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return PdlChip(
      key: keys.tags.filterChip,
      icon: PdlIcons.tag,
      label: tagFilterLabel(vocabulary, selected),
      selected: vocabulary.any((TagWithUsageDto t) => selected.contains(t.id)),
      onTap: () async {
        final List<String>? next = await showTagPickerSheet(
          context,
          vocabulary: vocabulary,
          selected: selected,
        );
        if (next != null && !listEquals(next, selected)) onChanged(next);
      },
    );
  }
}

/// Ouvre la feuille de choix des tags et rend la sélection à appliquer,
/// triée ([normalizeTagSelection]), ou `null` si elle a été fermée sans
/// valider.
///
/// Sans [title] ni [hint], c'est la feuille du **filtre** ; l'éditeur de
/// sortie la réutilise pour étiqueter, avec ses propres libellés et la limite
/// du contrat ([maxSelected], `RideRequest.tagIds` : 10).
Future<List<String>?> showTagPickerSheet(
  BuildContext context, {
  required List<TagWithUsageDto> vocabulary,
  required List<String> selected,
  String? title,
  String? hint,
  int? maxSelected,
}) {
  return PdlSheet.show<List<String>>(
    context: context,
    builder: (BuildContext context) => _TagPickerSheet(
      vocabulary: vocabulary,
      initial: selected,
      title: title,
      hint: hint,
      maxSelected: maxSelected,
    ),
  );
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({
    required this.vocabulary,
    required this.initial,
    this.title,
    this.hint,
    this.maxSelected,
  });

  final List<TagWithUsageDto> vocabulary;
  final List<String> initial;
  final String? title;
  final String? hint;
  final int? maxSelected;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  // Seuls les ids encore au vocabulaire entrent dans le brouillon : valider
  // la feuille purge ainsi un tag supprimé depuis.
  late final Set<String> _draft = <String>{
    for (final TagWithUsageDto tag in widget.vocabulary)
      if (widget.initial.contains(tag.id)) tag.id,
  };

  void _toggle(String id) => setState(() {
    if (_draft.remove(id)) return;
    final int? max = widget.maxSelected;
    if (max != null && _draft.length >= max) return;
    _draft.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return PdlSheet(
      title: widget.title ?? 'tags.pickerTitle'.tr(),
      headerAction: _draft.isEmpty
          ? null
          : PdlButton(
              key: keys.tags.pickerClear,
              label: 'tags.clear'.tr(),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => setState(_draft.clear),
            ),
      bodyPadding: EdgeInsets.zero,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PdlButton(
            key: keys.tags.pickerApply,
            fullWidth: true,
            label: 'tags.apply'.tr(),
            onPressed: () =>
                Navigator.of(context).pop(normalizeTagSelection(_draft)),
          ),
        ),
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            0,
            PdlSpacing.section,
            PdlSpacing.chipGap,
          ),
          child: Text(widget.hint ?? 'tags.pickerHint'.tr(), style: t.xs),
        ),
        for (final TagWithUsageDto tag in widget.vocabulary)
          _TagPickerRow(
            key: keys.tags.pickerRow(tag.id),
            label: tag.label,
            color: tagFamily(tag.color).soft(c).fill,
            selected: _draft.contains(tag.id),
            onTap: () => _toggle(tag.id),
          ),
      ],
    );
  }
}

/// Une ligne de la feuille : pastille, libellé, coche. 44 px au moins.
class _TagPickerRow extends StatelessWidget {
  const _TagPickerRow({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PdlSpacing.section,
              vertical: 8,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: PdlSpacing.cardTight),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: selected ? t.bodyStrong : t.body,
                  ),
                ),
                if (selected) Icon(PdlIcons.check, size: 20, color: c.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
