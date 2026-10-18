import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../keys.dart';

/// La feuille « Changer l'adresse » : le slug actuel, modifiable. Rend le slug
/// saisi (minuscules, sans espaces), ou `null` si la feuille est fermée sans
/// enregistrer.
///
/// Partagée par l'éditeur de sortie (ledger `MOB-80`) et celui de parcours
/// (`MOB-79`) ; [fieldKey] et [saveKey] donnent leurs clés au champ et au
/// bouton (celles de l'éditeur de sortie par défaut).
Future<String?> showSlugEditSheet(
  BuildContext context,
  String current, {
  Key? fieldKey,
  Key? saveKey,
}) {
  final TextEditingController controller = TextEditingController(text: current);
  return PdlSheet.show<String>(
    context: context,
    builder: (BuildContext sheetContext) {
      void submit() {
        final String slug = controller.text.trim().toLowerCase();
        if (slug.isEmpty) return;
        Navigator.of(sheetContext).pop(slug);
      }

      return PdlSheet(
        title: 'rides.editor.slugEdit'.tr(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: fieldKey ?? keys.rideEditor.slugField,
                controller: controller,
                autofocus: true,
                autocorrect: false,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
                ],
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: PdlSpacing.chipGap),
              Text(
                'rides.editor.slugHint'.tr(),
                style: sheetContext.pdlText.xs.copyWith(
                  color: sheetContext.pdl.textDimmed,
                ),
              ),
            ],
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: PdlButton(
              key: saveKey ?? keys.rideEditor.slugSave,
              label: 'rides.editor.save'.tr(),
              fullWidth: true,
              onPressed: submit,
            ),
          ),
        ),
      );
    },
  );
}
