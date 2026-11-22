import 'package:flutter/foundation.dart';

/// Ce qui identifie un tracé qu'un écran affiche : le parcours d'une équipe
/// ([RouteKey]) ou un aperçu des outils GPX ([GpxPreviewKey], ledger
/// `MOB-178`).
///
/// La carte, le profil et leurs providers (`shownRouteProvider`,
/// `route_elevation_provider.dart`) ne lisent qu'un `ShownRoute` : la clé dit
/// seulement d'où il vient. Scellée, pour que chaque `switch` sur l'origine
/// soit exhaustif — un aperçu n'a ni équipe ni slug, et rien ne doit en
/// inventer.
@immutable
sealed class TrackKey {
  const TrackKey();
}

/// Ce qui identifie un parcours : son équipe et son slug.
@immutable
final class RouteKey extends TrackKey {
  const RouteKey({required this.teamSlug, required this.routeSlug});

  final String teamSlug;
  final String routeSlug;

  @override
  bool operator ==(Object other) =>
      other is RouteKey &&
      other.teamSlug == teamSlug &&
      other.routeSlug == routeSlug;

  @override
  int get hashCode => Object.hash(teamSlug, routeSlug);

  @override
  String toString() => 'RouteKey($teamSlug/$routeSlug)';
}

/// Ce qui identifie un aperçu GPX : son identifiant public, seul (ledger
/// `MOB-178`).
@immutable
final class GpxPreviewKey extends TrackKey {
  const GpxPreviewKey(this.previewId);

  final String previewId;

  @override
  bool operator ==(Object other) =>
      other is GpxPreviewKey && other.previewId == previewId;

  @override
  int get hashCode => previewId.hashCode;

  @override
  String toString() => 'GpxPreviewKey($previewId)';
}
