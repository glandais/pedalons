import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/link_launcher.dart';

/// Une section du tableau de bord : un titre sans article, une action « Voir
/// tout » quand la section a une page entière derrière elle, puis son contenu.
///
/// Une section sans contenu **reste** — avec sa phrase d'état vide — tant que
/// le module de l'équipe est actif : c'est le `null` de l'API, et lui seul, qui
/// la fait disparaître. « Aucune sortie à venir » est une information ; une
/// section qui s'efface sans rien dire n'en est pas une.
class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    required this.title,
    required this.child,
    this.count,
    this.onViewAll,
    this.actionLabel,
    this.actionKey,
  });

  final String title;

  /// Le total derrière la section, quand il dit plus que les lignes montrées.
  final String? count;

  /// « Voir tout » : la page entière de la section.
  final VoidCallback? onViewAll;

  /// Le libellé de cette action ; « Voir tout » par défaut.
  final String? actionLabel;

  /// La clé du bouton de cette action.
  final Key? actionKey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlSectionHeader(
            title: title,
            count: count,
            action: onViewAll == null
                ? null
                : PdlButton(
                    key: actionKey,
                    label: actionLabel ?? 'common.viewAll'.tr(),
                    variant: PdlButtonVariant.text,
                    size: PdlButtonSize.sm,
                    onPressed: onViewAll,
                  ),
          ),
          child,
        ],
      ),
    );
  }
}

/// La phrase d'une section vide, dans une carte plate : la section garde sa
/// place et dit pourquoi elle n'a rien à montrer.
class DashboardEmptyLine extends StatelessWidget {
  const DashboardEmptyLine({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PdlCard(
      flat: true,
      child: Text(
        message,
        style: context.pdlText.sub.copyWith(color: context.pdl.textDimmed),
      ),
    );
  }
}

/// Une colonne de cartes séparées par l'écart du fil.
class DashboardCardColumn extends StatelessWidget {
  const DashboardCardColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: PdlSpacing.feedGap),
          children[i],
        ],
      ],
    );
  }
}

/// Ouvre une page du site que l'application n'a pas (créer, modifier,
/// administrer) dans le navigateur de l'appareil, et dit quand le système refuse.
Future<void> openTeamWebPage(BuildContext context, String path) async {
  final bool opened = await openWebPage(path);
  if (!opened && context.mounted) showUnopenableLinkBanner(context, path);
}
