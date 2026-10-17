import 'package:flutter/material.dart';

import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';

/// Une section d'un éditeur — l'éditeur de sortie et celui de modèle (ledger
/// `MOB-76`, `MOB-78`) : un titre de section, une phrase d'aide facultative,
/// puis le contenu.
class EditorSection extends StatelessWidget {
  const EditorSection({
    super.key,
    required this.title,
    required this.child,
    this.hint,
  });

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Padding(
      padding: const EdgeInsets.only(bottom: PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlSectionHeader(title: title),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: PdlSpacing.chipGap),
              child: Text(hint!, style: t.xs.copyWith(color: c.textDimmed)),
            ),
          child,
        ],
      ),
    );
  }
}
