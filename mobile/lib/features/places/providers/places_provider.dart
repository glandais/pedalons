import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../../rides/providers/ride_editor_providers.dart';
import '../data/places_repository.dart';
import '../domain/place_filters.dart';

/// La recherche courante de l'écran « Lieux » d'une équipe.
final placeFiltersProvider = StateProvider.autoDispose
    .family<PlaceFilters, String>(
      (Ref ref, String teamSlug) => PlaceFilters(teamSlug: teamSlug),
    );

/// Ce qui vient d'arriver à un lieu de [teamSlug].
enum PlaceChangeKind { created, updated, deleted }

/// Un lieu créé, réécrit ou supprimé — ce que [notifyPlacesChanged] annonce
/// aux listes ouvertes.
@immutable
class PlaceChange {
  const PlaceChange.created(this.teamSlug, PlaceDetailDto this.place)
    : kind = PlaceChangeKind.created,
      placeId = null;

  const PlaceChange.updated(this.teamSlug, PlaceDetailDto this.place)
    : kind = PlaceChangeKind.updated,
      placeId = null;

  const PlaceChange.deleted(this.teamSlug, String this.placeId)
    : kind = PlaceChangeKind.deleted,
      place = null;

  final String teamSlug;
  final PlaceChangeKind kind;

  /// Le lieu tel que le serveur l'a rendu (création, modification).
  final PlaceDetailDto? place;

  /// Le lieu supprimé.
  final String? placeId;
}

/// Le dernier changement annoncé : les listes ouvertes l'écoutent
/// ([teamPlacesProvider]) ; une liste ouverte ensuite lit le serveur, à jour.
final _placeChangeProvider = StateProvider<PlaceChange?>((Ref ref) => null);

/// Les lieux d'une équipe, page par page (20), pour une recherche donnée.
final teamPlacesProvider = StateNotifierProvider.autoDispose
    .family<TeamPlacesNotifier, PagedListState<PlaceDetailDto>, PlaceFilters>((
      Ref ref,
      PlaceFilters filters,
    ) {
      final TeamPlacesNotifier notifier = TeamPlacesNotifier(
        ref.watch(placesRepositoryProvider),
        filters,
      );
      ref.listen<PlaceChange?>(_placeChangeProvider, (
        PlaceChange? _,
        PlaceChange? change,
      ) {
        if (change != null) notifier.apply(change);
      });
      return notifier;
    });

class TeamPlacesNotifier extends PagedListNotifier<PlaceDetailDto> {
  TeamPlacesNotifier(this._repository, this._filters);

  final PlacesRepository _repository;
  final PlaceFilters _filters;

  @override
  Future<PageResult<PlaceDetailDto>> fetchPage(int page) {
    return _repository.fetchPlaces(
      filters: _filters,
      page: page,
      size: pageSize,
    );
  }

  @override
  Object? itemKey(PlaceDetailDto item) => item.id;

  /// Reporte [change] dans la liste **sans la recharger** quand c'est
  /// possible — la personne garde sa place :
  ///
  /// * un lieu supprimé quitte la liste ;
  /// * un lieu réécrit est remplacé à sa place — sauf sous une recherche, où
  ///   il ne lui correspond peut-être plus : la liste est alors relue ;
  /// * un lieu créé n'a pas de place connue (l'ordre est celui du serveur) :
  ///   la liste est relue, ses lignes restant à l'écran entre-temps.
  void apply(PlaceChange change) {
    if (change.teamSlug != _filters.teamSlug || !mounted) return;
    switch (change.kind) {
      case PlaceChangeKind.deleted:
        unawaited(removeItem(change.placeId!));
      case PlaceChangeKind.updated:
        final PlaceDetailDto place = change.place!;
        if (_filters.isFiltered || !replaceItem(place.id, place)) {
          unawaited(refresh());
        }
      case PlaceChangeKind.created:
        unawaited(refresh());
    }
  }
}

/// **Le** point où l'app dit « un lieu d'une équipe vient de changer » — créé,
/// réécrit ou supprimé (docs/LEDGER_*.md MOB-168).
///
/// Les listes ouvertes de l'écran « Lieux » reportent le changement
/// ([TeamPlacesNotifier.apply]), et le lieu que les éditeurs de sortie et de
/// voyage ont déjà lu pour le nommer et en tirer le fuseau
/// ([editorPlaceProvider]) est relu — un éditeur resté ouvert sous l'écran
/// montrerait sinon l'ancien nom, ou un lieu supprimé. Leur recherche de
/// lieux, elle, n'a pas de cache : elle interroge le serveur à chaque
/// ouverture de la feuille.
///
/// Prend le **conteneur**, comme `notifyTeamChanged` : l'écriture est une
/// requête, et l'écran qui l'a lancée peut être quitté avant sa réponse.
void notifyPlacesChanged(ProviderContainer container, PlaceChange change) {
  container.read(_placeChangeProvider.notifier).state = change;
  container.invalidate(editorPlaceProvider);
}
