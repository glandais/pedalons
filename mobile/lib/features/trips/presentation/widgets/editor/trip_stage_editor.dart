import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/units/unit_system.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../../rides/domain/ride_form.dart';
import '../../../../rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import '../../../../rides/presentation/widgets/editor/ride_group_editor.dart';
import '../../../domain/trip_form.dart';
import '../../../keys.dart';

/// La carte d'une étape dans l'éditeur de voyage (docs/LEDGER_*.md MOB-162) :
/// rang, nom, date et heure, vitesse, lieux de départ et d'arrivée, parcours,
/// description, et ses trois gestes — monter, descendre, retirer. Le pendant
/// d'un onglet d'étape de `TripEditor` au site, posé dans la page : un
/// formulaire à onglets ne tient pas sur un téléphone.
///
/// La description est du texte seul : les images d'une étape déjà posées au
/// site sont gardées telles quelles ([TripStageForm.media]), l'app n'en
/// ajoute pas ici.
class TripStageEditor extends ConsumerStatefulWidget {
  const TripStageEditor({
    super.key,
    required this.index,
    required this.stage,
    required this.isFirst,
    required this.isLast,
    required this.enabled,
    required this.showErrors,
    this.startPlaceName,
    this.endPlaceName,
    this.routeName,
    this.routeStats,
    required this.onChanged,
    required this.onPickDate,
    required this.onPickTime,
    required this.onPickStartPlace,
    required this.onPickEndPlace,
    required this.onPickRoute,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final TripStageForm stage;
  final bool isFirst;
  final bool isLast;
  final bool enabled;
  final bool showErrors;

  /// Les noms résolus par l'écran ; nuls tant qu'ils chargent.
  final String? startPlaceName;
  final String? endPlaceName;
  final String? routeName;
  final String? routeStats;

  final ValueChanged<TripStageForm> onChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onPickStartPlace;
  final VoidCallback onPickEndPlace;
  final VoidCallback onPickRoute;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  ConsumerState<TripStageEditor> createState() => _TripStageEditorState();
}

class _TripStageEditorState extends ConsumerState<TripStageEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.stage.name,
  );
  late final TextEditingController _speed = TextEditingController();
  late final TextEditingController _markdown = TextEditingController(
    text: widget.stage.media.markdown,
  )..addListener(_markdownChanged);
  bool _speedSeeded = false;

  void _markdownChanged() {
    final TripStageForm s = widget.stage;
    if (_markdown.text == s.media.markdown) return;
    widget.onChanged(
      s.copyWith(media: s.media.copyWith(markdown: _markdown.text)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_speedSeeded) return;
    _speedSeeded = true;
    final double? kmh = widget.stage.averageSpeed;
    if (kmh != null) {
      final UnitSystem units = ref.read(unitSystemProvider);
      _speed.text = AppFormatters.formatNumber(
        units.speed(kmh),
        fractionDigits: 1,
      ).replaceAll(RegExp(r'[.,]0$'), '');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _speed.dispose();
    _markdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final TripStageForm s = widget.stage;
    final int i = widget.index;
    final TripEditorKeys k = keys.tripEditor;
    final bool on = widget.enabled;

    final double? speed = parseDecimal(_speed.text);
    final bool speedError =
        _speed.text.trim().isNotEmpty && (speed == null || speed <= 0);
    final DateTime? wall = parseWallTime(s.dateTime);
    final String none = 'rides.editor.placeNone'.tr();

    return PdlCard(
      key: k.stage(i),
      padding: PdlCardPadding.tight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: PdlSpacing.chipGap,
                ),
                child: Text(
                  '${i + 1}',
                  style: t.bodyStrong.copyWith(color: c.textDimmed),
                ),
              ),
              Expanded(
                child: TextField(
                  key: k.stageName(i),
                  controller: _name,
                  enabled: on,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kTripStageNameMaxLength),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    hintText: 'trips.editor.stageName'.tr(),
                    errorText: widget.showErrors && !s.nameValid
                        ? 'trips.editor.stageNameError'.tr()
                        : null,
                  ),
                  onChanged: (String v) =>
                      widget.onChanged(s.copyWith(name: v)),
                ),
              ),
              EditorIconButton(
                key: k.stageUp(i),
                icon: PdlIcons.chevronUp,
                label: 'trips.editor.stageUp'.tr(),
                onTap: widget.isFirst || !on ? null : widget.onMoveUp,
              ),
              EditorIconButton(
                key: k.stageDown(i),
                icon: PdlIcons.chevronDown,
                label: 'trips.editor.stageDown'.tr(),
                onTap: widget.isLast || !on ? null : widget.onMoveDown,
              ),
              EditorIconButton(
                key: k.stageRemove(i),
                icon: PdlIcons.delete,
                label: 'trips.editor.stageRemove'.tr(),
                color: c.danger,
                onTap: on ? widget.onRemove : null,
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          PdlSettingRow(
            key: k.stageDate(i),
            padding: EdgeInsets.zero,
            icon: PdlIcons.date,
            title: 'rides.editor.date'.tr(),
            subtitle: wall == null ? '…' : AppFormatters.formatLongDate(wall),
            onTap: on ? widget.onPickDate : null,
          ),
          PdlSettingRow(
            key: k.stageTime(i),
            padding: EdgeInsets.zero,
            icon: PdlIcons.time,
            title: 'rides.editor.time'.tr(),
            subtitle: wall == null ? '…' : AppFormatters.formatTime(wall),
            onTap: on ? widget.onPickTime : null,
          ),
          PdlSettingRow(
            key: k.stageStartPlace(i),
            padding: EdgeInsets.zero,
            icon: PdlIcons.placeStart,
            title: 'rides.editor.startPlace'.tr(),
            subtitle: s.startPlaceId == null
                ? none
                : (widget.startPlaceName ?? '…'),
            trailing: s.startPlaceId == null
                ? null
                : EditorClearButton(
                    onTap: () =>
                        widget.onChanged(s.copyWith(startPlaceId: () => null)),
                  ),
            onTap: on ? widget.onPickStartPlace : null,
          ),
          PdlSettingRow(
            key: k.stageEndPlace(i),
            padding: EdgeInsets.zero,
            icon: PdlIcons.placeEnd,
            title: 'rides.editor.endPlace'.tr(),
            subtitle: s.endPlaceId == null
                ? none
                : (widget.endPlaceName ?? '…'),
            trailing: s.endPlaceId == null
                ? null
                : EditorClearButton(
                    onTap: () =>
                        widget.onChanged(s.copyWith(endPlaceId: () => null)),
                  ),
            onTap: on ? widget.onPickEndPlace : null,
          ),
          PdlSettingRow(
            key: k.stageRoute(i),
            padding: EdgeInsets.zero,
            icon: PdlIcons.route,
            title: 'trips.editor.stageRoute'.tr(),
            subtitle: s.routeSlug == null
                ? 'rides.editor.routeNone'.tr()
                : <String>[
                    widget.routeName ?? s.routeSlug!,
                    ?widget.routeStats,
                  ].join(' · '),
            trailing: s.routeSlug == null
                ? null
                : EditorClearButton(
                    onTap: () =>
                        widget.onChanged(s.copyWith(routeSlug: () => null)),
                  ),
            onTap: on ? widget.onPickRoute : null,
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          TextField(
            key: k.stageSpeed(i),
            controller: _speed,
            enabled: on,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'trips.editor.stageSpeed'.tr(
                namedArgs: <String, String>{'unit': units.speedSymbol},
              ),
              errorText: speedError ? 'rides.editor.positive'.tr() : null,
            ),
            onChanged: (String v) {
              final double? d = parseDecimal(v);
              setState(() {});
              widget.onChanged(
                s.copyWith(
                  averageSpeed: () =>
                      d == null ? null : units.speedToKilometersPerHour(d),
                ),
              );
            },
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          RichMarkdownEditorField(
            title: 'trips.editor.stageDescription'.tr(),
            fieldKey: k.stageMarkdown(i),
            controller: _markdown,
            hintText: 'trips.editor.stageMarkdownPlaceholder'.tr(),
            images: s.media.assets.images,
            enabled: on,
            errorText: s.media.markdown.length <= kTripMarkdownMaxLength
                ? null
                : 'rides.editor.markdownTooLong'.tr(),
          ),
        ],
      ),
    );
  }
}
