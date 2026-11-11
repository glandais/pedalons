import 'package:pedalons/api/generated/export.dart' as api;

/// Valeurs neutres des champs calculés du contrat 13.7.0 (docs/LEDGER_*.md
/// API-176), pour les jeux de données qui construisent un DTO à la main.
/// Aucun écran ne les lit encore (lot 5).
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
