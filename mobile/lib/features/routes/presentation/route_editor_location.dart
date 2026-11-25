import '../../../config/paths.dart';

/// Le paramètre d'adresse qui fait ouvrir le sélecteur de fichier dès que
/// l'éditeur de parcours s'affiche (« Remplacer le fichier GPX »).
const String kRouteEditGpxQuery = 'gpx';
const String kRouteEditGpxReplace = 'replace';
const String kRouteNewGpxImport = 'import';

/// Le paramètre qui ouvre le planificateur dès que l'éditeur d'un nouveau
/// parcours s'affiche (« Tracer sur la carte »).
const String kRouteNewDrawQuery = 'tracer';

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

/// Par où commence un nouveau parcours : le choix d'un GPX, ou le
/// planificateur — chacun son entrée dans les menus « Créer », plutôt que la
/// page de choix de l'éditeur (qui reste celle d'un lien nu).
enum RouteNewStart { importGpx, draw }

/// L'adresse de l'éditeur d'un nouveau parcours, qui commence par [start].
String routeNewLocation(String teamSlug, {RouteNewStart? start}) =>
    switch (start) {
      null => Paths.routeNew(teamSlug),
      RouteNewStart.importGpx =>
        '${Paths.routeNew(teamSlug)}?$kRouteEditGpxQuery=$kRouteNewGpxImport',
      RouteNewStart.draw => '${Paths.routeNew(teamSlug)}?$kRouteNewDrawQuery=1',
    };
