import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;

import '../../../api/generated/export.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../rides/providers/participation_changes.dart';
import '../data/trip_repository.dart';
import 'trip_detail_provider.dart';

/// Pourquoi une participation a échoué.
///
/// Deux motifs seulement — un voyage n'a pas de groupes, donc ni exclusivité ni
/// capacité : `TripDto` ne porte aucun `maxParticipants`. Le générique porte le
/// message résolu, hors-ligne compris.
enum TripParticipationFailureReason { notMember, generic }

@immutable
class TripParticipationFailure {
  const TripParticipationFailure({required this.reason, required this.message});

  final TripParticipationFailureReason reason;
  final String message;
}

/// L'état de la participation à un voyage.
///
/// Le `TripDto` vit ici et pas seulement dans `tripDetailProvider` pour la même
/// raison que sur la sortie : la bascule est **optimiste**, le bouton change
/// avant tout aller-retour et se rétablit intégralement si l'appel échoue.
@immutable
class TripParticipationState {
  const TripParticipationState({
    required this.trip,
    this.pending = false,
    this.failure,
  });

  final AsyncValue<TripDto> trip;

  /// Un appel est en vol. Une seconde demande est ignorée, pas mise en file.
  final bool pending;

  final TripParticipationFailure? failure;

  TripParticipationState copyWith({
    AsyncValue<TripDto>? trip,
    bool? pending,
    TripParticipationFailure? failure,
    bool clearFailure = false,
  }) => TripParticipationState(
    trip: trip ?? this.trip,
    pending: pending ?? this.pending,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// `autoDispose` : lié à l'écran ouvert, comme le détail (`tripDetailProvider`), que l'écran
/// garde en vie tant qu'il est ouvert.
final tripParticipationProvider = StateNotifierProvider.autoDispose
    .family<TripParticipationController, TripParticipationState, TripKey>((
      Ref ref,
      TripKey key,
    ) {
      final TripParticipationController controller =
          TripParticipationController(ref, key);
      ref.listen<AsyncValue<TripDto>>(
        tripDetailProvider(key),
        (AsyncValue<TripDto>? _, AsyncValue<TripDto> next) =>
            controller.adopt(next),
        fireImmediately: true,
      );
      return controller;
    });

/// La séquence de participation : bascule optimiste, un appel, invalidation du
/// détail partagé et des vues dérivées ([notifyParticipationChanged]),
/// rétablissement complet puis bandeau en cas d'échec.
///
/// **`registered` fait foi.** La v1 déduisait la participation en cherchant
/// l'utilisateur courant dans `participants[]` — une liste vide sans droit de
/// lecture, donc un faux négatif systématique pour qui n'était pas membre, et
/// une dépendance à `authProvider` dont l'écran n'a plus besoin.
///
/// Aucun `showSnackBar` : l'échec est un état, rendu en `PdlBanner`.
class TripParticipationController
    extends StateNotifier<TripParticipationState> {
  TripParticipationController(this._ref, this._key)
    : super(const TripParticipationState(trip: AsyncValue<TripDto>.loading()));

  final Ref _ref;
  final TripKey _key;

  TripRepository get _repository => _ref.read(tripRepositoryProvider);

  /// Adopte le détail rafraîchi — sauf pendant un appel, où l'état optimiste
  /// doit tenir jusqu'à la réponse.
  void adopt(AsyncValue<TripDto> detail) {
    if (state.pending) return;
    state = state.copyWith(trip: detail);
  }

  void dismissFailure() => state = state.copyWith(clearFailure: true);

  Future<void> join() => _toggle(join: true);

  Future<void> leave() => _toggle(join: false);

  Future<void> _toggle({required bool join}) async {
    final TripDto? trip = state.trip.value;
    if (trip == null || state.pending || trip.registered == join) return;

    state = state.copyWith(
      trip: AsyncValue<TripDto>.data(_withRegistration(trip, join)),
      pending: true,
      clearFailure: true,
    );

    // L'écran peut se fermer pendant l'appel : voir RideRegistrationController.
    final KeepAliveLink alive = _ref.keepAlive();
    try {
      if (join) {
        await _repository.joinTrip(_key.teamSlug, _key.tripSlug);
      } else {
        await _repository.leaveTrip(_key.teamSlug, _key.tripSlug);
      }
      state = state.copyWith(pending: false);
      _ref.invalidate(tripDetailProvider(_key));
      // Un voyage remonte aussi dans « À venir », dans le compteur du profil
      // et au calendrier (ses étapes) : mêmes vues dérivées qu'une sortie.
      notifyParticipationChanged(
        _ref,
        publicationId: trip.id,
        registered: join,
      );
    } catch (error, stackTrace) {
      final ApiError resolved = resolveApiError(error, stackTrace);
      state = TripParticipationState(
        // Rétablissement **complet** avant d'expliquer : le bouton revient à ce
        // qu'il était, sans quoi l'utilisateur lit un état qui n'a jamais
        // existé côté serveur.
        trip: AsyncValue<TripDto>.data(trip),
        failure: TripParticipationFailure(
          reason: resolved.code == 'FORBIDDEN'
              ? TripParticipationFailureReason.notMember
              : TripParticipationFailureReason.generic,
          message: resolved.message,
        ),
      );
      _ref.invalidate(tripDetailProvider(_key));
      // Déjà dans l'état visé côté serveur : l'app ne le savait pas, ses vues
      // dérivées non plus.
      if (resolved.code == 'ALREADY_REGISTERED' ||
          resolved.code == 'NOT_REGISTERED') {
        notifyParticipationChanged(_ref, publicationId: trip.id);
      }
    } finally {
      alive.close();
    }
  }

  /// Applique localement la participation, en tenant `participantCount`
  /// cohérent — c'est ce que le serveur renverra. `participants[]` n'est pas
  /// touché : y insérer un utilisateur fabriqué afficherait un avatar qui n'est
  /// pas celui du serveur, et l'invalidation qui suit le rend de toute façon.
  TripDto _withRegistration(TripDto trip, bool registered) => trip.copyWith(
    registered: registered,
    participantCount: (trip.participantCount + (registered ? 1 : -1)).clamp(
      0,
      1 << 30,
    ),
  );
}
