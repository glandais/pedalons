import '../material.dart';

import '../theme/enum_colors.dart' show PdlTone;
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Les deux tailles de la ligne de départ.
enum PdlDepartureLineSize {
  /// « Départ 09:00 » en 16/700 : les cartes du fil, d'étape, de voyage.
  regular,

  /// « Départ 09:30 » en 20/700 : la carte « Ma prochaine sortie ».
  large,
}

/// La ligne de départ d'une carte (BRANDING §7.1, §7.8, ledgers `BRAND-8`,
/// `MOB-115`) : l'horloge indigo, [headline] (« Départ 09:00 ») en 700, puis
/// [trailing] (la plage d'un voyage, la date d'une
/// étape) en 14 atténué.
///
/// **L'heure n'est jamais tronquée** : [headline] passe à la ligne s'il le faut, et
/// [trailing] passe à la ligne, puis s'abrège, quand la place manque.
///
/// Ne formate ni ne traduit rien. Lue d'un tenant par les lecteurs d'écran
/// (« Départ 09:00, ven. 16 → dim. 18 oct. », ou [semanticLabel]).
class PdlDepartureLine extends StatelessWidget {
  const PdlDepartureLine({
    super.key,
    required this.headline,
    this.trailing,
    this.size = PdlDepartureLineSize.regular,
    this.semanticLabel,
  });

  final String headline;
  final String? trailing;
  final PdlDepartureLineSize size;

  /// Ce que lit un lecteur d'écran à la place des fragments — le jour en
  /// toutes lettres quand la boîte du jour, à côté, est muette. Par défaut
  /// « [headline], [trailing] ».
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool large = size == PdlDepartureLineSize.large;

    return Semantics(
      container: true,
      label: semanticLabel ?? <String>[headline, ?trailing].join(', '),
      excludeSemantics: true,
      child: Wrap(
        spacing: PdlSpacing.chipGap,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(PdlIcons.time, size: large ? 22 : 18, color: c.primary),
              const SizedBox(width: 6),
              // Jamais d'ellipse : à très grand texte, la ligne passe à la
              // ligne plutôt que de couper l'heure.
              Flexible(
                child: Text(
                  headline,
                  style: large ? t.departureLineLg : t.departureLine,
                ),
              ),
            ],
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: t.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// La pastille « Aujourd'hui » / « Demain » posée en haut à droite de l'image
/// d'une carte (BRANDING §7.1) : surface à 95 %, 12/700 au ton. Seulement ces
/// deux cas — l'appelant ne la pose pas autrement.
class PdlDayPill extends StatelessWidget {
  const PdlDayPill({super.key, required this.label, this.tone});

  final String label;

  /// Sans ton, celui d'une sortie (`primary`).
  final PdlTone? tone;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PdlSpacing.chipGap,
        vertical: PdlSpacing.badgeGap,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        borderRadius: PdlRadii.mdAll,
        boxShadow: PdlShadows.posed,
      ),
      child: Text(
        label,
        style: t.dayPill.copyWith(color: tone?.onSoft ?? c.primaryOnSoft),
      ),
    );
  }
}
