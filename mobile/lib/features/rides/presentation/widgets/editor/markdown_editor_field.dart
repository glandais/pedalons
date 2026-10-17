import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/widgets/markdown_content.dart';
import '../../../../../keys.dart';
import '../../../domain/markdown_edit.dart';

enum _MarkdownMode { write, preview }

/// La description d'une sortie : du **markdown brut**, une barre d'outils
/// qui l'écrit à la place du membre, et un aperçu rendu par le même
/// [MarkdownContent] que la fiche (ledger `MOB-76`).
///
/// Pas d'éditeur riche : le site écrit ce texte avec Tiptap, et un éditeur
/// mobile à modèle propre le réécrirait à l'enregistrement — directives
/// `::asset{}` comprises, qui placent les images (`markdown_edit.dart`).
///
/// [onInsertImage] envoie une image et rend sa directive, ou `null` si le
/// membre a renoncé ; [images] sont celles de la sortie, que l'aperçu résout.
/// Un [onInsertImage] nul **retire** l'outil image : le modèle de sortie n'a
/// pas de médias (ledger `MOB-78`). [fieldKey] donne sa clé au champ de saisie
/// (celle de l'éditeur de sortie par défaut).
class MarkdownEditorField extends StatefulWidget {
  const MarkdownEditorField({
    super.key,
    required this.controller,
    this.images = const <AssetDto>[],
    this.onInsertImage,
    this.fieldKey,
    this.errorText,
    this.enabled = true,
    this.imageBusy = false,
  });

  final TextEditingController controller;
  final List<AssetDto> images;
  final Future<String?> Function()? onInsertImage;
  final Key? fieldKey;
  final String? errorText;
  final bool enabled;
  final bool imageBusy;

  @override
  State<MarkdownEditorField> createState() => _MarkdownEditorFieldState();
}

class _MarkdownEditorFieldState extends State<MarkdownEditorField> {
  _MarkdownMode _mode = _MarkdownMode.write;
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _apply(TextEditingValue Function(TextEditingValue) edit) {
    widget.controller.value = edit(widget.controller.value);
    _focus.requestFocus();
  }

  Future<void> _link() async {
    final ({String url, String label})? link = await _askLink(context);
    if (link == null || !mounted) return;
    _apply(
      (TextEditingValue v) => insertLink(v, url: link.url, label: link.label),
    );
  }

  Future<void> _image() async {
    // La sélection est lue **avant** l'envoi : le clavier fermé par le
    // sélecteur de photos la remet à -1.
    final TextEditingValue before = widget.controller.value;
    final Future<String?> Function()? insert = widget.onInsertImage;
    if (insert == null) return;
    final String? directive = await insert();
    if (directive == null || !mounted) return;
    widget.controller.value = insertBlock(before, directive);
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PdlSegmented<_MarkdownMode>(
          key: keys.rideEditor.markdownMode,
          value: _mode,
          onChanged: (_MarkdownMode m) => setState(() => _mode = m),
          segments: <PdlSegment<_MarkdownMode>>[
            PdlSegment<_MarkdownMode>(
              value: _MarkdownMode.write,
              label: 'rides.editor.write'.tr(),
              icon: PdlIcons.edit,
            ),
            PdlSegment<_MarkdownMode>(
              value: _MarkdownMode.preview,
              label: 'rides.editor.preview'.tr(),
              icon: PdlIcons.page,
            ),
          ],
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        if (_mode == _MarkdownMode.write) ...<Widget>[
          _Toolbar(
            enabled: widget.enabled,
            imageBusy: widget.imageBusy,
            onBold: () =>
                _apply((TextEditingValue v) => wrapSelection(v, '**')),
            onItalic: () =>
                _apply((TextEditingValue v) => wrapSelection(v, '_')),
            onHeading: () =>
                _apply((TextEditingValue v) => toggleLinePrefix(v, '## ')),
            onBullets: () =>
                _apply((TextEditingValue v) => toggleLinePrefix(v, '- ')),
            onNumbers: () =>
                _apply((TextEditingValue v) => toggleLinePrefix(v, '1. ')),
            onQuote: () =>
                _apply((TextEditingValue v) => toggleLinePrefix(v, '> ')),
            onLink: _link,
            onImage: widget.onInsertImage == null ? null : _image,
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          TextField(
            key: widget.fieldKey ?? keys.rideEditor.markdownField,
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            minLines: 6,
            maxLines: 16,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: t.body,
            decoration: InputDecoration(
              hintText: 'rides.editor.markdownPlaceholder'.tr(),
              errorText: widget.errorText,
            ),
          ),
        ] else
          Container(
            key: keys.rideEditor.markdownPreview,
            constraints: const BoxConstraints(minHeight: PdlMetrics.media120),
            padding: const EdgeInsets.all(PdlSpacing.cardTight),
            decoration: BoxDecoration(
              borderRadius: PdlRadii.mdAll,
              border: Border.all(color: c.border),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (BuildContext context, TextEditingValue value, _) {
                if (value.text.trim().isEmpty) {
                  return Text(
                    'rides.editor.previewEmpty'.tr(),
                    style: t.sub.copyWith(color: c.textPlaceholder),
                  );
                }
                return MarkdownContent(data: value.text, images: widget.images);
              },
            ),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.enabled,
    required this.imageBusy,
    required this.onBold,
    required this.onItalic,
    required this.onHeading,
    required this.onBullets,
    required this.onNumbers,
    required this.onQuote,
    required this.onLink,
    required this.onImage,
  });

  final bool enabled;
  final bool imageBusy;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onHeading;
  final VoidCallback onBullets;
  final VoidCallback onNumbers;
  final VoidCallback onQuote;
  final VoidCallback onLink;
  final VoidCallback? onImage;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    Widget tool(IconData icon, String labelKey, VoidCallback onTap) {
      return IconButton(
        icon: Icon(icon, size: 22),
        color: c.text,
        tooltip: labelKey.tr(),
        constraints: const BoxConstraints(
          minWidth: PdlMetrics.tapTarget,
          minHeight: PdlMetrics.tapTarget,
        ),
        onPressed: enabled ? onTap : null,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          tool(PdlIcons.formatBold, 'rides.editor.toolbar.bold', onBold),
          tool(PdlIcons.formatItalic, 'rides.editor.toolbar.italic', onItalic),
          tool(
            PdlIcons.formatHeading,
            'rides.editor.toolbar.heading',
            onHeading,
          ),
          tool(
            PdlIcons.formatBullets,
            'rides.editor.toolbar.bullets',
            onBullets,
          ),
          tool(
            PdlIcons.formatNumbers,
            'rides.editor.toolbar.numbers',
            onNumbers,
          ),
          tool(PdlIcons.formatQuote, 'rides.editor.toolbar.quote', onQuote),
          tool(PdlIcons.link, 'rides.editor.toolbar.link', onLink),
          if (onImage == null)
            const SizedBox.shrink()
          else if (imageBusy)
            const SizedBox(
              width: PdlMetrics.tapTarget,
              height: PdlMetrics.tapTarget,
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else
            tool(PdlIcons.imageAdd, 'rides.editor.toolbar.image', onImage!),
        ],
      ),
    );
  }
}

/// La feuille « Insérer un lien » : une adresse, un texte facultatif.
Future<({String url, String label})?> _askLink(BuildContext context) {
  final TextEditingController url = TextEditingController();
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
        title: 'rides.editor.linkTitle'.tr(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: url,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'rides.editor.linkUrl'.tr(),
                ),
              ),
              const SizedBox(height: PdlSpacing.chipGap),
              TextField(
                controller: label,
                decoration: InputDecoration(
                  hintText: 'rides.editor.linkLabel'.tr(),
                ),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: PdlButton(
              label: 'rides.editor.linkInsert'.tr(),
              fullWidth: true,
              onPressed: submit,
            ),
          ),
        ),
      );
    },
  );
}
