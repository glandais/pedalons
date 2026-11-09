import 'package:flutter/material.dart';

import '../theme/enum_colors.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_badge.dart';

/// Le bloc de départ du détail d'une sortie et de la page d'un groupe
/// (BRANDING §7.8, ledgers `BRAND-8`, `MOB-113`) : le départ en information
/// primaire, juste sous l'identité.
///
/// Surface alternée bordée, rayon 12 ; à gauche la boîte du jour ([dayBox],
/// un `PdlDayBox`) ; au centre « Départ 09:00 » en 22/700 et la pastille
/// « Demain » / « Aujourd'hui » ([relativeLabel], seulement ces deux cas),
/// puis les [details] en 14 atténué (« Arrivée estimée 12:10 »),
/// la mention de fuseau ([zoneMention]) et, en 600, la ligne du groupe de la
/// personne ([groupLine]).
///
/// Ne formate ni ne traduit rien : tout arrive en `String`. Le bloc n'est pas
/// actionnable ; [semanticLabel] le lit d'un tenant, à la place des
/// fragments de la boîte du jour.
class PdlDepartureBlock extends StatelessWidget {
  const PdlDepartureBlock({
    super.key,
    required this.dayBox,
    required this.headline,
    this.relativeLabel,
    this.details = const <String>[],
    this.zoneMention,
    this.groupLine,
    this.semanticLabel,
  });

  final Widget dayBox;

  /// « Départ 09:00 ».
  final String headline;

  /// « Aujourd'hui » ou « Demain » ; `null` sinon.
  final String? relativeLabel;

  /// Lignes en 14 atténué, sous l'heure.
  final List<String> details;

  /// La `ZoneMentionLine` de l'heure affichée, quand le lecteur est ailleurs.
  final Widget? zoneMention;

  /// « Votre groupe : B · 09:30 ».
  final String? groupLine;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget content = Container(
      padding: const EdgeInsets.all(PdlSpacing.cardTight),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: PdlRadii.cardAll,
        border: Border.all(color: c.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          dayBox,
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(
                  spacing: PdlSpacing.chipGap,
                  runSpacing: PdlSpacing.badgeGap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(headline, style: t.departureTime),
                    if (relativeLabel != null)
                      PdlBadge(
                        label: relativeLabel!,
                        // Neutre, à l'horloge, comme « Ma prochaine sortie »
                        // (ledger `MOB-111`) : le ton « inscrit » appartient
                        // au badge « J'y vais ».
                        tone: PdlFamily.gray.soft(c),
                        size: PdlBadgeSize.lg,
                        icon: PdlIcons.time,
                      ),
                  ],
                ),
                for (final String line in details) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(line, style: t.sub),
                ],
                if (zoneMention != null) ...<Widget>[
                  const SizedBox(height: 2),
                  zoneMention!,
                ],
                if (groupLine != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  Text(groupLine!, style: t.bodyStrong),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: content,
    );
  }
}
