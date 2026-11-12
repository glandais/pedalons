import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../domain/ad_filters.dart';
import '../../providers/ad_list_provider.dart';

// Le prix des annonces (règle RL3 des listes, KIT §10) : une puce « Prix »
// après le tri, qui ouvre une petite feuille « Prix min. / Prix max. » aux
// règles du site (`frontend/src/pages/ad/AdListPage.tsx`) — des euros entiers,
// 0 au minimum, « Indifférent » à vide, et la même phrase d'aide : une borne
// écarte les annonces à négocier.

String _euros(int price) => AppFormatters.formatNumber(price);

/// Le libellé de la puce « Prix » : « Prix » au repos ; réglée, la plage —
/// « Jusqu'à 500 € », « Prix min. 100 € », « 100 – 500 € ».
String adPriceChipLabel(AdFilters filters) {
  final int? min = filters.minPrice;
  final int? max = filters.maxPrice;
  if (min != null && max != null) {
    return 'ads.list.price.range'.tr(
      namedArgs: <String, String>{'min': _euros(min), 'max': _euros(max)},
    );
  }
  if (max != null) {
    return 'ads.list.price.upTo'.tr(
      namedArgs: <String, String>{'price': _euros(max)},
    );
  }
  if (min != null) {
    return 'ads.list.price.minActive'.tr(
      namedArgs: <String, String>{'price': _euros(min)},
    );
  }
  return 'ads.list.price.chip'.tr();
}

/// Les bornes posées, nommées comme au site dans le vide filtré : « Prix
/// min. 100 € », « Prix max. 500 € ».
List<String> adPriceFilterNames(AdFilters filters) => <String>[
  if (filters.minPrice case final int min)
    'ads.list.price.minActive'.tr(
      namedArgs: <String, String>{'price': _euros(min)},
    ),
  if (filters.maxPrice case final int max)
    'ads.list.price.maxActive'.tr(
      namedArgs: <String, String>{'price': _euros(max)},
    ),
];

/// Ouvre la feuille de prix sur [filters] ; rend les filtres à appliquer, ou
/// `null` si la feuille est fermée sans valider.
Future<AdFilters?> showAdPriceSheet(
  BuildContext context, {
  required AdFilters filters,
}) => PdlSheet.show<AdFilters>(
  context: context,
  builder: (BuildContext context) => _AdPriceSheet(initial: filters),
);

class _AdPriceSheet extends ConsumerStatefulWidget {
  const _AdPriceSheet({required this.initial});

  final AdFilters initial;

  @override
  ConsumerState<_AdPriceSheet> createState() => _AdPriceSheetState();
}

class _AdPriceSheetState extends ConsumerState<_AdPriceSheet> {
  late final TextEditingController _min = TextEditingController(
    text: widget.initial.minPrice?.toString() ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.initial.maxPrice?.toString() ?? '',
  );
  late AdFilters _draft = widget.initial;

  /// Le dernier compte confirmé, gardé à l'écran pendant que le suivant
  /// arrive : le bouton ne clignote pas à chaque chiffre tapé.
  int? _lastCount;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  static int? _parse(String text) =>
      text.trim().isEmpty ? null : int.tryParse(text.trim());

  void _changed() => setState(
    () => _draft = _draft.copyWith(
      price: (min: _parse(_min.text), max: _parse(_max.text)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    ref.listen(adCountProvider(_draft), (_, AsyncValue<int> next) {
      final int? value = next.value;
      if (value != null) _lastCount = value;
    });
    final int? count = ref.watch(adCountProvider(_draft)).value ?? _lastCount;

    Widget field(Key key, String label, TextEditingController controller) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: t.bodyStrong),
              const SizedBox(height: PdlSpacing.badgeGap),
              TextField(
                key: key,
                controller: controller,
                onChanged: (_) => _changed(),
                keyboardType: TextInputType.number,
                // Des euros entiers, jamais négatifs : 0 au minimum.
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                style: t.body,
                decoration: InputDecoration(
                  hintText: 'ads.list.price.placeholder'.tr(),
                  suffixText: '€',
                  isDense: true,
                ),
              ),
            ],
          ),
        );

    return PdlSheet(
      title: 'ads.list.price.title'.tr(),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PdlButton(
            key: keys.adsList.priceApplyButton,
            fullWidth: true,
            label: count == null
                ? 'ads.list.price.applyUnknown'.tr()
                : 'ads.list.price.apply'.plural(
                    count,
                    args: <String>[AppFormatters.formatNumber(count)],
                  ),
            onPressed: () => Navigator.of(context).pop(_draft),
          ),
        ),
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  field(
                    keys.adsList.minPriceField,
                    'ads.list.price.min'.tr(),
                    _min,
                  ),
                  const SizedBox(width: PdlSpacing.cardTight),
                  field(
                    keys.adsList.maxPriceField,
                    'ads.list.price.max'.tr(),
                    _max,
                  ),
                ],
              ),
              const SizedBox(height: PdlSpacing.chipGap),
              Text('ads.list.price.hint'.tr(), style: t.sub),
            ],
          ),
        ),
      ],
    );
  }
}
