import '../material.dart';
import '../theme/pdl_tokens.dart';

/// Un geste d'une ligne de liste d'administration (modifier, supprimer,
/// monter, descendre…) : 44 × 44, icône discrète, libellé pour les lecteurs
/// d'écran. Inactif quand [onPressed] est nul.
class RowIconAction extends StatelessWidget {
  const RowIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(
        width: PdlMetrics.tapTarget,
        height: PdlMetrics.tapTarget,
      ),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
