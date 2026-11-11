import 'package:pedalons/api/generated/export.dart' as api;

/// Valeurs neutres des champs calculés du contrat 13.7.0 (docs/LEDGER_*.md
/// API-176) : ce que le backend répond à quelqu'un qui n'est pas membre de
/// l'équipe — rien à modifier, ni inscription, ni noms, ni commentaires.
const api.ContentPermissionsDto kNoPermissions = api.ContentPermissionsDto(
  canEdit: false,
  canDelete: false,
  indexable: false,
);

const api.ContentVisibilitiesDto kAllContentVisibilities =
    api.ContentVisibilitiesDto(
      ride: _all,
      rideTemplate: _all,
      route: _all,
      post: _all,
      trip: _all,
      teamPage: _all,
      ad: <api.Visibility>[api.Visibility.team],
    );

const List<api.Visibility> _all = <api.Visibility>[
  api.Visibility.team,
  api.Visibility.publicUnlisted,
  api.Visibility.public,
];

/// Le bloc `permissions` que le backend calcule pour un appelant (docs/
/// LEDGER_*.md MOB-137), tel que les écrans le lisent désormais : un membre
/// s'inscrit, voit les noms et commente ; un organisateur ou un administrateur
/// de l'équipe modifie et supprime ; l'administration de la plateforme peut
/// tout. Les jeux d'essai qui disaient « membre » par « Mes équipes » le disent
/// maintenant par ce bloc, comme le serveur.
api.ContentPermissionsDto permissionsFor({
  required bool member,
  String? role,
  bool platformAdmin = false,
}) {
  final bool manage =
      platformAdmin || (member && (role == 'ORGANIZER' || role == 'ADMIN'));
  final bool reads = member || platformAdmin;
  return api.ContentPermissionsDto(
    canEdit: manage,
    canDelete: manage,
    indexable: false,
    canRegister: reads,
    canComment: reads,
    canSeeParticipants: reads,
    allowedVisibilities: _all,
  );
}

/// `TeamDetailDto.allowedContentVisibilities` comme le backend le calcule
/// pour une équipe de visibilité [teamVisibility] (plan 2026-11-11 §4.2) : les
/// trois valeurs, sauf pour une équipe privée sans [publicContentAllowed], qui
/// n'a que « Équipe ».
api.ContentVisibilitiesDto contentVisibilitiesFor(
  String teamVisibility, {
  bool publicContentAllowed = false,
}) {
  if (teamVisibility != 'TEAM' || publicContentAllowed) {
    return kAllContentVisibilities;
  }
  const List<api.Visibility> team = <api.Visibility>[api.Visibility.team];
  return const api.ContentVisibilitiesDto(
    ride: team,
    rideTemplate: team,
    route: team,
    post: team,
    trip: team,
    teamPage: team,
    ad: team,
  );
}
