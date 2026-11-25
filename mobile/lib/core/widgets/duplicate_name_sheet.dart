import 'package:easy_localization/easy_localization.dart';

import '../material.dart';
import '../pdl/pdl.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../utils/api_error_handler.dart';

/// Les bornes du nom d'un parcours ou d'un aperçu, celles de l'API
/// (`@NotBlank @Size(min = 3, max = 200)`), jugées comme elle sur le nom
/// rogné.
const int kCopyNameMin = 3;
const int kCopyNameMax = 200;

/// « Copie de {name} », coupé à la borne de l'API.
String cappedCopyName(String name) =>
    name.length <= kCopyNameMax ? name : name.substring(0, kCopyNameMax);

/// La feuille « Dupliquer » : le nom de la copie, « Copie de … » d'avance,
/// puis [onSubmit], qui crée la copie. Elle se ferme sur la copie ; un échec
/// se lit dans un bandeau, la feuille ouverte et le nom gardé. Celle d'un
/// aperçu des outils GPX (docs/LEDGER_*.md MOB-178) et celle d'un parcours.
class DuplicateNameSheet<T> extends StatefulWidget {
  const DuplicateNameSheet({
    super.key,
    required this.title,
    required this.nameLabel,
    required this.submitLabel,
    required this.initialName,
    required this.onSubmit,
    this.nameKey,
    this.submitKey,
  });

  final String title;
  final String nameLabel;
  final String submitLabel;
  final String initialName;
  final Future<T> Function(String name) onSubmit;
  final Key? nameKey;
  final Key? submitKey;

  @override
  State<DuplicateNameSheet<T>> createState() => _DuplicateNameSheetState<T>();
}

class _DuplicateNameSheetState<T> extends State<DuplicateNameSheet<T>> {
  late final TextEditingController _name = TextEditingController(
    text: cappedCopyName(widget.initialName),
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
    final int length = _name.text.trim().length;
    if (length < kCopyNameMin || length > kCopyNameMax) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final T copy = await widget.onSubmit(_name.text.trim());
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
    if (length < kCopyNameMin) return 'gpxTools.edit.nameTooShort'.tr();
    if (length > kCopyNameMax) return 'gpxTools.edit.nameTooLong'.tr();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PdlSheet(
      title: widget.title,
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
            key: widget.submitKey,
            label: widget.submitLabel,
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
              key: widget.nameKey,
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
                labelText: widget.nameLabel,
                errorText: _nameError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
