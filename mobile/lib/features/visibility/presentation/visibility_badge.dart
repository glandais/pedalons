import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;

import '../../../api/generated/export.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/enum_colors.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../domain/content_visibility.dart';

/// Le badge de visibilité d'une carte : « Public », « Non répertorié »,
/// « Équipe uniquement », avec son icône.
///
/// Ne se construit que par [cardVisibilityBadges], qui ne rend rien quand la
/// visibilité est celle de l'équipe (règle R1, [cardVisibility]).
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({super.key, required this.visibility});

  final Visibility visibility;

  @override
  Widget build(BuildContext context) => PdlBadge(
    label: 'visibility.${visibility.json!.toLowerCase()}'.tr(),
    tone: visibility.tone(context.pdl),
    icon: switch (visibility) {
      Visibility.public => PdlIcons.visibilityPublic,
      Visibility.publicUnlisted => PdlIcons.visibilityUnlisted,
      _ => PdlIcons.visibilityTeam,
    },
  );
}

/// Zéro ou un badge, à étaler dans la pile d'une carte : la visibilité de
/// [visibility] quand elle diffère de [reference], la visibilité de l'équipe
/// (règle R1, [cardVisibility]).
List<Widget> cardVisibilityBadges(
  String visibility, {
  required String reference,
  Key? key,
}) {
  final Visibility? v = cardVisibility(visibility, reference: reference);
  return <Widget>[if (v != null) VisibilityBadge(key: key, visibility: v)];
}

/// Zéro ou un badge pour la carte d'une équipe : « Équipe uniquement » sur une
/// équipe privée, rien sur une équipe publique (règle R1,
/// [teamCardVisibility]).
List<Widget> teamVisibilityBadges(String teamVisibility, {Key? key}) {
  final Visibility? v = teamCardVisibility(teamVisibility);
  return <Widget>[if (v != null) VisibilityBadge(key: key, visibility: v)];
}
