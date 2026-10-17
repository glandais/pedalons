import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/units/unit_system.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../domain/ride_form.dart';
import '../../../keys.dart';

/// Une heure « HH:mm[:ss] » du contrat, à l'affichage (12/24 h du téléphone).
/// L'heure est déjà murale : `formatTime` laisse un `DateTime` local intact.
String formatGroupTime(String time) {
  final List<String> parts = time.split(':');
  final DateTime wall = DateTime(
    2000,
    1,
    1,
    int.tryParse(parts.first) ?? 0,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
  return AppFormatters.formatTime(wall);
}

/// Un nombre saisi au clavier, virgule ou point ; `null` pour un champ vide
/// ou illisible.
double? parseDecimal(String text) {
  final String t = text.trim().replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

/// La carte d'un groupe dans l'éditeur : nom, heure, vitesse, places,
/// meneur, parcours, et ses trois gestes — monter, descendre, retirer.
///
/// Le meneur est `GroupRequest.leaderId` et rien d'autre : sans meneur, la
/// ligne dit « Aucun meneur », jamais le créateur de la sortie (ledger
/// `API-30`).
///
/// L'éditeur de modèle (ledger `MOB-78`) réutilise la carte **sans** meneur
/// ni parcours : un modèle n'en porte pas. Un [onPickLeader] ou un
/// [onPickRoute] nul **ne rend pas** la ligne correspondante. [fieldKeys]
/// donne les clés de la carte à l'éditeur qui l'héberge.
class RideGroupEditor extends ConsumerStatefulWidget {
  const RideGroupEditor({
    super.key,
    required this.index,
    required this.group,
    this.leaderName,
    this.routeName,
    required this.isFirst,
    required this.isLast,
    required this.onChanged,
    required this.onPickTime,
    this.onPickLeader,
    this.onPickRoute,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    this.fieldKeys,
  });

  final int index;
  final RideGroupForm group;

  /// Le nom du meneur, s'il est connu (`null` avec un [RideGroupForm.leaderId]
  /// : « Meneur désigné », comme au site).
  final String? leaderName;
  final String? routeName;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<RideGroupForm> onChanged;
  final VoidCallback onPickTime;
  final VoidCallback? onPickLeader;
  final VoidCallback? onPickRoute;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  /// Les clés des champs de la carte ; celles de l'éditeur de sortie par
  /// défaut. Les lignes meneur et parcours gardent `keys.rideEditor`.
  final GroupEditorKeys? fieldKeys;

  @override
  ConsumerState<RideGroupEditor> createState() => _RideGroupEditorState();
}

class _RideGroupEditorState extends ConsumerState<RideGroupEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group.name,
  );
  late final TextEditingController _speed = TextEditingController();
  late final TextEditingController _max = TextEditingController(
    text: widget.group.maxParticipants?.toString() ?? '',
  );
  bool _speedSeeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_speedSeeded) return;
    _speedSeeded = true;
    final double? kmh = widget.group.averageSpeed;
    if (kmh != null) {
      final UnitSystem units = ref.read(unitSystemProvider);
      _speed.text = AppFormatters.formatNumber(
        units.speed(kmh),
        fractionDigits: 1,
      ).replaceAll(RegExp(r'[.,]0$'), '');
    }
  }

  @override
  void didUpdateWidget(RideGroupEditor old) {
    super.didUpdateWidget(old);
    // Un modèle chargé remplace les groupes : le nom suit s'il a changé
    // ailleurs que dans ce champ.
    if (widget.group.name != _name.text &&
        old.group.name != widget.group.name) {
      _name.text = widget.group.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _speed.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final RideGroupForm g = widget.group;
    final int i = widget.index;
    final GroupEditorKeys k = widget.fieldKeys ?? keys.rideEditor;

    final double? speed = parseDecimal(_speed.text);
    final int? max = int.tryParse(_max.text.trim());
    final bool speedError =
        _speed.text.trim().isNotEmpty && (speed == null || speed <= 0);
    final bool maxError =
        _max.text.trim().isNotEmpty && (max == null || max <= 0);

    return PdlCard(
      key: k.group(i),
      padding: PdlCardPadding.tight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: k.groupName(i),
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kRideGroupNameMaxLength),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    hintText: 'rides.editor.groupName'.tr(),
                  ),
                  onChanged: (String v) =>
                      widget.onChanged(g.copyWith(name: v)),
                ),
              ),
              EditorIconButton(
                icon: PdlIcons.chevronUp,
                label: 'rides.editor.groupUp'.tr(),
                onTap: widget.isFirst ? null : widget.onMoveUp,
              ),
              EditorIconButton(
                icon: PdlIcons.chevronDown,
                label: 'rides.editor.groupDown'.tr(),
                onTap: widget.isLast ? null : widget.onMoveDown,
              ),
              EditorIconButton(
                key: k.groupRemove(i),
                icon: PdlIcons.delete,
                label: 'rides.editor.groupRemove'.tr(),
                color: c.danger,
                onTap: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: k.groupSpeed(i),
                  controller: _speed,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'rides.editor.groupSpeed'.tr(
                      namedArgs: <String, String>{'unit': units.speedSymbol},
                    ),
                    errorText: speedError ? 'rides.editor.positive'.tr() : null,
                  ),
                  onChanged: (String v) {
                    final double? d = parseDecimal(v);
                    setState(() {});
                    widget.onChanged(
                      g.copyWith(
                        averageSpeed: () => d == null
                            ? null
                            : units.speedToKilometersPerHour(d),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              Expanded(
                child: TextField(
                  key: k.groupMax(i),
                  controller: _max,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'rides.editor.groupMax'.tr(),
                    errorText: maxError ? 'rides.editor.positive'.tr() : null,
                  ),
                  onChanged: (String v) {
                    setState(() {});
                    widget.onChanged(
                      g.copyWith(maxParticipants: () => int.tryParse(v.trim())),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          PdlSettingRow(
            key: k.groupTime(i),
            padding: EdgeInsets.zero,
            icon: PdlIcons.time,
            title: 'rides.editor.groupTime'.tr(),
            subtitle: g.time == null
                ? 'rides.editor.groupTimeNone'.tr()
                : formatGroupTime(g.time!),
            trailing: g.time == null
                ? null
                : _ClearButton(
                    onTap: () => widget.onChanged(g.copyWith(time: () => null)),
                  ),
            onTap: widget.onPickTime,
          ),
          if (widget.onPickLeader != null)
            PdlSettingRow(
              key: keys.rideEditor.groupLeader(i),
              padding: EdgeInsets.zero,
              icon: PdlIcons.leader,
              title: 'rides.editor.groupLeader'.tr(),
              subtitle: g.leaderId == null
                  ? 'rides.editor.groupLeaderNone'.tr()
                  : (widget.leaderName ??
                        'rides.editor.groupLeaderUnknown'.tr()),
              trailing: g.leaderId == null
                  ? null
                  : _ClearButton(
                      onTap: () =>
                          widget.onChanged(g.copyWith(leaderId: () => null)),
                    ),
              onTap: widget.onPickLeader,
            ),
          if (widget.onPickRoute != null)
            PdlSettingRow(
              key: keys.rideEditor.groupRoute(i),
              padding: EdgeInsets.zero,
              icon: PdlIcons.route,
              title: 'rides.editor.groupRoute'.tr(),
              subtitle: g.routeSlug == null
                  ? 'rides.editor.routeNone'.tr()
                  : (widget.routeName ?? g.routeSlug!),
              trailing: g.routeSlug == null
                  ? null
                  : _ClearButton(
                      onTap: () =>
                          widget.onChanged(g.copyWith(routeSlug: () => null)),
                    ),
              onTap: widget.onPickRoute,
            ),
        ],
      ),
    );
  }
}

/// Un bouton-icône de 44 px, libellé lu par le lecteur d'écran : les gestes
/// d'une carte de groupe, le `⋯` d'une carte de modèle.
class EditorIconButton extends StatelessWidget {
  const EditorIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: color ?? context.pdl.text,
      tooltip: label,
      constraints: const BoxConstraints(
        minWidth: PdlMetrics.tapTarget,
        minHeight: PdlMetrics.tapTarget,
      ),
      onPressed: onTap,
    );
  }
}

/// Le « Retirer » d'une ligne de choix : 44 px, libellé lu par le lecteur
/// d'écran.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EditorIconButton(
      icon: PdlIcons.close,
      label: 'rides.editor.clear'.tr(),
      color: context.pdl.textDimmed,
      onTap: onTap,
    );
  }
}

/// Le même bouton, pour les lignes de l'écran.
class EditorClearButton extends StatelessWidget {
  const EditorClearButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ClearButton(onTap: onTap);
}
