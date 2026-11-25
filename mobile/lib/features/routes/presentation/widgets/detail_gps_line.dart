import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/material.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../gps_export_runner.dart';
import 'gps_button.dart';

/// « GPS » dans l'en-tête d'un écran de détail — sortie, groupe, étape
/// (docs/LEDGER_*.md MOB-184, décision D7 du plan des en-têtes, comme le site
/// depuis `WEB-203`) : une ligne sous les badges du bloc d'identité, le
/// bouton en contour et, sur une sortie à plusieurs groupes, le groupe dont
/// part le parcours ([subtitle], « Groupe B · 82 km »).
///
/// **Un seul « GPS » par écran** : ni la carte d'un groupe ni la section
/// « Parcours » n'en portent plus sur ces quatre écrans.
///
/// Elle tient son propre [GpsExportRunner] : l'attente et les bandeaux de
/// l'issue s'affichent sous le bouton qui les a causés. Rien n'est rendu —
/// marge comprise — sans [target] ou quand il n'a rien à proposer avec les
/// services de la personne ([GpsExportTarget.offered]).
class DetailGpsLine extends ConsumerStatefulWidget {
  const DetailGpsLine({
    super.key,
    required this.target,
    this.subtitle,
    this.buttonKey,
  });

  /// Le parcours à exporter ; `null` : pas de « GPS » sur cet écran.
  final GpsExportTarget? target;

  /// Le texte à côté du bouton ; `null` : le bouton seul.
  final String? subtitle;

  /// La clé du bouton, celle que les tests de l'écran cherchent.
  final Key? buttonKey;

  @override
  ConsumerState<DetailGpsLine> createState() => _DetailGpsLineState();
}

class _DetailGpsLineState extends ConsumerState<DetailGpsLine>
    with GpsExportRunner<DetailGpsLine> {
  @override
  Widget build(BuildContext context) {
    final GpsExportTarget? target = widget.target;
    if (target == null || !target.offered(watchGpsServices())) {
      return const SizedBox.shrink();
    }
    final String? subtitle = widget.subtitle;
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.cardTight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              GpsButton(
                key: widget.buttonKey,
                loading: gpsExporting,
                onPressed: (BuildContext button) =>
                    openGpsSheet(target, button),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(width: PdlSpacing.chipGap),
                Expanded(
                  child: Text(
                    subtitle,
                    style: context.pdlText.sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          ...gpsExportBanners(gapBefore: true),
        ],
      ),
    );
  }
}
