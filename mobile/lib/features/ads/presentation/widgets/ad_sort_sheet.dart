import 'package:easy_localization/easy_localization.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../domain/ad_filters.dart';

/// Les six tris d'une liste d'annonces — trois colonnes, deux sens.
///
/// Ils sont énumérés à plat plutôt qu'en « colonne + sens » parce que c'est
/// ainsi qu'on les choisit : personne ne pense « prix, ascendant », on pense
/// « les moins chères d'abord ». Le libellé porte donc le sens, et la feuille
/// n'a qu'une seule liste de choix exclusifs.
enum AdSortOption {
  newest(AdSortBy.dateTime, SortDirection.desc),
  oldest(AdSortBy.dateTime, SortDirection.asc),
  priceAsc(AdSortBy.price, SortDirection.asc),
  priceDesc(AdSortBy.price, SortDirection.desc),
  nameAsc(AdSortBy.name, SortDirection.asc),
  nameDesc(AdSortBy.name, SortDirection.desc);

  const AdSortOption(this.sortBy, this.sortDir);

  final AdSortBy sortBy;
  final SortDirection sortDir;

  /// L'option correspondant aux filtres courants, [newest] par défaut — c'est
  /// aussi le défaut du serveur, donc la chip ne ment jamais sur ce qu'on lit.
  static AdSortOption of(AdFilters filters) {
    for (final AdSortOption option in values) {
      if (option.sortBy == filters.sortBy &&
          option.sortDir == filters.sortDir) {
        return option;
      }
    }
    return AdSortOption.newest;
  }

  String get label => 'ads.sort.$name'.tr();
}

/// Ouvre la feuille de tri et rend les filtres modifiés, ou `null` si
/// l'utilisateur ressort sans choisir.
Future<AdFilters?> showAdSortSheet(
  BuildContext context, {
  required AdFilters filters,
}) {
  return PdlSheet.show<AdFilters>(
    context: context,
    builder: (BuildContext sheetContext) => _AdSortSheet(filters: filters),
  );
}

class _AdSortSheet extends StatelessWidget {
  const _AdSortSheet({required this.filters});

  final AdFilters filters;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final AdSortOption current = AdSortOption.of(filters);

    return PdlSheet(
      title: 'ads.sort.title'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        for (final AdSortOption option in AdSortOption.values)
          PdlSettingRow(
            title: option.label,
            trailing: option == current
                ? Icon(PdlIcons.check, size: 20, color: c.primary)
                : const SizedBox.shrink(),
            onTap: () => Navigator.of(context).pop(
              filters.copyWith(sortBy: option.sortBy, sortDir: option.sortDir),
            ),
          ),
      ],
    );
  }
}
