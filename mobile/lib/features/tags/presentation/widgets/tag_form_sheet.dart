import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../domain/tag_form.dart';
import '../../providers/team_tags_change.dart';

/// Ouvre le formulaire d'un tag de [teamSlug] : un nouveau tag du type
/// [type], ou [tag] à renommer et recolorer (docs/LEDGER_*.md MOB-169). Rend
/// le tag enregistré, ou `null` si la feuille a été fermée sans enregistrer.
Future<TagWithUsageDto?> showTagFormSheet(
  BuildContext context,
  String teamSlug, {
  required TagTarget type,
  TagWithUsageDto? tag,
}) {
  return PdlSheet.show<TagWithUsageDto>(
    context: context,
    builder: (BuildContext _) =>
        TagFormSheet(teamSlug: teamSlug, type: type, tag: tag),
  );
}

/// Le formulaire d'un tag — le pendant mobile de `TagFormModal` du site :
/// libellé, couleur parmi les neuf familles, aperçu.
///
/// L'unicité du libellé — par équipe et par type, sans tenir compte de la
/// casse — est l'affaire du serveur : son `TAG_LABEL_TAKEN` se lit dans un
/// bandeau, la feuille ouverte et la saisie gardée.
class TagFormSheet extends ConsumerStatefulWidget {
  const TagFormSheet({
    super.key,
    required this.teamSlug,
    required this.type,
    this.tag,
  });

  final String teamSlug;

  /// Le type d'un nouveau tag. Un tag modifié garde le sien : un tag ne
  /// change jamais de type.
  final TagTarget type;

  /// Le tag à modifier ; `null` pour un nouveau tag.
  final TagWithUsageDto? tag;

  @override
  ConsumerState<TagFormSheet> createState() => _TagFormSheetState();
}

class _TagFormSheetState extends ConsumerState<TagFormSheet> {
  late TagForm _form = widget.tag == null
      ? const TagForm.initial()
      : TagForm.fromTag(widget.tag!);

  late final TextEditingController _label = TextEditingController(
    text: _form.label,
  );

  bool _saving = false;

  /// L'erreur du libellé ne se montre qu'après une tentative.
  bool _showErrors = false;
  String? _error;

  bool get _editing => widget.tag != null;

  @override
  void initState() {
    super.initState();
    _label.addListener(
      () => setState(() => _form = _form.copyWith(label: _label.text)),
    );
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.isValid) {
      setState(() => _showErrors = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final TagsClient client = ref.read(tagsClientProvider);
    // Pris avant l'`await` : la feuille peut être fermée avant la réponse.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final NavigatorState navigator = Navigator.of(context);
    final TagWithUsageDto? tag = widget.tag;
    try {
      final TagWithUsageDto saved = tag == null
          ? await client.createTeamTag(
              teamSlug: widget.teamSlug,
              body: _form.toCreateRequest(widget.type),
            )
          : await client.updateTeamTag(
              teamSlug: widget.teamSlug,
              tagId: tag.id,
              body: _form.toUpdateRequest(),
            );
      notifyTeamTagsChanged(
        container,
        tag == null
            ? TeamTagChange.created(widget.teamSlug, widget.type)
            : TeamTagChange.updated(
                widget.teamSlug,
                TagTarget.fromJson(tag.type),
              ),
      );
      if (mounted) navigator.pop(saved);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String preview = _form.trimmedLabel;
    final Map<String, String> max = <String, String>{
      'max': '$kTagLabelMaxLength',
    };

    return PdlSheet(
      key: keys.teamTags.formSheet,
      title: _editing
          ? 'tags.admin.form.editTitle'.tr()
          : 'tags.admin.form.createTitle'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: PdlButton(
            key: keys.teamTags.formSubmit,
            label: _editing
                ? 'routes.editor.save'.tr()
                : 'tags.admin.form.create'.tr(),
            loading: _saving,
            loadingLabel: 'routes.editor.saving'.tr(),
            fullWidth: true,
            onPressed: _save,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          PdlSpacing.section,
          PdlSpacing.chipGap,
          PdlSpacing.section,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_error != null) ...<Widget>[
              PdlBanner(
                key: keys.teamTags.formErrorBanner,
                tone: PdlBannerTone.danger,
                icon: PdlIcons.error,
                message: _error!,
                onDismiss: () => setState(() => _error = null),
                dismissSemanticLabel: 'common.close'.tr(),
              ),
              const SizedBox(height: PdlSpacing.section),
            ],

            // ── Libellé ── Pas de coupe à la saisie : la borne se lit sur le
            // libellé rogné, celui qui part, et un libellé trop long se dit.
            TextField(
              key: keys.teamTags.formLabel,
              controller: _label,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (String _) => _save(),
              decoration: InputDecoration(
                labelText: 'tags.admin.form.label'.tr(),
                hintText: 'tags.admin.form.labelPlaceholder'.tr(),
                helperText: 'tags.admin.form.labelHint'.tr(namedArgs: max),
                helperMaxLines: 3,
                errorText: _showErrors && !_form.labelValid
                    ? 'tags.admin.form.labelError'.tr(namedArgs: max)
                    : null,
              ),
            ),
            const SizedBox(height: PdlSpacing.section),

            // ── Couleur ── Les neuf familles du code couleur, rendues par le
            // thème : aucune table de couleurs ici.
            Text('tags.admin.form.color'.tr(), style: t.bodyStrong),
            const SizedBox(height: PdlSpacing.chipGap),
            Semantics(
              container: true,
              label: 'tags.admin.form.color'.tr(),
              child: IgnorePointer(
                ignoring: _saving,
                child: Wrap(
                  children: <Widget>[
                    for (final TagColor color in TagColor.$valuesDefined)
                      _ColorSwatch(
                        key: keys.teamTags.formColor(color.json!),
                        tone: tagFamily(color.json!).soft(c),
                        name: 'tags.color.${color.json!}'.tr(),
                        selected: _form.color == color,
                        onTap: () => setState(
                          () => _form = _form.copyWith(color: color),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Aperçu ── Le tag tel que les cartes le montreront.
            if (preview.isNotEmpty) ...<Widget>[
              const SizedBox(height: PdlSpacing.section),
              Row(
                children: <Widget>[
                  Text(
                    'tags.admin.form.preview'.tr(),
                    style: t.sub.copyWith(color: c.textDimmed),
                  ),
                  const SizedBox(width: PdlSpacing.chipGap),
                  Flexible(
                    child: PdlTag(
                      key: keys.teamTags.formPreview,
                      label: preview,
                      color: tagFamily(_form.color.json!).soft(c).fill,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La pastille d'une couleur : l'aplat de la famille, une coche quand elle
/// est choisie. 44 × 44 au toucher.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    super.key,
    required this.tone,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final PdlTone tone;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: name,
      excludeSemantics: true,
      child: Tooltip(
        message: name,
        child: InkResponse(
          onTap: onTap,
          radius: PdlMetrics.tapTarget / 2,
          child: SizedBox.square(
            dimension: PdlMetrics.tapTarget,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tone.fill,
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? Icon(PdlIcons.check, size: 16, color: tone.onFill)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
