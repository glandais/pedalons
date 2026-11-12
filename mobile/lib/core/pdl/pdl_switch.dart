import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';

/// A15 — Interrupteur de la charte.
///
/// **Ce n'est pas un `Switch` Material.** Le composant M3 mesure 52 × 32 avec
/// un curseur qui grossit à l'activation ; la charte demande 46 × 28 avec un
/// curseur fixe de 24 et 2 px de marge. Dans une liste de réglages, la
/// différence de 4 px se voit d'un coup d'œil sur la colonne de droite.
///
/// Le rail rendu mesure 46 × 28, mais le widget occupe [PdlMetrics.tapTarget]
/// de haut : la cible tactile ne descend jamais sous 44, même employé seul.
class PdlSwitch extends StatelessWidget {
  const PdlSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// `null` désactive l'interrupteur.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;

  static const double trackWidth = 46;
  static const double trackHeight = 28;
  static const double thumbSize = 24;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final bool enabled = onChanged != null;

    final Color track = !enabled
        ? c.disabledBg
        : (value ? c.primary : c.border);

    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          height: PdlMetrics.tapTarget,
          width: trackWidth,
          child: Center(
            child: AnimatedContainer(
              duration: PdlMotion.stateChange,
              curve: PdlMotion.stateChangeCurve,
              width: trackWidth,
              height: trackHeight,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: track,
                borderRadius: PdlRadii.pillAll,
              ),
              child: AnimatedAlign(
                duration: PdlMotion.stateChange,
                curve: PdlMotion.stateChangeCurve,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: enabled ? c.surface : c.disabledText,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
