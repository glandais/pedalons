import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../data/ride_template_repository.dart';
import '../../domain/ride_form.dart';
import '../../domain/ride_template_form.dart';
import '../../providers/ride_template_providers.dart';
import '../widgets/editor/editor_section.dart';
import '../widgets/editor/markdown_editor_field.dart';
import '../widgets/editor/ride_group_editor.dart';
import '../widgets/templates/ride_template_gate.dart';

/// Créer ([templateSlug] nul) ou modifier un modèle de sortie — le pendant
/// mobile de `CreateRideTemplatePage` / `EditRideTemplatePage` du site, au
/// même contrat (docs/LEDGER_*.md MOB-78).
///
/// Mêmes droits que la liste ([RideTemplateAccessGate]) : un modèle ne se
/// lit, ne s'écrit et ne se supprime qu'en organisateur ou administrateur.
/// Un modèle n'a ni date, ni lieux, ni parcours, ni médias : ses groupes n'ont
/// ni meneur ni parcours, qui se choisissent sur chaque sortie.
class RideTemplateEditorPage extends ConsumerWidget {
  const RideTemplateEditorPage({
    super.key,
    required this.teamSlug,
    this.templateSlug,
  });

  final String teamSlug;
  final String? templateSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? slug = templateSlug;
    final String title = slug == null
        ? 'rides.templates.createTitle'.tr()
        : 'rides.templates.editTitle'.tr();
    return RideTemplateAccessGate(
      teamSlug: teamSlug,
      title: title,
      template: slug == null ? null : (teamSlug: teamSlug, templateSlug: slug),
      builder:
          (
            BuildContext context,
            TeamDetailDto team,
            RideTemplateDto? template,
          ) => _RideTemplateEditorForm(
            // Un modèle rechargé sous l'écran (slug changé, autre
            // appareil) ne réécrit pas un formulaire en cours : la clé ne
            // suit que son id.
            key: ValueKey<String>(template?.id ?? 'new-$teamSlug'),
            team: team,
            template: template,
            title: title,
          ),
    );
  }
}

class _RideTemplateEditorForm extends ConsumerStatefulWidget {
  const _RideTemplateEditorForm({
    super.key,
    required this.team,
    required this.template,
    required this.title,
  });

  final TeamDetailDto team;
  final RideTemplateDto? template;
  final String title;

  @override
  ConsumerState<_RideTemplateEditorForm> createState() =>
      _RideTemplateEditorFormState();
}

class _RideTemplateEditorFormState
    extends ConsumerState<_RideTemplateEditorForm> {
  late RideTemplateForm _form;
  late final String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _nextNumber;
  late final TextEditingController _markdown;

  /// Une clé locale par groupe, stable au réordonnancement : c'est elle qui
  /// garde chaque carte (et ses champs) attachée à son groupe.
  final List<int> _groupUids = <int>[];
  int _nextUid = 0;

  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  RideTemplateDto? get _template => widget.template;
  String get _teamSlug => widget.team.slug;

  @override
  void initState() {
    super.initState();
    final RideTemplateDto? template = _template;
    _form = template == null
        ? RideTemplateForm.initial(
            widget.team,
            firstGroupName: _defaultGroupName(1),
          )
        : RideTemplateForm.fromTemplate(template);
    _initialJson = _json(_form);
    _name = TextEditingController(text: _form.name)
      ..addListener(() => _update(_form.copyWith(name: _name.text)));
    _nextNumber = TextEditingController(
      text: _form.nextNumber?.toString() ?? '',
    )..addListener(_onNextNumberChanged);
    _markdown = TextEditingController(text: _form.markdown)
      ..addListener(() => _update(_form.copyWith(markdown: _markdown.text)));
    for (int i = 0; i < _form.groups.length; i++) {
      _groupUids.add(_nextUid++);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nextNumber.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(RideTemplateForm form) =>
      jsonEncode(form.toRequest().toJson());

  static String _defaultGroupName(int number) => 'rides.editor.groupDefaultName'
      .tr(namedArgs: <String, String>{'number': '$number'});

  bool get _dirty => !_saved && _json(_form) != _initialJson;

  void _update(RideTemplateForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  /// Un champ vidé veut dire « ne pas numéroter » : `null`, pas zéro.
  void _onNextNumberChanged() {
    final int? value = int.tryParse(_nextNumber.text.trim());
    if (value == _form.nextNumber) return;
    _update(_form.copyWith(nextNumber: () => value));
  }

  // ── Tags ───────────────────────────────────────────────────────────────

  Future<void> _editTags(List<TagWithUsageDto> vocabulary) async {
    final List<String>? picked = await showTagPickerSheet(
      context,
      vocabulary: vocabulary,
      selected: _form.tagIds,
      title: 'rides.templates.tagsPickerTitle'.tr(),
      hint: 'rides.editor.tagsPickerHint'.tr(),
      maxSelected: kRideMaxTags,
    );
    if (picked == null) return;
    _update(_form.copyWith(tagIds: picked));
  }

  String _tagLabels(List<TagWithUsageDto> vocabulary) {
    final Map<String, String> labels = <String, String>{
      for (final TagWithUsageDto t in vocabulary) t.id: t.label,
    };
    return _form.tagIds
        .map((String id) => labels[id])
        .whereType<String>()
        .join(', ');
  }

  // ── Groupes ────────────────────────────────────────────────────────────

  void _setGroup(int index, RideGroupForm group) {
    final List<RideGroupForm> groups = <RideGroupForm>[..._form.groups];
    groups[index] = group;
    _update(_form.copyWith(groups: groups));
  }

  void _addGroup() {
    setState(() {
      _groupUids.add(_nextUid++);
      _form = _form.copyWith(
        groups: <RideGroupForm>[
          ..._form.groups,
          RideGroupForm(name: _defaultGroupName(_form.groups.length + 1)),
        ],
      );
    });
  }

  void _moveGroup(int index, int delta) {
    final int to = index + delta;
    if (to < 0 || to >= _form.groups.length) return;
    setState(() {
      final List<RideGroupForm> groups = <RideGroupForm>[..._form.groups];
      final RideGroupForm g = groups.removeAt(index);
      groups.insert(to, g);
      final int uid = _groupUids.removeAt(index);
      _groupUids.insert(to, uid);
      _form = _form.copyWith(groups: groups);
    });
  }

  /// Retirer un groupe de modèle ne coûte rien à personne : aucune
  /// inscription n'y est attachée, donc pas de confirmation.
  void _removeGroup(int index) {
    setState(() {
      _groupUids.removeAt(index);
      _form = _form.copyWith(
        groups: <RideGroupForm>[..._form.groups]..removeAt(index),
      );
    });
  }

  Future<void> _editGroupTime(int index) async {
    final String? time = _form.groups[index].time;
    final List<String> parts = time?.split(':') ?? const <String>[];
    final TimeOfDay initial = time == null
        ? const TimeOfDay(hour: kDefaultRideHour, minute: 0)
        : TimeOfDay(
            hour: int.tryParse(parts.first) ?? 0,
            minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
          );
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final String hhmm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _setGroup(index, _form.groups[index].copyWith(time: () => hhmm));
  }

  // ── Enregistrer ────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() => confirmDestructive(
    context,
    title: 'rides.editor.discardTitle'.tr(),
    message: 'rides.editor.discardMessage'.tr(),
    confirmLabel: 'rides.editor.discardConfirm'.tr(),
  );

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_form.isValid) {
      setState(() {
        _showErrors = true;
        _error = 'rides.editor.invalid'.tr();
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final RideTemplateRepository repo = ref.read(
      rideTemplateRepositoryProvider,
    );
    // Pris avant l'`await` : pendant l'enregistrement le retour est permis, et
    // l'écran peut être démonté avant la réponse.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final RideTemplateRequest request = _form.toRequest();
    final RideTemplateDto? template = _template;
    try {
      if (template == null) {
        await repo.create(_teamSlug, request);
      } else {
        await repo.update(_teamSlug, template.slug, request);
      }
      // Le modèle est écrit même si l'écran est parti : les vues dessous
      // (liste, détail, tableau de bord) doivent le savoir.
      notifyRideTemplatesChanged(container);
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            template == null
                ? 'rides.templates.created'.tr()
                : 'rides.templates.saved'.tr(),
          ),
        ),
      );
      // La liste est dessous : on y revient ; ouvert par un lien, sans rien
      // dessous, on y va.
      final GoRouter router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.rideTemplates(_teamSlug));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final List<TagWithUsageDto> vocabulary =
        ref
            .watch(
              teamTagsProvider((teamSlug: _teamSlug, type: TagTarget.ride)),
            )
            .value ??
        const <TagWithUsageDto>[];

    final bool teamOnly = widget.team.visibility == Visibility.team.json;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _saved = true;
          navigator.pop();
        }
      },
      child: PdlScreenScaffold(
        appBar: PdlAppBar(
          title: widget.title,
          onBack: () => Navigator.of(context).maybePop(),
          backSemanticLabel: 'common.back'.tr(),
        ),
        actionBar: PdlActionBar(
          children: <Widget>[
            PdlButton(
              key: keys.rideTemplateEditor.saveButton,
              label: 'rides.editor.save'.tr(),
              loading: _saving,
              loadingLabel: 'rides.editor.saving'.tr(),
              onPressed: _save,
            ),
          ],
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section * 2,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  PdlBanner(
                    key: keys.rideTemplateEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Nom et numérotation ──
                TextField(
                  key: keys.rideTemplateEditor.nameField,
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(
                      kRideTemplateNameMaxLength,
                    ),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'rides.templates.name'.tr(),
                    hintText: 'rides.templates.namePlaceholder'.tr(),
                    errorText: _showErrors && !_form.nameValid
                        ? 'rides.templates.nameError'.tr()
                        : null,
                  ),
                ),
                const SizedBox(height: PdlSpacing.section),
                TextField(
                  key: keys.rideTemplateEditor.nextNumberField,
                  controller: _nextNumber,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      kRideTemplateNextNumberMaxDigits,
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'rides.templates.nextNumber'.tr(),
                    hintText: 'rides.templates.nextNumberNone'.tr(),
                    helperText: 'rides.templates.nextNumberHint'.tr(),
                    helperMaxLines: 4,
                    helperStyle: t.xs.copyWith(color: c.textDimmed),
                  ),
                ),
                const SizedBox(height: PdlSpacing.section),

                // ── Description ── Pas d'image : le modèle n'a pas de médias.
                EditorSection(
                  title: 'rides.editor.description'.tr(),
                  child: MarkdownEditorField(
                    controller: _markdown,
                    fieldKey: keys.rideTemplateEditor.markdownField,
                    enabled: !_saving,
                    errorText: _form.markdownValid
                        ? null
                        : 'rides.editor.markdownTooLong'.tr(),
                  ),
                ),

                // ── Tags ── Rien à proposer sans vocabulaire, sauf à garder
                // des tags déjà posés.
                if (vocabulary.isNotEmpty || _form.tagIds.isNotEmpty)
                  EditorSection(
                    title: 'rides.editor.tags'.tr(),
                    child: PdlSettingRow(
                      key: keys.rideTemplateEditor.tagsRow,
                      padding: EdgeInsets.zero,
                      icon: PdlIcons.tag,
                      title: _form.tagIds.isEmpty
                          ? 'rides.editor.tagsNone'.tr()
                          : _tagLabels(vocabulary),
                      onTap: _saving || vocabulary.isEmpty
                          ? null
                          : () => _editTags(vocabulary),
                    ),
                  ),

                // ── Visibilité et statut des sorties créées ──
                if (!teamOnly)
                  EditorSection(
                    title: 'rides.templates.visibility'.tr(),
                    child: PdlSegmented<Visibility>(
                      key: keys.rideTemplateEditor.visibility,
                      value: _form.visibility,
                      onChanged: (Visibility v) =>
                          _update(_form.copyWith(visibility: v)),
                      segments: <PdlSegment<Visibility>>[
                        for (final Visibility v in Visibility.$valuesDefined)
                          PdlSegment<Visibility>(
                            value: v,
                            label: 'visibility.${v.json!.toLowerCase()}'.tr(),
                          ),
                      ],
                    ),
                  ),
                EditorSection(
                  title: 'rides.templates.status'.tr(),
                  child: PdlSegmented<Status>(
                    key: keys.rideTemplateEditor.status,
                    value: _form.status,
                    onChanged: (Status s) => _update(_form.copyWith(status: s)),
                    segments: <PdlSegment<Status>>[
                      for (final Status s in Status.$valuesDefined)
                        PdlSegment<Status>(
                          value: s,
                          label: 'status.${s.json!.toLowerCase()}'.tr(),
                        ),
                    ],
                  ),
                ),

                // ── Groupes ── Ni meneur ni parcours : ils se choisissent sur
                // chaque sortie.
                EditorSection(
                  title: 'rides.editor.groups'.tr(),
                  hint: 'rides.templates.groupsHint'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < _form.groups.length; i++) ...<Widget>[
                        RideGroupEditor(
                          key: ValueKey<int>(_groupUids[i]),
                          fieldKeys: keys.rideTemplateEditor,
                          index: i,
                          group: _form.groups[i],
                          isFirst: i == 0,
                          isLast: i == _form.groups.length - 1,
                          onChanged: (RideGroupForm g) => _setGroup(i, g),
                          onPickTime: () => _editGroupTime(i),
                          onMoveUp: () => _moveGroup(i, -1),
                          onMoveDown: () => _moveGroup(i, 1),
                          onRemove: () => _removeGroup(i),
                        ),
                        const SizedBox(height: PdlSpacing.chipGap),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: PdlButton(
                          key: keys.rideTemplateEditor.addGroupButton,
                          label: 'rides.editor.groupAdd'.tr(),
                          icon: PdlIcons.add,
                          variant: PdlButtonVariant.outline,
                          size: PdlButtonSize.sm,
                          enabled: !_saving,
                          onPressed: _addGroup,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
