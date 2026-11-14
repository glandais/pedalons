import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../rides/presentation/widgets/editor/search_picker_sheet.dart';
import '../../data/place_search_repository.dart';

/// Ouvre la recherche d'adresse du formulaire d'annonce et rend la suggestion
/// choisie, ou `null` (ledger `MOB-158`).
///
/// La suggestion vient le plus souvent **sans position** : c'est l'écran qui
/// la lit ensuite, une fois, pour celle qui a été choisie (ledger `API-129`).
/// Le pied porte le crédit que les conditions du fournisseur veulent visible.
Future<GeocodeResultDto?> showAdPlacePicker(
  BuildContext context,
  WidgetRef ref,
) {
  final PlaceSearchRepository places = ref.read(placeSearchRepositoryProvider);
  return showSearchPickerSheet<GeocodeResultDto>(
    context,
    title: 'ads.editor.placePickerTitle'.tr(),
    searchHint: 'ads.editor.placeSearch'.tr(),
    emptyMessage: 'ads.editor.placeEmpty'.tr(),
    idOf: (GeocodeResultDto place) => place.id,
    load: (String? search, int page) async {
      // Une seule page : le serveur rend cinq suggestions au plus.
      if (page > 0) return (items: const <GeocodeResultDto>[], total: 0);
      final List<GeocodeResultDto> results = await places.search(search ?? '');
      return (items: results, total: results.length);
    },
    itemBuilder: (BuildContext _, GeocodeResultDto place, VoidCallback onTap) =>
        PdlSettingRow(
          icon: PdlIcons.place,
          title: place.displayName,
          trailing: const SizedBox.shrink(),
          onTap: onTap,
        ),
    footerBuilder: (BuildContext sheetContext) {
      final PdlColors c = sheetContext.pdl;
      final PdlTypography t = sheetContext.pdlText;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: Text(
            'ads.editor.placeAttribution'.tr(),
            style: t.xs.copyWith(color: c.textDimmed),
          ),
        ),
      );
    },
  );
}
