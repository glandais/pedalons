import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/api_error_handler.dart';
import '../data/team_repository.dart';
import 'membership_scoped_content.dart';
import 'team_providers.dart';

/// L'état d'adhésion à **une** équipe, du point de vue de sa page.
///
/// Le `TeamDetailDto` vit ici et pas seulement dans `teamDetailProvider` pour
/// la même raison que sur une sortie ou un voyage : la bascule est optimiste,
/// le bouton change avant tout aller-retour et se rétablit intégralement si
/// l'appel échoue.
///
/// **L'état est résolu avant le premier paint** : `TeamDetailDto.role` arrive
/// avec l'équipe, et la page n'est montée qu'une fois l'équipe là. Il n'y a
/// donc jamais de bouton « Rejoindre » qui devient « Quitter » après coup —
/// c'est le défaut que cette tâche corrige.
@immutable
class TeamMembershipState {
  const TeamMembershipState({
    required this.team,
    this.pending = false,
    this.pendingJoin = false,
    this.failure,
  });

  final AsyncValue<TeamDetailDto> team;

  /// Un appel est en vol. Une seconde demande est ignorée, pas mise en file.
  final bool pending;

  /// Sens de l'appel en vol. Il ne se déduit **pas** de [isMember] : la bascule
  /// étant optimiste, le rôle a déjà changé quand l'appel part, et le bouton
  /// afficherait « Départ… » pendant une adhésion.
  final bool pendingJoin;

  /// Échec courant, déjà mis en mots. Nul tant que rien n'a échoué.
  final String? failure;

  bool get isMember => team.value?.role != null;

  TeamMembershipState copyWith({
    AsyncValue<TeamDetailDto>? team,
    bool? pending,
    bool? pendingJoin,
    String? failure,
    bool clearFailure = false,
  }) => TeamMembershipState(
    team: team ?? this.team,
    pending: pending ?? this.pending,
    pendingJoin: pendingJoin ?? this.pendingJoin,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// `autoDispose` : lié à la page ouverte. Le détail, lui, survit.
final teamMembershipControllerProvider = StateNotifierProvider.autoDispose
    .family<TeamMembershipController, TeamMembershipState, String>((
      Ref ref,
      String teamSlug,
    ) {
      final TeamMembershipController controller = TeamMembershipController(
        ref,
        teamSlug,
      );
      ref.listen<AsyncValue<TeamDetailDto>>(
        teamDetailProvider(teamSlug),
        (AsyncValue<TeamDetailDto>? _, AsyncValue<TeamDetailDto> next) =>
            controller.adopt(next),
        fireImmediately: true,
      );
      return controller;
    });

/// Adhérer et quitter : bascule optimiste, un appel, invalidation du détail
/// partagé, rétablissement complet puis bandeau en cas d'échec.
///
/// Aucun `showSnackBar` : l'échec est un état, rendu en `PdlBanner` qui nomme
/// sa cause.
class TeamMembershipController extends StateNotifier<TeamMembershipState> {
  TeamMembershipController(this._ref, this._teamSlug)
    : super(
        const TeamMembershipState(team: AsyncValue<TeamDetailDto>.loading()),
      );

  final Ref _ref;
  final String _teamSlug;

  TeamRepository get _repository => _ref.read(teamRepositoryProvider);

  /// Adopte le détail rafraîchi — sauf pendant un appel, où l'état optimiste
  /// doit tenir jusqu'à la réponse.
  void adopt(AsyncValue<TeamDetailDto> detail) {
    if (state.pending) return;
    // Un rafraîchissement ne renvoie **pas** la page aux squelettes : après une
    // adhésion, l'équipe est réinterrogée, et repasser par l'état de chargement
    // ferait clignoter tout l'écran pour un seul champ qui change.
    if (detail.isLoading && state.team.hasValue) return;
    state = state.copyWith(team: detail);
  }

  void dismissFailure() => state = state.copyWith(clearFailure: true);

  Future<void> join() => _toggle(join: true);

  Future<void> leave() => _toggle(join: false);

  Future<void> _toggle({required bool join}) async {
    final TeamDetailDto? team = state.team.value;
    if (team == null || state.pending) return;
    if ((team.role != null) == join) return;

    state = state.copyWith(
      team: AsyncValue<TeamDetailDto>.data(
        // `MEMBER` est ce que le serveur renverra : rejoindre ne fait de
        // personne un organisateur.
        team.copyWith(
          role: join ? 'MEMBER' : null,
          memberCount: (team.memberCount + (join ? 1 : -1)).clamp(0, 1 << 30),
        ),
      ),
      pending: true,
      pendingJoin: join,
      clearFailure: true,
    );

    try {
      if (join) {
        await _repository.joinTeam(_teamSlug);
      } else {
        await _repository.leaveTeam(_teamSlug);
      }
      state = state.copyWith(pending: false);
      // Le rôle change ce que l'équipe montre — sections réservées aux
      // membres comprises — et « Mes équipes » vient d'en gagner ou d'en
      // perdre une.
      _ref.invalidate(teamDetailProvider(_teamSlug));
      _ref.invalidate(myTeamsProvider);
      // Et les droits calculés des entités déjà lues (docs/LEDGER_*.md
      // MOB-137).
      invalidateMembershipScopedContent((p) => _ref.invalidate(p));
    } catch (error, stackTrace) {
      final ApiError resolved = resolveApiError(error, stackTrace);
      // Rétablissement **complet** avant d'expliquer : le bouton revient à ce
      // qu'il était, sans quoi on lirait un état qui n'a jamais existé côté
      // serveur.
      state = TeamMembershipState(
        team: AsyncValue<TeamDetailDto>.data(team),
        failure: resolved.message,
      );
      _ref.invalidate(teamDetailProvider(_teamSlug));
    }
  }
}
