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
/// Trois emplacements facultatifs, pour les écrans de détail refondus
/// (ledger `MOB-132`) : [trailing] à droite de l'en-tête (« Rejoindre », le
/// badge « J'y vais »), [places] sous l'en-tête, sur toute la largeur (des
/// `PdlPlaceRow.link`), et [footnote] en 14 atténué au pied du bloc
/// (« Sortie sans groupe, inscription impossible »). Sans eux, le bloc est
/// rendu exactement comme avant.
///
/// Ne formate ni ne traduit rien : tout arrive en `String`. [semanticLabel]
/// lit l'en-tête d'un tenant, à la place des fragments de la boîte du jour.
/// Sans emplacement, il couvre tout le bloc ; avec, il ne couvre que
/// l'en-tête : le bouton, les lieux et la note restent des nœuds à part,
/// sinon le lecteur d'écran ne pourrait plus les atteindre.
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
    this.trailing,
    this.places = const <Widget>[],
    this.footnote,
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

  /// À droite de l'en-tête, centré sur sa hauteur : un `PdlButton`
  /// « Rejoindre » ou un `PdlBadge` « J'y vais ».
  final Widget? trailing;

  /// Les lieux de départ et d'arrivée, sous l'en-tête (`PdlPlaceRow.link`).
  final List<Widget> places;

  /// La note de pied de bloc, en 14 atténué.
  final String? footnote;

  bool get _hasSlots =>
      trailing != null || places.isNotEmpty || footnote != null;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget header = Row(
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
    );

    BoxDecoration decoration() => BoxDecoration(
      color: c.surfaceAlt,
      borderRadius: PdlRadii.cardAll,
      border: Border.all(color: c.borderSubtle),
    );

    if (!_hasSlots) {
      return Semantics(
        container: true,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: Container(
          padding: const EdgeInsets.all(PdlSpacing.cardTight),
          decoration: decoration(),
          child: header,
        ),
      );
    }

    final Widget labelledHeader = Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: header,
    );

    return Container(
      padding: const EdgeInsets.all(PdlSpacing.cardTight),
      decoration: decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (trailing == null)
            labelledHeader
          else
            Row(
              children: <Widget>[
                // L'heure garde au moins la moitié de la largeur : un libellé
                // long (« Changer pour Les Rapides ») s'abrège plutôt que de
                // l'écraser.
                Expanded(child: labelledHeader),
                const SizedBox(width: PdlSpacing.chipGap),
                Flexible(child: trailing!),
              ],
            ),
          if (places.isNotEmpty) ...<Widget>[
            // Les lignes de lieu portent leur cible de 44 px : l'écart visible
            // avec l'en-tête vient déjà de leur marge interne.
            const SizedBox(height: PdlSpacing.badgeGap),
            ...places,
          ],
          if (footnote != null) ...<Widget>[
            SizedBox(
              height: places.isEmpty
                  ? PdlSpacing.cardTight
                  : PdlSpacing.badgeGap,
            ),
            Text(footnote!, style: t.sub),
          ],
        ],
      ),
    );
  }
}
