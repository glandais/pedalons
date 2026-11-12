import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_typography.dart';

/// A10 — Pastille ronde portant un nombre.
///
/// 26 px de diamètre, fond `primary`, chiffre 12/700 sur `onPrimary`. Sert au
/// numéro d'étape d'un voyage et aux compteurs de rail, pas aux notifications :
/// un compteur d'alerte est un [Badge] Material posé sur son bouton.
///
/// Le nombre ne suit pas l'agrandissement typographique — il déborderait d'un
/// disque de 26 px. Le libellé d'accessibilité, lui, reste complet.
class PdlNumberPill extends StatelessWidget {
  const PdlNumberPill({
    super.key,
    required this.value,
    this.size = 26,
    this.background,
    this.semanticLabel,
  });

  final int value;
  final double size;
  final Color? background;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Semantics(
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background ?? c.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$value',
          textScaler: TextScaler.noScaling,
          style: t.badge.copyWith(
            fontSize: 12,
            letterSpacing: 0,
            color: c.onPrimary,
            height: 1,
          ),
        ),
      ),
    );
  }
}
