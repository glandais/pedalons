import 'package:easy_localization/easy_localization.dart';

import '../../../../core/material.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';

/// Ouvre le sélecteur de fuseau horaire et rend le nom IANA choisi, ou `null`
/// si la feuille se ferme sans choix.
Future<String?> showTimezoneSheet(BuildContext context, {String? current}) {
  return PdlFullSheet.show<String>(
    context: context,
    builder: (BuildContext sheetContext) => TimezoneSheet(current: current),
  );
}

/// Le sélecteur de fuseau : une recherche, puis la liste des fuseaux de la
/// base embarquée ([AppFormatters.timezoneNames]) — celle qui sert ensuite à
/// convertir les heures, pour ne proposer que ce que l'app sait appliquer.
///
/// La recherche ignore la casse, les espaces et les soulignés : « new york »
/// trouve `America/New_York`.
class TimezoneSheet extends StatefulWidget {
  const TimezoneSheet({super.key, this.current});

  final String? current;

  @override
  State<TimezoneSheet> createState() => _TimezoneSheetState();
}

class _TimezoneSheetState extends State<TimezoneSheet> {
  late final List<String> _all = AppFormatters.timezoneNames();
  String _query = '';

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll('_', ' ').trim();

  List<String> get _filtered {
    final String query = _normalize(_query);
    if (query.isEmpty) return _all;
    return _all
        .where((String name) => _normalize(name).contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final List<String> names = _filtered;

    return PdlFullSheet(
      title: 'profile.timezone'.tr(),
      headerAction: PdlButton(
        label: 'common.cancel'.tr(),
        variant: PdlButtonVariant.text,
        size: PdlButtonSize.sm,
        onPressed: () => Navigator.of(context).pop(),
      ),
      bodyBuilder: (BuildContext context, ScrollController controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                0,
                PdlSpacing.section,
                PdlSpacing.chipGap,
              ),
              child: PdlSearchField(
                key: keys.profile.timezoneSearch,
                value: _query,
                hintText: 'profile.timezoneSearch'.tr(),
                debounce: Duration.zero,
                clearTooltip: 'common.clearSearch'.tr(),
                onChanged: (String? value) =>
                    setState(() => _query = value ?? ''),
              ),
            ),
            Expanded(
              child: names.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(PdlSpacing.section),
                      child: Text('profile.timezoneNone'.tr(), style: t.sub),
                    )
                  : ListView.builder(
                      controller: controller,
                      itemCount: names.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String name = names[index];
                        final bool selected = name == widget.current;
                        return Semantics(
                          selected: selected,
                          child: PdlSettingRow(
                            key: keys.profile.timezoneOption(name),
                            title: name.replaceAll('_', ' '),
                            trailing: selected
                                ? Icon(
                                    PdlIcons.check,
                                    size: 20,
                                    color: c.primary,
                                  )
                                : const SizedBox.shrink(),
                            onTap: () => Navigator.of(context).pop(name),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
