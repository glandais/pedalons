import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/pdl_colors.dart';
import '../../theme/pdl_icons.dart';
import '../../theme/pdl_tokens.dart';
import '../../theme/pdl_typography.dart';
import '../pdl_blur_surface.dart';
import 'pdl_map_hero.dart';

/// Ce qu'un écran doit fournir pour qu'une carte crédite ses fournisseurs.
@immutable
class PdlMapCredit {
  const PdlMapCredit({required this.toggleLabel, this.extra});

  /// Libellé d'accessibilité du bouton ⓘ, **déjà localisé** — `core/pdl` ne
  /// traduit rien.
  final String toggleLabel;

  /// `MapStyleDto.attribution` : le crédit que le document de style ne porte
  /// pas lui-même. Nul pour presque tous les fonds, qui se créditent seuls.
  final String? extra;
}

/// Le crédit dû aux fournisseurs de tuiles, posé au coin d'une carte.
///
/// **L'app n'en affichait aucun, sur aucun fond.** Le greffon Flutter coupe
/// lui-même l'UI native (`attributionEnabled(false)` côté Android,
/// `showsAttributionButton = false` côté iOS), et rien ne la remplaçait : les
/// chaînes arrivaient bien sur l'appareil dans les documents de style, elles
/// n'étaient simplement jamais rendues. Ce n'est pas un détail de présentation —
/// l'ODbL d'OpenStreetMap, les conditions d'ESRI et celles de l'IGN exigent
/// toutes que le crédit soit visible à côté des tuiles qu'il couvre.
///
/// Deux sources se cumulent :
///
/// * ce que le document de style déclare (`getAttributionsSync()`) — c'est de
///   là que viennent OpenStreetMap, CyclOSM, ESRI, Géoportail, VersaTiles et le
///   MNT Mapterhorn ;
/// * [PdlMapCredit.extra], `MapStyleDto.attribution`, pour le fond dont le
///   fournisseur ne déclare rien du tout (le `PLAN.IGN` de l'IGN).
///
/// Le `SourceAttribution` du paquet ne sait pas cumuler les deux, et poserait
/// son texte sur `scaffoldBackgroundColor` : ici c'est `overlaySolid` bordé,
/// comme tout ce qui s'écrit au-dessus d'une tuile (voir `pdl_map_buttons`).
class PdlMapAttribution extends StatefulWidget {
  const PdlMapAttribution({
    super.key,
    required this.credit,
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.all(PdlSpacing.chipGap),
  });

  final PdlMapCredit credit;

  final Alignment alignment;
  final EdgeInsets padding;

  @override
  State<PdlMapAttribution> createState() => _PdlMapAttributionState();
}

class _PdlMapAttributionState extends State<PdlMapAttribution> {
  /// Replié par défaut : sur un écran de téléphone, un bandeau de crédits
  /// permanent mangerait le bas de la carte. Le ⓘ reste visible en
  /// permanence, ce qui est ce que les licences demandent — un accès direct au
  /// crédit, pas un crédit qui recouvre la vue.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final String? extra = widget.credit.extra;
    final List<String> credits = <String>[
      ...?MapController.maybeOf(context)?.style?.getAttributionsSync(),
      if (extra != null && extra.isNotEmpty) extra,
    ];
    if (credits.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: widget.padding,
        child: Align(
          alignment: widget.alignment,
          // Au-dessus de la couche de toucher d'une vignette qui ouvre le
          // plein écran : le ⓘ reste à portée, comme sur toute carte.
          child: PdlMapTapPassThrough(
            child: PdlBlurSurface(
              sigma: PdlMotion.blurOverlayButton,
              color: c.overlaySolid,
              borderRadius: PdlRadii.smAll,
              border: Border.all(color: c.borderSubtle),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (_expanded)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          top: 6,
                          bottom: 6,
                        ),
                        child: _CreditText(credits: credits),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: widget.credit.toggleLabel,
                    child: InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      borderRadius: PdlRadii.smAll,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(PdlIcons.info, size: 16, color: c.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les crédits mis bout à bout, liens compris.
class _CreditText extends StatelessWidget {
  const _CreditText({required this.credits});

  final List<String> credits;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final TextStyle base = context.pdlText.xs.copyWith(color: c.text);
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final String credit in credits) {
      if (spans.isNotEmpty) spans.add(TextSpan(text: ' · ', style: base));
      for (final PdlCreditSegment segment in parsePdlCredit(credit)) {
        final String? href = segment.href;
        spans.add(
          href == null
              ? TextSpan(text: segment.text, style: base)
              : TextSpan(
                  text: segment.text,
                  style: base.copyWith(
                    color: c.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: c.primary,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      final Uri? uri = Uri.tryParse(href);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                ),
        );
      }
    }
    return Text.rich(TextSpan(children: spans), style: base);
  }
}

/// Un morceau de crédit : du texte, cliquable ou non.
@immutable
class PdlCreditSegment {
  const PdlCreditSegment(this.text, {this.href});

  final String text;

  /// La cible du lien, ou `null` pour du texte ordinaire.
  final String? href;

  @override
  bool operator ==(Object other) =>
      other is PdlCreditSegment && other.text == text && other.href == href;

  @override
  int get hashCode => Object.hash(text, href);

  @override
  String toString() => 'PdlCreditSegment($text, href: $href)';
}

/// Une chaîne d'attribution découpée en texte et en liens.
///
/// Les fournisseurs livrent leur crédit en HTML — un fragment, jamais un
/// document : du texte et des `<a href>`, c'est tout ce que la spécification de
/// style MapLibre y met. D'où ce découpage à la main plutôt qu'un moteur de
/// rendu HTML : ajouter une dépendance pour deux balises coûterait plus que ce
/// qu'elle rendrait.
///
/// Un fragment sans lien ressort en un seul segment : c'est le cas d'ESRI, dont
/// le crédit est une phrase entière sans balise.
List<PdlCreditSegment> parsePdlCredit(String html) {
  final RegExp anchor = RegExp(
    // Les deux styles de guillemets : Mapterhorn cite son `href` en
    // apostrophes simples là où tous les autres emploient des doubles.
    r'''<a\b[^>]*?href=["']([^"']*)["'][^>]*?>(.*?)</a>''',
    caseSensitive: false,
    dotAll: true,
  );
  final List<PdlCreditSegment> segments = <PdlCreditSegment>[];
  int cursor = 0;
  for (final RegExpMatch m in anchor.allMatches(html)) {
    if (m.start > cursor) {
      segments.add(
        PdlCreditSegment(_unescape(html.substring(cursor, m.start))),
      );
    }
    segments.add(
      PdlCreditSegment(
        _unescape(_stripTags(m.group(2) ?? '')),
        href: m.group(1),
      ),
    );
    cursor = m.end;
  }
  if (cursor < html.length) {
    segments.add(
      PdlCreditSegment(_unescape(_stripTags(html.substring(cursor)))),
    );
  }
  return segments;
}

String _stripTags(String value) => value.replaceAll(RegExp(r'<[^>]*>'), '');

/// Les seules entités que les fournisseurs emploient réellement. Une table
/// complète serait du code mort : ce sont des crédits, pas de la prose.
String _unescape(String value) => value
    .replaceAll('&copy;', '©')
    .replaceAll('&mdash;', '—')
    .replaceAll('&ndash;', '–')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
