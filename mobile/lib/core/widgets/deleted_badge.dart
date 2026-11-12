import 'package:easy_localization/easy_localization.dart';

import '../material.dart';

import '../pdl/pdl.dart';
import '../theme/enum_colors.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';

/// Le badge « Supprimé » d'une entité soft-deleted.
///
/// `deleted` n'est **pas** une valeur de `Status` : c'est un booléen à part,
/// que le backend ne renvoie qu'aux administrateurs de l'équipe
/// (`IncludeDeletedService`). Une publication supprimée reste donc dans le fil
/// d'un admin, avec son statut d'origine — `PUBLIÉ` la plupart du temps. Sans
/// ce badge elle est strictement indiscernable d'une publication vivante, ce
/// qui donne l'impression que la suppression n'a pas eu lieu.
///
/// Il vit ici et non dans `core/pdl` parce qu'il traduit sa propre étiquette :
/// la bibliothèque ne connaît aucune clé de localisation.
class DeletedBadge extends StatelessWidget {
  const DeletedBadge({super.key, this.size = PdlBadgeSize.sm});

  final PdlBadgeSize size;

  @override
  Widget build(BuildContext context) => PdlBadge(
    label: 'status.deleted'.tr(),
    tone: PdlDerivedTones.deleted(context.pdl),
    size: size,
    icon: PdlIcons.delete,
  );
}

/// Le badge en tête d'une pile, ou rien — le `if` qu'écrirait chaque appelant.
///
/// **En tête** : la suppression prime sur le type, le statut et la visibilité,
/// qui décrivent une entité dont on croit encore qu'elle existe.
List<Widget> deletedBadgeFirst(bool deleted) =>
    deleted ? const <Widget>[DeletedBadge()] : const <Widget>[];
