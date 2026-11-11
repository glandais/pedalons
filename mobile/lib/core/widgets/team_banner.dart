import 'package:flutter/material.dart';

import '../../api/generated/export.dart';
import '../../config/paths.dart';
import '../pdl/pdl_team_line.dart';
import '../utils/push_location.dart';

/// Ouvre la page de [team] depuis un détail — ou rien quand le backend dit
/// que l'appelant ne peut pas la consulter (`TeamPublicationDto.accessible`
/// faux : le contenu public d'une équipe privée, lu par lien, docs/LEDGER_*.md
/// MOB-137). Ce lien finirait sur « Équipe indisponible » : il n'est pas
/// offert, et l'écran rend le résumé embarqué à la place.
VoidCallback? teamLinkOf(BuildContext context, TeamPublicationDto team) =>
    team.accessible ? () => pushLocation(context, Paths.team(team.slug)) : null;

/// Ligne d'appartenance d'une publication : logo, nom d'équipe, chevron.
///
/// Ce n'est plus qu'une **façade** : le rendu appartient à [PdlTeamLine]
/// (B3). Ce qui reste ici est ce que `core/pdl` ne peut pas connaître — le DTO
/// et l'itinéraire de navigation. C'est la frontière du module : tout widget
/// qui prend un DTO vit hors de `core/pdl`, sans préfixe `Pdl`.
///
/// Le logo n'est montré que quand le résumé en porte l'adresse (absente pour
/// une équipe privée qui ne publie pas par lien) ; sinon, les initiales. Le
/// lien vers l'équipe suit [teamLinkOf].
class TeamBanner extends StatelessWidget {
  final TeamPublicationDto team;

  const TeamBanner({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return PdlTeamLine(
      label: team.name,
      imageUrl: team.logoUrl,
      onTap: teamLinkOf(context, team),
    );
  }
}
