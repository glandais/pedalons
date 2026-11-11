import 'package:flutter/widgets.dart';

class _VisibilityKey extends ValueKey<String> {
  const _VisibilityKey(String value) : super('visibility_$value');
}

/// Le sélecteur de visibilité partagé des éditeurs et les feuilles de refus
/// `INCOMPATIBLE_VISIBILITY` (docs/LEDGER_*.md MOB-137).
class VisibilityKeys {
  /// L'explication qui remplace le sélecteur quand aucune valeur n'est
  /// permise (un parcours utilisé publiquement d'une équipe qui ne publie
  /// plus qu'en « Équipe »).
  final noneAllowed = const _VisibilityKey('noneAllowed');

  /// L'avertissement sous le sélecteur quand la valeur actuelle n'est plus
  /// permise.
  final notAllowed = const _VisibilityKey('notAllowed');

  /// L'aide d'une équipe privée : lisible par lien, hors des listes.
  final privateTeamHint = const _VisibilityKey('privateTeamHint');

  /// Le segment d'une valeur, par son nom JSON (`TEAM`, `PUBLIC`…).
  ValueKey<String> option(String visibility) =>
      _VisibilityKey('option_$visibility');

  /// La confirmation d'alignement des parcours (décision D5).
  final alignSheet = const _VisibilityKey('alignSheet');
  ValueKey<String> alignRoute(String slug) =>
      _VisibilityKey('alignRoute_$slug');
  final alignConfirm = const _VisibilityKey('alignConfirm');
  final alignCancel = const _VisibilityKey('alignCancel');

  /// Le refus d'un parcours qui sert publiquement (décision D6).
  final routeInUseSheet = const _VisibilityKey('routeInUseSheet');
  ValueKey<String> usage(String type, String slug) =>
      _VisibilityKey('usage_${type}_$slug');

  /// Le refus de restaurer une sortie dont des parcours sont redevenus
  /// « Équipe ».
  final restoreBlockedSheet = const _VisibilityKey('restoreBlockedSheet');
  ValueKey<String> restoreRoute(String slug) =>
      _VisibilityKey('restoreRoute_$slug');

  /// Le bouton qui referme une feuille de refus.
  final refusalClose = const _VisibilityKey('refusalClose');
}
