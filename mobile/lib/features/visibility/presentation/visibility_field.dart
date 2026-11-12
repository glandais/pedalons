import 'package:easy_localization/easy_localization.dart';

import '../../../api/generated/export.dart';
import '../../../core/material.dart' hide Visibility;
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/theme/pdl_typography.dart';
import '../../../keys.dart';
import '../../rides/presentation/widgets/editor/editor_section.dart';

/// Le champ « Visibilité » des éditeurs de sortie, de modèle et de parcours
/// (docs/LEDGER_*.md MOB-137) : les valeurs que le backend permet, dans
/// l'ordre de l'enum `Visibility`, et rien d'autre — [allowed] vient de
/// `allowedVisibilitiesFor`, jamais de `team.visibility` ni du rôle (D7).
///
/// * **Une seule valeur**, celle du contenu : rien à choisir, pas de champ.
/// * **Une seule valeur, qui n'est pas celle du contenu** (l'équipe a perdu le
///   droit de publier hors de l'équipe, plan §4.2) : le champ montre les
///   deux, la valeur actuelle avec un avertissement, pour que la personne
///   voie pourquoi l'enregistrement serait refusé et en choisisse une autre.
/// * **Aucune valeur** (un parcours utilisé publiquement d'une équipe qui ne
///   publie plus qu'en « Équipe », plan §4.4) : une explication à la place
///   d'un sélecteur vide.
///
/// [teamPrivate] ne choisit que l'aide : en équipe privée, « Public » et
/// « Non répertorié » sont lisibles par lien et absents des listes (D1).
class VisibilityField extends StatelessWidget {
  const VisibilityField({
    super.key,
    required this.title,
    required this.allowed,
    required this.value,
    required this.onChanged,
    required this.teamPrivate,
    this.selectorKey,
    this.enabled = true,
  });

  /// Le titre de la section, celui de l'éditeur (« Visibilité », « Visibilité
  /// des sorties créées »).
  final String title;
  final List<Visibility> allowed;
  final Visibility value;
  final ValueChanged<Visibility> onChanged;
  final bool teamPrivate;

  /// La clé du sélecteur segmenté, celle de l'éditeur (les tests de bout en
  /// bout la trouvent).
  final Key? selectorKey;
  final bool enabled;

  /// Le champ a-t-il quelque chose à montrer ?
  static bool shows(List<Visibility> allowed, Visibility value) =>
      allowed.isEmpty || allowed.length > 1 || !allowed.contains(value);

  @override
  Widget build(BuildContext context) {
    if (!shows(allowed, value)) return const SizedBox.shrink();
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    if (allowed.isEmpty) {
      return EditorSection(
        title: title,
        child: PdlBanner(
          key: keys.visibility.noneAllowed,
          tone: PdlBannerTone.warn,
          icon: PdlIcons.warning,
          message: 'visibility.noneAllowed'.tr(),
        ),
      );
    }

    final bool valueAllowed = allowed.contains(value);
    final bool offersOutside = allowed.any(
      (Visibility v) => v != Visibility.team,
    );
    // L'ordre de l'enum, la valeur actuelle gardée à sa place quand elle
    // n'est plus permise.
    final List<Visibility> shown = <Visibility>[
      for (final Visibility v in Visibility.$valuesDefined)
        if (allowed.contains(v) || v == value) v,
    ];

    return EditorSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (teamPrivate && offersOutside)
            Padding(
              padding: const EdgeInsets.only(bottom: PdlSpacing.chipGap),
              child: Text(
                'visibility.privateTeamHint'.tr(),
                key: keys.visibility.privateTeamHint,
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ),
          IgnorePointer(
            ignoring: !enabled,
            child: PdlSegmented<Visibility>(
              key: selectorKey,
              value: value,
              // Une valeur qui n'est plus permise reste affichée, mais ne se
              // choisit pas : seul son abandon est possible.
              onChanged: (Visibility v) {
                if (allowed.contains(v)) onChanged(v);
              },
              segments: <PdlSegment<Visibility>>[
                for (final Visibility v in shown)
                  PdlSegment<Visibility>(
                    key: keys.visibility.option(v.json!),
                    value: v,
                    label: 'visibility.${v.json!.toLowerCase()}'.tr(),
                  ),
              ],
            ),
          ),
          if (!valueAllowed)
            Padding(
              padding: const EdgeInsets.only(top: PdlSpacing.chipGap),
              child: Text(
                'visibility.currentNotAllowed'.tr(),
                key: keys.visibility.notAllowed,
                style: t.xs.copyWith(color: c.warningOnSoft),
              ),
            ),
        ],
      ),
    );
  }
}
