import 'package:easy_localization/easy_localization.dart';

import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import 'rich_markdown_editor_field.dart';

/// La feuille « Insérer un lien » de l'éditeur riche
/// ([RichMarkdownEditorField]) : une adresse, un texte facultatif.
///
/// [selectedText] : le texte sélectionné, qui devient le lien — le champ du
/// texte disparaît alors, et la feuille rappelle ce texte. [initialUrl] :
/// l'adresse du lien déjà posé sous le curseur, à modifier.
Future<({String url, String label})?> askMarkdownLink(
  BuildContext context, {
  String? selectedText,
  String? initialUrl,
}) {
  final String selection = selectedText?.trim() ?? '';
  final TextEditingController url = TextEditingController(text: initialUrl);
  final TextEditingController label = TextEditingController();
  return PdlSheet.show<({String url, String label})>(
    context: context,
    builder: (BuildContext sheetContext) {
      void submit() {
        final String u = url.text.trim();
        if (u.isEmpty) return;
        Navigator.of(sheetContext).pop((url: u, label: label.text.trim()));
      }

      return PdlSheet(
        title:
            (initialUrl == null
                    ? 'rides.editor.linkTitle'
                    : 'rides.editor.linkEditTitle')
                .tr(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (selection.isNotEmpty) ...<Widget>[
                Text(
                  'rides.editor.linkOn'.tr(
                    namedArgs: <String, String>{'text': selection},
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: sheetContext.pdlText.sub.copyWith(
                    color: sheetContext.pdl.textDimmed,
                  ),
                ),
                const SizedBox(height: PdlSpacing.chipGap),
              ],
              TextField(
                controller: url,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: selection.isEmpty
                    ? TextInputAction.next
                    : TextInputAction.done,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'rides.editor.linkUrl'.tr(),
                ),
                onSubmitted: selection.isEmpty ? null : (_) => submit(),
              ),
              if (selection.isEmpty) ...<Widget>[
                const SizedBox(height: PdlSpacing.chipGap),
                TextField(
                  controller: label,
                  decoration: InputDecoration(
                    hintText: 'rides.editor.linkLabel'.tr(),
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ],
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: PdlButton(
              label:
                  (initialUrl == null
                          ? 'rides.editor.linkInsert'
                          : 'routes.editor.save')
                      .tr(),
              fullWidth: true,
              onPressed: submit,
            ),
          ),
        ),
      );
    },
  );
}
