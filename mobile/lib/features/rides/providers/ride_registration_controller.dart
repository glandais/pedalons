import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/api_error_handler.dart';
import '../data/ride_repository.dart';
import 'participation_changes.dart';
import 'ride_detail_provider.dart';

/// Pourquoi une inscription a échoué, à la granularité que le bandeau rend.
///
/// Quatre motifs, parce que quatre phrases différentes valent la peine d'être
/// écrites. Le générique n'est pas un fourre-tout honteux : il porte le message
/// résolu par [resolveApiError] — donc l'explication du serveur quand il y en a
/// une, et le motif hors-ligne quand c'est le cas — et propose « Réessayer ».
enum RegistrationFailureReason {
  /// Le serveur répond que l'utilisateur est déjà inscrit **ailleurs** dans
  /// cette sortie, sans que l'app l'ait su : l'inscription a été faite sur un
  /// autre appareil. Le filet d'une course entre deux appareils — le détail
  /// redemandé, les cartes offrent alors « Changer pour {groupe} » (ledger
  /// `MOB-134`, lot 8). L'app ne pose plus ce motif d'elle-même : rejoindre
  /// depuis un autre groupe passe par [RideRegistrationController.switchGroup].
  alreadyRegistered,

  /// Le groupe visé a atteint sa capacité. État **terminal** : il n'y a pas de
  /// liste d'attente (§5.1), donc rien à proposer.
  groupFull,

  /// L'équipe n'accepte que ses membres. Renvoie vers l'équipe.
  notMember,

  /// Tout le reste, hors-ligne compris.
  generic,
}

/// Un échec d'inscription, **persistant** : c'est un état, pas un événement.
///
/// Il **nomme le groupe fautif**. « Grupetto » n'est pas « Groupe 2 », et
/// savoir lequel a refusé est la moitié de l'information — c'est précisément ce
/// que le `SnackBar` de la v1 perdait, quand la barre d'onglets ne le masquait
/// pas purement et simplement.
@immutable
class RegistrationFailure {
  const RegistrationFailure({
    required this.reason,
    required this.groupId,
    required this.groupName,
    required this.message,
    this.leaving = false,
  });

  final RegistrationFailureReason reason;

  /// Le groupe qu'on essayait de rejoindre ou de quitter — son identifiant
  /// **et** son nom. L'identifiant parce qu'une action de reprise doit viser
  /// le même groupe sans le retrouver par son libellé, que rien n'oblige à
  /// être unique.
  final String groupId;
  final String groupName;

  /// Le message résolu, rendu en corps de bandeau.
  final String message;

  /// L'échec est celui d'une désinscription : « Réessayer » quitte à
  /// nouveau, au lieu de rejoindre.
  final bool leaving;
}

/// L'état de l'inscription à une sortie.
///
/// Le `RideDto` vit **ici** et non dans le seul `rideDetailProvider` parce que
/// la bascule doit être optimiste : le bouton change en moins de 16 ms, avant
/// tout aller-retour réseau, et se rétablit intégralement si l'appel échoue.
/// Un `AsyncValue` rechargé n'offre pas ce point de reprise.
@immutable
class RideRegistrationState {
  const RideRegistrationState({
    required this.ride,
    this.pendingGroupId,
    this.failure,
  });

  final AsyncValue<RideDto> ride;

  /// Le groupe sur lequel un appel est en vol, s'il y en a un. Un seul à la
  /// fois : une seconde demande pendant qu'une première est en vol est ignorée
  /// plutôt que mise en file.
  final String? pendingGroupId;

  final RegistrationFailure? failure;

  RideRegistrationState copyWith({
    AsyncValue<RideDto>? ride,
    String? pendingGroupId,
    RegistrationFailure? failure,
    bool clearPending = false,
    bool clearFailure = false,
  }) => RideRegistrationState(
    ride: ride ?? this.ride,
    pendingGroupId: clearPending
        ? null
        : (pendingGroupId ?? this.pendingGroupId),
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Le contrôleur d'inscription d'une sortie.
///
/// `autoDispose` : il n'a de sens que tant que l'écran de la sortie est ouvert.
/// Le détail, lui, survit — c'est `rideDetailProvider` qui le porte, et
/// l'accueil s'en sert.
final rideRegistrationProvider = StateNotifierProvider.autoDispose
    .family<RideRegistrationController, RideRegistrationState, RideKey>((
      Ref ref,
      RideKey key,
    ) {
      final RideRegistrationController controller = RideRegistrationController(
        ref,
        key,
      );
      // Le détail reste la source de vérité : toute invalidation externe
      // (pull-to-refresh, retour d'un autre écran, succès d'inscription) se
      // propage ici sans code de synchronisation.
      ref.listen<AsyncValue<RideDto>>(
        rideDetailProvider(key),
        (AsyncValue<RideDto>? _, AsyncValue<RideDto> next) =>
            controller.adopt(next),
        fireImmediately: true,
      );
      return controller;
    });

/// La séquence d'inscription du §2.1 du plan, en un seul endroit :
///
/// 1. si un **autre** groupe porte `registered == true`, rejoindre est un
///    changement de groupe ([switchGroup]) : `joinGroup` répondrait 400 ;
/// 2. mutation optimiste locale ;
/// 3. `joinGroup` / `leaveGroup` / `switchGroup` — **un seul appel**, jamais une boucle sur
///    tous les groupes ;
/// 4. succès → invalidation du détail partagé, puis
///    [notifyParticipationChanged] pour l'accueil, le profil et le calendrier ;
/// 5. échec → **rétablissement complet** de l'état d'avant, puis bandeau.
///
/// Aucun `showSnackBar` : le lot 2 en interdit l'usage dans `features/rides`.
class RideRegistrationController extends StateNotifier<RideRegistrationState> {
  RideRegistrationController(this._ref, this._key)
    : super(const RideRegistrationState(ride: AsyncValue<RideDto>.loading()));

  final Ref _ref;
  final RideKey _key;

  RideRepository get _repository => _ref.read(rideRepositoryProvider);

  RideDto? get _ride => state.ride.value;

  /// Adopte le détail rafraîchi — sauf pendant un appel, où l'état optimiste
  /// doit tenir jusqu'à la réponse.
  void adopt(AsyncValue<RideDto> detail) {
    if (state.pendingGroupId != null) return;
    state = state.copyWith(ride: detail);
  }

  void dismissFailure() => state = state.copyWith(clearFailure: true);

  /// Rejoindre [groupId].
  Future<void> join(String groupId) async {
    final RideDto? ride = _ride;
    if (ride == null || state.pendingGroupId != null) return;

    final RideGroupDto? target = _groupById(ride, groupId);
    if (target == null) return;

    // (1) L'exclusivité se lit **avant** l'appel, sur `registeredGroupId`,
    // sans parcourir `participants[]` : inscrit ailleurs, rejoindre est un
    // changement de groupe, l'appel atomique (ledger `API-171`). Le bandeau
    // d'exclusivité et son « Quitter {groupe} » ont disparu avec « Changer
    // pour » sur les cartes (docs/LEDGER_*.md MOB-134, lot 8).
    final RideGroupDto? current = ride.joinedGroup;
    if (current != null && current.id != groupId) return switchGroup(groupId);

    // (2) Bascule optimiste.
    state = state.copyWith(
      ride: AsyncValue<RideDto>.data(_withRegistration(ride, groupId)),
      pendingGroupId: groupId,
      clearFailure: true,
    );

    // L'écran peut se fermer pendant l'appel : le contrôleur reste en vie
    // jusqu'à la réponse, sans quoi les vues dérivées ne seraient pas
    // prévenues d'une inscription pourtant faite.
    final KeepAliveLink alive = _ref.keepAlive();
    try {
      // (3) Un appel.
      await _repository.joinGroup(_key.teamSlug, _key.rideSlug, groupId);
      // (4) Le détail partagé redevient la source, et toutes les vues qui
      // dérivent de mes participations (accueil, profil, calendrier) sont
      // prévenues : elles ne lisent pas ce détail-ci.
      state = state.copyWith(clearPending: true);
      _ref.invalidate(rideDetailProvider(_key));
      notifyParticipationChanged(
        _ref,
        publicationId: ride.id,
        registered: true,
      );
    } catch (error, stackTrace) {
      // (5) Rétablissement **complet** avant d'expliquer : le bouton doit
      // revenir à « Rejoindre », sans quoi l'utilisateur lit un état qui n'a
      // jamais existé côté serveur.
      _fail(
        previous: ride,
        group: target,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      alive.close();
    }
  }

  /// Quitter [groupId].
  Future<void> leave(String groupId) async {
    final RideDto? ride = _ride;
    if (ride == null || state.pendingGroupId != null) return;

    final RideGroupDto? target = _groupById(ride, groupId);
    if (target == null) return;

    state = state.copyWith(
      ride: AsyncValue<RideDto>.data(_withRegistration(ride, null)),
      pendingGroupId: groupId,
      clearFailure: true,
    );

    final KeepAliveLink alive = _ref.keepAlive();
    try {
      await _repository.leaveGroup(_key.teamSlug, _key.rideSlug, groupId);
      state = state.copyWith(clearPending: true);
      _ref.invalidate(rideDetailProvider(_key));
      notifyParticipationChanged(
        _ref,
        publicationId: ride.id,
        registered: false,
      );
    } catch (error, stackTrace) {
      _fail(
        previous: ride,
        group: target,
        error: error,
        stackTrace: stackTrace,
        leaving: true,
      );
    } finally {
      alive.close();
    }
  }

  /// Passer dans [groupId] depuis le groupe où l'on est inscrit — « Changer
  /// pour {groupe} » des cartes de groupe et de la page d'un groupe.
  ///
  /// **Un seul appel**, l'endpoint atomique `…/groups/{groupId}/switch`
  /// (ledger `API-171`) : l'ancien « quitter puis rejoindre » laissait, sur
  /// un groupe devenu complet entre les deux, la personne inscrite nulle part.
  /// Même séquence que [join] : bascule optimiste (l'ancien groupe perd une
  /// place, le nouveau en gagne une), puis rétablissement complet sur échec.
  /// Sans inscription dans la sortie, c'est un [join] ; dans ce groupe déjà,
  /// rien à faire.
  Future<void> switchGroup(String groupId) async {
    final RideDto? ride = _ride;
    if (ride == null || state.pendingGroupId != null) return;

    final RideGroupDto? target = _groupById(ride, groupId);
    if (target == null) return;
    final RideGroupDto? current = ride.joinedGroup;
    if (current == null) return join(groupId);
    if (current.id == groupId) return;

    state = state.copyWith(
      ride: AsyncValue<RideDto>.data(_withRegistration(ride, groupId)),
      pendingGroupId: groupId,
      clearFailure: true,
    );

    final KeepAliveLink alive = _ref.keepAlive();
    try {
      await _repository.switchGroup(_key.teamSlug, _key.rideSlug, groupId);
      state = state.copyWith(clearPending: true);
      _ref.invalidate(rideDetailProvider(_key));
      notifyParticipationChanged(
        _ref,
        publicationId: ride.id,
        registered: true,
      );
    } catch (error, stackTrace) {
      _fail(
        previous: ride,
        group: target,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      alive.close();
    }
  }

  void _fail({
    required RideDto previous,
    required RideGroupDto group,
    required Object error,
    required StackTrace stackTrace,
    bool leaving = false,
  }) {
    final ApiError resolved = resolveApiError(error, stackTrace);
    state = RideRegistrationState(
      ride: AsyncValue<RideDto>.data(previous),
      failure: RegistrationFailure(
        reason: switch (resolved.code) {
          'GROUP_FULL' => RegistrationFailureReason.groupFull,
          'ALREADY_REGISTERED' => RegistrationFailureReason.alreadyRegistered,
          'FORBIDDEN' => RegistrationFailureReason.notMember,
          _ => RegistrationFailureReason.generic,
        },
        groupId: group.id,
        groupName: group.name,
        message: resolved.message,
        leaving: leaving,
      ),
    );
    // L'état affiché ne reflète peut-être plus le serveur — un groupe devenu
    // complet vient précisément de le périmer. On le redemande.
    _ref.invalidate(rideDetailProvider(_key));
    // Déjà inscrit : l'inscription existe côté serveur sans que l'app l'ait
    // su (faite ailleurs). Les vues dérivées sont aussi périmées que ce
    // détail-ci, et ce qu'on croyait savoir de cette sortie ne tient plus.
    if (resolved.code == 'ALREADY_REGISTERED') {
      notifyParticipationChanged(_ref, publicationId: previous.id);
    }
  }

  RideGroupDto? _groupById(RideDto ride, String id) {
    for (final RideGroupDto g in ride.groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Applique localement l'inscription à [groupId] (ou la désinscription si
  /// `null`), en tenant `countParticipants`, `full` et `registeredGroupId`
  /// cohérents — c'est ce que le serveur renverra.
  RideDto _withRegistration(RideDto ride, String? groupId) {
    final List<RideGroupDto> groups = <RideGroupDto>[
      for (final RideGroupDto g in ride.groups)
        if (g.id == groupId && !g.registered)
          _shift(g, registered: true, delta: 1)
        else if (g.registered && g.id != groupId)
          _shift(g, registered: false, delta: -1)
        else
          g,
    ];
    final bool wasRegistered = ride.registeredGroupId != null;
    final bool isRegistered = groupId != null;
    RideGroupDto? joined;
    for (final RideGroupDto g in groups) {
      if (g.id == groupId) joined = g;
    }
    return ride.copyWith(
      groups: groups,
      registered: isRegistered,
      registeredGroupId: groupId,
      registeredGroup: joined,
      participantCount:
          ride.participantCount +
          (isRegistered ? (wasRegistered ? 0 : 1) : (wasRegistered ? -1 : 0)),
    );
  }

  RideGroupDto _shift(
    RideGroupDto g, {
    required bool registered,
    required int delta,
  }) {
    final int count = (g.countParticipants + delta).clamp(0, 1 << 30);
    final int? max = g.maxParticipants;
    return g.copyWith(
      registered: registered,
      countParticipants: count,
      full: max != null && count >= max,
    );
  }
}
