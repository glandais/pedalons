import '../../../api/generated/export.dart';

/// Un type de contenu qui porte sa propre visibilité, tel que
/// `ContentVisibilitiesDto` le nomme. Les annonces restent « Équipe » partout
/// et n'ont pas de sélecteur.
enum VisibilityKind { ride, rideTemplate, route, post, trip, teamPage }

/// Ce qu'un éditeur propose, tel que le backend le calcule (docs/LEDGER_*.md
/// MOB-137, décision D7) — jamais déduit de `team.visibility` ni du rôle :
///
/// * à la **modification**, `permissions.allowedVisibilities` de l'entité, qui
///   peut être plus étroite que celle de l'équipe (un parcours utilisé
///   publiquement perd `TEAM`) et même vide ;
/// * à la **création**, et pour les types dont le DTO ne porte pas de liste
///   (les modèles de sortie), `TeamDetailDto.allowedContentVisibilities` du
///   type.
///
/// Une valeur que cette version de l'app ne connaît pas est écartée : elle ne
/// saurait pas la nommer.
List<Visibility> allowedVisibilitiesFor(
  TeamDetailDto team,
  VisibilityKind kind, {
  ContentPermissionsDto? permissions,
}) {
  final List<Visibility> list =
      permissions?.allowedVisibilities ?? _teamList(team, kind);
  return <Visibility>[
    for (final Visibility v in Visibility.$valuesDefined)
      if (list.contains(v)) v,
  ];
}

List<Visibility> _teamList(TeamDetailDto team, VisibilityKind kind) {
  final ContentVisibilitiesDto all = team.allowedContentVisibilities;
  return switch (kind) {
    VisibilityKind.ride => all.ride,
    VisibilityKind.rideTemplate => all.rideTemplate,
    VisibilityKind.route => all.route,
    VisibilityKind.post => all.post,
    VisibilityKind.trip => all.trip,
    VisibilityKind.teamPage => all.teamPage,
  };
}

/// La visibilité de départ d'un formulaire de création : celle que le backend
/// donne (`TeamDetailDto.defaultContentVisibility`, « Équipe » pour une équipe
/// privée, drapeau ou non). Une valeur inconnue retombe sur « Équipe », la
/// plus fermée : un formulaire ne publie jamais plus large que ce qu'il sait
/// nommer.
Visibility defaultContentVisibilityOf(TeamDetailDto team) {
  final Visibility v = Visibility.fromJson(team.defaultContentVisibility);
  return v == Visibility.$unknown ? Visibility.team : v;
}

/// L'équipe est privée : « Public » et « Non répertorié » n'y valent que par
/// lien (décision D1). Ne choisit **que** le texte d'aide du sélecteur, jamais
/// ce qui est proposé.
bool isPrivateTeam(TeamDetailDto team) =>
    team.visibility == Visibility.team.json;
