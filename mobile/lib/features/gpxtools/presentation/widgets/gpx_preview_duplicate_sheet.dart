import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../data/gpx_preview_repository.dart';
import '../../domain/preview_name.dart';

/// Ouvre « Dupliquer le fichier » et rend la copie, `null` si la feuille est
/// fermée sans dupliquer (docs/LEDGER_*.md MOB-178, `WEB-180` au site).
Future<GpxPreviewDto?> showGpxPreviewDuplicateSheet(
  BuildContext context,
  GpxPreviewDto preview,
) => PdlSheet.show<GpxPreviewDto>(
  context: context,
  builder: (BuildContext _) => GpxPreviewDuplicateSheet(preview: preview),
);

/// Le nom de la copie, « Copie de … » d'avance. Toute personne connectée
/// peut copier un aperçu dont elle a le lien : la copie est à elle,
/// l'original reste tel quel, et rien ne compte dans un quota. Un échec se
/// lit dans un bandeau, la feuille ouverte et le nom gardé.
class GpxPreviewDuplicateSheet extends ConsumerStatefulWidget {
  const GpxPreviewDuplicateSheet({super.key, required this.preview});

  final GpxPreviewDto preview;

  @override
  ConsumerState<GpxPreviewDuplicateSheet> createState() =>
      _GpxPreviewDuplicateSheetState();
}

class _GpxPreviewDuplicateSheetState
    extends ConsumerState<GpxPreviewDuplicateSheet> {
  late final TextEditingController _name = TextEditingController(
    text: cappedPreviewName(
      'gpxTools.preview.duplicate.defaultName'.tr(
        namedArgs: <String, String>{'name': widget.preview.name},
      ),
    ),
  );
  bool _saving = false;
  bool _showErrors = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!gpxPreviewNameValid(_name.text)) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final GpxPreviewDto copy = await ref
          .read(gpxPreviewRepositoryProvider)
          .copy(widget.preview.id, name: _name.text.trim());
      if (mounted) Navigator.of(context).pop(copy);
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = getErrorMessage(error, stackTrace);
        });
      }
    }
  }

  String? get _nameError {
    if (!_showErrors) return null;
    final int length = _name.text.trim().length;
    if (length < kGpxPreviewNameMin) return 'gpxTools.edit.nameTooShort'.tr();
    if (length > kGpxPreviewNameMax) return 'gpxTools.edit.nameTooLong'.tr();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PdlSheet(
      key: keys.gpxTools.duplicateSheet,
      title: 'gpxTools.preview.duplicate.title'.tr(),
      headerAction: PdlButton(
        label: 'common.close'.tr(),
        variant: PdlButtonVariant.text,
        size: PdlButtonSize.sm,
        onPressed: () => Navigator.of(context).pop(),
      ),
      bodyPadding: EdgeInsets.zero,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: PdlButton(
            key: keys.gpxTools.duplicateSubmit,
            label: 'gpxTools.preview.duplicate.submit'.tr(),
            loading: _saving,
            fullWidth: true,
            onPressed: _save,
          ),
        ),
      ),
      body: Padding(
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
                tone: PdlBannerTone.danger,
                icon: PdlIcons.error,
                message: _error!,
                onDismiss: () => setState(() => _error = null),
                dismissSemanticLabel: 'common.close'.tr(),
              ),
              const SizedBox(height: PdlSpacing.section),
            ],
            TextField(
              key: keys.gpxTools.duplicateName,
              controller: _name,
              enabled: !_saving,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (String _) {
                if (_showErrors) setState(() {});
              },
              onSubmitted: (String _) => _save(),
              decoration: InputDecoration(
                labelText: 'gpxTools.preview.duplicate.nameLabel'.tr(),
                errorText: _nameError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
