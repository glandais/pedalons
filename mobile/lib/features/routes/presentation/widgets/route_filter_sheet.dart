import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../domain/route_filter_labels.dart';
import '../../domain/route_filters.dart';
import '../../providers/route_count_provider.dart';
import '../../providers/route_tags_provider.dart';

/// Opens the filter sheet and returns the filters to apply, or null if the
/// user dismissed it.
///
/// The sheet edits a draft copy: nothing reaches the list until
/// "Voir N parcours" is tapped.
/// F-DE-8 : l'ouverture passe par [PdlSheet.show], qui force
/// `useRootNavigator: true`. Sans lui la feuille naissait dans le navigateur
/// de la branche courante — c'est-à-dire *sous* la barre d'onglets, qui lui
/// passait devant et mangeait son bouton de validation.
Future<RouteFilters?> showRouteFilterSheet(
  BuildContext context, {
  required RouteFilters filters,
}) {
  return PdlSheet.show<RouteFilters>(
    context: context,
    builder: (context) => _RouteFilterSheet(initial: filters),
  );
}

/// Opens the sort picker on its own, for the sort chip above the list.
Future<({RouteSortBy by, SortDirection dir})?> showRouteSortSheet(
  BuildContext context, {
  required RouteSortBy sortBy,
  required SortDirection sortDir,
}) {
  return PdlSheet.show<({RouteSortBy by, SortDirection dir})>(
    context: context,
    builder: (context) => _SortSheet(sortBy: sortBy, sortDir: sortDir),
  );
}

class _RouteFilterSheet extends ConsumerStatefulWidget {
  final RouteFilters initial;

  const _RouteFilterSheet({required this.initial});

  @override
  ConsumerState<_RouteFilterSheet> createState() => _RouteFilterSheetState();
}

class _RouteFilterSheetState extends ConsumerState<_RouteFilterSheet> {
  late RouteFilters _draft = widget.initial;

  /// Last count the server confirmed, kept on screen while the next one is in
  /// flight so the button label does not flicker on every slider move.
  int? _lastCount;

  void _update(RouteFilters next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    // S21-2 : le CTA annonce le compte **du serveur**, pas une estimation.
    // La famille débounce elle-même, si bien que glisser un curseur ne part
    // pas compter à chaque pixel.
    final countProvider = routeCountProvider(_draft);
    ref.listen(countProvider, (_, next) {
      final value = next.value;
      if (value != null) _lastCount = value;
    });
    final count = ref.watch(countProvider).value ?? _lastCount;
    final units = ref.watch(unitSystemProvider);
    final List<TagWithUsageDto> tags = routeTagVocabulary(ref, _draft);

    // F-DE-5 : le corps était un `Column` dans un `SingleChildScrollView`
    // dans un `Flexible`, sous un parent `MainAxisSize.min`, avec le CTA hors
    // du défilement. La dernière ligne — « Trier par » — se retrouvait écrasée
    // à 1 pt : elle existait, elle était même tapable, mais elle n'était plus
    // lisible ni atteignable. Le gabarit `PdlSheet` est le seul qui ne puisse
    // pas s'effondrer : en-tête fixe, corps *borné et défilant*, pied fixe.
    return PdlSheet(
      header: Text(
        'routes.filters.title'.tr(),
        style: context.pdlText.sectionTitle,
      ),
      // Le même geste que le vide filtré (règle RL4) : « Effacer les
      // filtres » lève tout ce que la pastille compte, et garde le tri.
      headerAction: _draft.activeCount == 0
          ? null
          : PdlButton(
              key: keys.routes.filterClearButton,
              label: 'common.clearFilters'.tr(),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => _update(_draft.cleared),
            ),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PdlButton(
            key: keys.routes.filterApplyButton,
            fullWidth: true,
            label: count == null
                ? 'routes.filters.applyUnknown'.tr()
                : 'routes.filters.apply'.plural(count),
            onPressed: () => Navigator.of(context).pop(_draft),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La feuille ne garde que les critères : le tri est la puce
              // visible en tête de la rangée, hors de la feuille (règle RL6).
              _RangeSection(
                label: 'routes.filters.distance'.tr(),
                summary: RouteFilterLabels.filterRange(
                  _draft.minDistance,
                  _draft.maxDistance,
                  (meters) =>
                      AppFormatters.formatDistanceRounded(meters, units),
                ),
                min: _draft.minDistance,
                max: _draft.maxDistance,
                upperBound: kRouteDistanceMaxMeters,
                step: kRouteDistanceStepMeters,
                onChanged: (min, max) => _update(
                  _draft.copyWith(minDistance: min, maxDistance: max),
                ),
              ),
              const SizedBox(height: 20),
              _RangeSection(
                label: 'routes.filters.elevationGain'.tr(),
                summary: RouteFilterLabels.filterRange(
                  _draft.minElevationGain,
                  _draft.maxElevationGain,
                  (meters) => AppFormatters.formatElevation(meters, units),
                ),
                min: _draft.minElevationGain,
                max: _draft.maxElevationGain,
                upperBound: kRouteElevationMaxMeters,
                step: kRouteElevationStepMeters,
                onChanged: (min, max) => _update(
                  _draft.copyWith(minElevationGain: min, maxElevationGain: max),
                ),
              ),
              const SizedBox(height: 20),
              _ChoiceSection<SurfaceType>(
                label: 'routes.filters.surfaceType'.tr(),
                values: SurfaceType.$valuesDefined,
                selected: _draft.surfaceType,
                labelOf: RouteFilterLabels.surfaceTypeName,
                onSelected: (value) =>
                    _update(_draft.copyWith(surfaceType: value)),
              ),
              const SizedBox(height: 20),
              _ChoiceSection<Hilliness>(
                label: 'routes.filters.hilliness'.tr(),
                values: Hilliness.$valuesDefined,
                selected: _draft.hilliness,
                labelOf: RouteFilterLabels.hillinessName,
                onSelected: (value) =>
                    _update(_draft.copyWith(hilliness: value)),
              ),
              const SizedBox(height: 12),
              // La direction du vent reste d'un niveau plus bas : c'est le
              // filtre le moins souvent posé.
              _NavigationRow(
                label: 'routes.filters.windDirection'.tr(),
                value: _draft.windDirection == null
                    ? 'routes.filters.anyFeminine'.tr()
                    : RouteFilterLabels.windDirectionName(
                        _draft.windDirection!,
                      ),
                onTap: _pickWindDirection,
              ),
              // Les tags de parcours de l'équipe, en OU (ledger `MOB-39`). La
              // ligne n'existe que si l'équipe en a.
              if (tags.isNotEmpty)
                _NavigationRow(
                  label: 'tags.filter'.tr(),
                  value: _draft.tagIds.isEmpty
                      ? 'routes.filters.any'.tr()
                      : tagFilterLabel(tags, _draft.tagIds),
                  onTap: () => _pickTags(tags),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickWindDirection() async {
    final result = await PdlSheet.show<_Optional<WindDirection>>(
      context: context,
      builder: (context) => _OptionSheet<WindDirection>(
        title: 'routes.filters.windDirection'.tr(),
        anyLabel: 'routes.filters.anyFeminine'.tr(),
        values: WindDirection.$valuesDefined,
        selected: _draft.windDirection,
        labelOf: RouteFilterLabels.windDirectionName,
      ),
    );
    if (result != null) _update(_draft.copyWith(windDirection: result.value));
  }

  Future<void> _pickTags(List<TagWithUsageDto> tags) async {
    final List<String>? result = await showTagPickerSheet(
      context,
      vocabulary: tags,
      selected: _draft.tagIds,
    );
    if (result != null) _update(_draft.copyWith(tagIds: result));
  }
}

/// A min/max range over a slider, where either end sitting on its bound means
/// "unbounded" and is reported back as null.
class _RangeSection extends StatelessWidget {
  final String label;
  final String summary;
  final double? min;
  final double? max;
  final double upperBound;
  final double step;
  final void Function(double? min, double? max) onChanged;

  const _RangeSection({
    required this.label,
    required this.summary,
    required this.min,
    required this.max,
    required this.upperBound,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = RangeValues(
      (min ?? 0).clamp(0, upperBound),
      (max ?? upperBound).clamp(0, upperBound),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: values,
          min: 0,
          max: upperBound,
          divisions: (upperBound / step).round(),
          onChanged: (next) => onChanged(
            next.start <= 0 ? null : next.start,
            next.end >= upperBound ? null : next.end,
          ),
        ),
      ],
    );
  }
}

/// A row of choice chips with a leading "all" chip that clears the field.
class _ChoiceSection<T> extends StatelessWidget {
  final String label;
  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T?> onSelected;

  const _ChoiceSection({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('routes.filters.any'.tr()),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final value in values)
              ChoiceChip(
                key: keys.routes.filterChoice(value as Object),
                label: Text(labelOf(value)),
                selected: selected == value,
                onSelected: (isSelected) =>
                    onSelected(isSelected ? value : null),
              ),
          ],
        ),
      ],
    );
  }
}

/// Hauteur plancher des deux lignes de navigation de la feuille de filtres.
///
/// Elle est publique parce qu'elle est **la** garantie de F-DE-5 : le test de
/// régression mesure « Direction du vent » contre cette
/// valeur, à `textScaleFactor` 1 comme à 1,3.
const double kFilterNavigationRowHeight = 52;

class _NavigationRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _NavigationRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      // 52 px : la hauteur de ligne de la charte, imposée et non déduite.
      // C'est exactement ce que F-DE-5 avait perdu — cette ligne mesurait
      // 1 pt. `minTileHeight` la rend vérifiable par un test.
      minTileHeight: kFilterNavigationRowHeight,
      shape: Border(top: BorderSide(color: theme.dividerColor)),
      title: Text(label, style: theme.textTheme.titleSmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Wrapper so a sub-sheet can return "no value" without being mistaken for a
/// dismissal.
class _Optional<T> {
  final T? value;
  const _Optional(this.value);
}

/// One selectable line in a sub-sheet.
class _OptionRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(
        label,
        style: isSelected
            ? theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : theme.textTheme.bodyLarge,
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _OptionSheet<T> extends StatelessWidget {
  final String title;
  final String anyLabel;
  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;

  const _OptionSheet({
    required this.title,
    required this.anyLabel,
    required this.values,
    required this.selected,
    required this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return PdlSheet(
      title: title,
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: [
        _OptionRow(
          label: anyLabel,
          isSelected: selected == null,
          onTap: () => Navigator.of(context).pop(_Optional<T>(null)),
        ),
        for (final value in values)
          _OptionRow(
            label: labelOf(value),
            isSelected: selected == value,
            onTap: () => Navigator.of(context).pop(_Optional<T>(value)),
          ),
      ],
    );
  }
}

class _SortSheet extends StatefulWidget {
  final RouteSortBy sortBy;
  final SortDirection sortDir;

  const _SortSheet({required this.sortBy, required this.sortDir});

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late RouteSortBy _by = widget.sortBy;
  late SortDirection _dir = widget.sortDir;

  @override
  Widget build(BuildContext context) {
    return PdlSheet(
      title: 'routes.filters.sort'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PdlButton(
            fullWidth: true,
            label: 'common.continue'.tr(),
            onPressed: () => Navigator.of(context).pop((by: _by, dir: _dir)),
          ),
        ),
      ),
      children: [
        for (final value in RouteSortBy.$valuesDefined)
          _OptionRow(
            label: RouteFilterLabels.routeSortByName(value),
            isSelected: _by == value,
            onTap: () => setState(() => _by = value),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SegmentedButton<SortDirection>(
            segments: [
              ButtonSegment(
                value: SortDirection.asc,
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: Text('routes.sort.asc'.tr()),
              ),
              ButtonSegment(
                value: SortDirection.desc,
                icon: const Icon(Icons.arrow_downward, size: 16),
                label: Text('routes.sort.desc'.tr()),
              ),
            ],
            selected: {_dir},
            onSelectionChanged: (next) => setState(() => _dir = next.first),
          ),
        ),
      ],
    );
  }
}
