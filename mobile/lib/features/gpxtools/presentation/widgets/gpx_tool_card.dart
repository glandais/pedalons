import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';

/// Une carte de l'accueil des outils GPX (docs/LEDGER_*.md MOB-178) : une
/// icône et un titre, une phrase, un bouton — les cartes du site
/// (`GpxToolsPage`). [extra] se pose entre la phrase et le bouton : le mot du
/// quota épuisé sous « Créer un parcours ».
class GpxToolCard extends StatelessWidget {
  const GpxToolCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget action;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return PdlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: c.text),
              const SizedBox(width: PdlSpacing.chipGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: t.bodyStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          Text(description, style: t.sub.copyWith(color: c.textDimmed)),
          if (extra != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            extra!,
          ],
          const SizedBox(height: PdlSpacing.section),
          Align(alignment: AlignmentDirectional.centerStart, child: action),
        ],
      ),
    );
  }
}
