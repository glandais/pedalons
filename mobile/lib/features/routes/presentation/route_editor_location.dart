import '../../../config/paths.dart';

/// Le paramètre d'adresse qui fait ouvrir le sélecteur de fichier dès que
/// l'éditeur de parcours s'affiche (« Remplacer le fichier GPX »).
const String kRouteEditGpxQuery = 'gpx';
const String kRouteEditGpxReplace = 'replace';

/// L'adresse de l'éditeur d'un parcours en modification ; avec [replaceGpx],
/// `RouteEditorPage` lance aussitôt le choix d'un nouveau GPX
/// (docs/LEDGER_*.md MOB-79). Hors contrat des routes : le paramètre ne sert
/// qu'aux liens internes.
String routeEditLocation(
  String teamSlug,
  String routeSlug, {
  bool replaceGpx = false,
}) => replaceGpx
    ? '${Paths.routeEdit(teamSlug, routeSlug)}'
          '?$kRouteEditGpxQuery=$kRouteEditGpxReplace'
    : Paths.routeEdit(teamSlug, routeSlug);
