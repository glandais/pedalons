import 'package:flutter/material.dart';

import '../pdl/pdl.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import '../utils/link_launcher.dart';

/// Le bouton ⓘ d'une source de données sur un écran de détail (ledger
/// `MOB-134`, maquettes `groupe-mobile-cible`) : « Profil ⓘ » (altitude),
/// la légende du revêtement ⓘ (OpenStreetMap). Le visuel de 18 px, centré
/// dans la cible de 44 px, lu comme un bouton nommé [semanticLabel].
///
/// Le même dessin que l'ⓘ de « Prévision du … » (`WeatherForecastFooter`).
/// Ne traduit rien : [semanticLabel] arrive traduit.
class DetailSourceButton extends StatelessWidget {
  const DetailSourceButton({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onPressed,
          radius: PdlMetrics.tapTarget / 2,
          child: SizedBox.square(
            dimension: PdlMetrics.tapTarget,
            child: Icon(PdlIcons.info, size: 18, color: c.textDimmed),
          ),
        ),
      ),
    );
  }
}

/// La feuille courte derrière un [DetailSourceButton] : un titre, la mention
/// de la source ([text]) et, avec [url], un lien vers elle ([linkLabel]).
Future<void> showDetailSourceSheet(
  BuildContext context, {
  Key? key,
  required String title,
  required String text,
  String? linkLabel,
  String? url,
}) => PdlSheet.show<void>(
  context: context,
  builder: (BuildContext sheetContext) {
    final PdlTypography t = sheetContext.pdlText;
    return PdlSheet(
      key: key,
      title: title,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Text(text, style: t.sub),
        ),
        if (url != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: PdlButton(
                label: linkLabel ?? url,
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                icon: PdlIcons.openExternal,
                onPressed: () => openLink(sheetContext, url),
              ),
            ),
          ),
      ],
    );
  },
);
