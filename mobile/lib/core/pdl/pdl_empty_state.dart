import '../animations/animated_empty_state.dart';
import '../material.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';

/// Les quatre états « il n'y a rien à montrer », qui ne disent pas la même
/// chose et n'appellent pas la même action.
enum PdlEmptyVariant {
  /// Rien n'existe encore. L'action, si elle existe, est de créer.
  empty,

  /// Quelque chose existe, mais le filtre ou la recherche ne laisse rien
  /// passer. L'action est de **relâcher le filtre**, jamais de créer.
  filtered,

  /// Le chargement a échoué. L'action est de réessayer.
  error,

  /// L'objet demandé n'existe pas ou n'est plus visible. L'action est de
  /// revenir en arrière.
  notFound,
}

/// B7 — État vide.
///
/// Icône de 48 px, **titre nominal** (« Aucune publication », pas « Vide »),
/// une phrase qui explique, et zéro à deux actions. Le titre nominal n'est pas
/// un détail de rédaction : c'est lui qui distingue « cette équipe n'a rien
/// publié » de « la liste n'a pas chargé ».
///
/// L'icône flotte doucement via [AnimatedEmptyState], qui respecte déjà
/// `PdlMotion.reducedOf`.
///
/// Pour l'état vide **filtré et détaillé** — le terme cité, les filtres
/// listés un à un, un aperçu de ce qu'on rate — voyez `PdlDeadEndEmpty` : il
/// aide, là où celui-ci se contente de constater.
class PdlEmptyState extends StatelessWidget {
  const PdlEmptyState({
    super.key,
    required this.variant,
    required this.title,
    this.message,
    this.icon,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    this.animate = true,
  });

  final PdlEmptyVariant variant;

  /// Titre nominal, 16/700 sur `text`.
  final String title;

  /// Une phrase, pas un paragraphe.
  final String? message;

  /// Icône imposée ; à défaut, celle de la variante.
  final IconData? icon;

  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  final bool animate;

  IconData get _icon =>
      icon ??
      switch (variant) {
        PdlEmptyVariant.empty => PdlIcons.feed,
        PdlEmptyVariant.filtered => PdlIcons.emptySearch,
        PdlEmptyVariant.error => PdlIcons.error,
        PdlEmptyVariant.notFound => PdlIcons.notFound,
      };

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    // Seule l'erreur porte une teinte : un état vide n'est pas un incident.
    final Color iconColor = variant == PdlEmptyVariant.error
        ? c.dangerOnSoft
        : c.textPlaceholder;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AnimatedEmptyState(
            animate: animate,
            child: Icon(_icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.cardTitle.copyWith(color: c.text),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: t.sub),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
