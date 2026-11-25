import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../data/team_repository.dart';
import '../domain/member_filters.dart';

/// Filtres courants du trombinoscope d'une équipe.
final memberFiltersProvider = StateProvider.autoDispose
    .family<MemberFilters, String>(
      (ref, teamSlug) => MemberFilters(teamSlug: teamSlug),
    );

/// Filtres courants de l'écran « Membres » (docs/LEDGER_*.md
/// MOB-167). **Distincts** de ceux du trombinoscope : filtrer l'un ne doit pas
/// filtrer l'autre, resté ouvert dessous. La liste, elle, est la même
/// ([teamMembersProvider]).
final adminMemberFiltersProvider = StateProvider.autoDispose
    .family<MemberFilters, String>(
      (ref, teamSlug) => MemberFilters(teamSlug: teamSlug),
    );

/// Le trombinoscope paginé pour un jeu de filtres.
final teamMembersProvider = StateNotifierProvider.autoDispose
    .family<TeamMembersNotifier, PagedListState<MemberDto>, MemberFilters>((
      ref,
      filters,
    ) {
      final TeamMembersNotifier notifier = TeamMembersNotifier(
        ref.watch(teamRepositoryProvider),
        filters,
      );
      ref.listen<TeamMembersChange?>(_teamMembersChangeProvider, (
        TeamMembersChange? _,
        TeamMembersChange? change,
      ) {
        if (change != null) notifier.apply(change);
      });
      return notifier;
    });

/// Ce qui vient d'arriver aux membres de [teamSlug] — ce que
/// [notifyTeamMembersChanged] annonce aux listes ouvertes.
@immutable
class TeamMembersChange {
  /// Le rôle de la personne [userId] est désormais [role].
  const TeamMembersChange.roleChanged(
    this.teamSlug, {
    required String this.userId,
    required TeamRole this.role,
  }) : removed = false;

  /// La personne [userId] a été retirée de l'équipe.
  const TeamMembersChange.removed(this.teamSlug, {required String this.userId})
    : removed = true,
      role = null;

  /// Les membres ont changé sans qu'on sache comment — une invitation
  /// peut-être acceptée entre-temps : les listes sont relues.
  const TeamMembersChange.unknown(this.teamSlug)
    : userId = null,
      role = null,
      removed = false;

  final String teamSlug;

  /// L'identifiant de la **personne**, pas celui de l'adhésion.
  final String? userId;
  final TeamRole? role;
  final bool removed;
}

/// Le dernier changement annoncé : les listes ouvertes l'écoutent
/// ([teamMembersProvider]) ; une liste ouverte ensuite lit le serveur, à jour.
final _teamMembersChangeProvider = StateProvider<TeamMembersChange?>(
  (Ref ref) => null,
);

/// Annonce [change] aux listes de membres **de cette équipe** — la gestion des
/// membres, le trombinoscope resté ouvert dessous, quels que soient leurs
/// filtres (docs/LEDGER_*.md MOB-167). Chacune le reporte à sa place
/// ([TeamMembersNotifier.apply]) : la liste n'est pas vidée, et la personne
/// qui administre une grande équipe reste où elle en était. Les listes des
/// autres équipes ne bougent pas.
///
/// Prend le **conteneur**, comme `notifyTeamChanged` : l'écran qui a lancé
/// l'écriture peut être quitté avant sa réponse.
void notifyTeamMembersChanged(
  ProviderContainer container,
  TeamMembersChange change,
) {
  container.read(_teamMembersChangeProvider.notifier).state = change;
}

class TeamMembersNotifier extends PagedListNotifier<MemberDto> {
  final TeamRepository _repository;
  final MemberFilters _filters;

  TeamMembersNotifier(this._repository, this._filters);

  @override
  Future<PageResult<MemberDto>> fetchPage(int page) {
    return _repository.fetchMembers(
      filters: _filters,
      page: page,
      size: pageSize,
    );
  }

  @override
  Object? itemKey(MemberDto item) => item.id;

  /// Reporte [change] dans la liste **sans la recharger** quand c'est
  /// possible :
  ///
  /// * une personne retirée quitte la liste ;
  /// * un rôle modifié est réécrit sur sa ligne (l'ordre est par nom : la
  ///   ligne ne bouge pas) — sauf sous un filtre de rôle : la personne quitte
  ///   la liste si son nouveau rôle n'est plus celui du filtre, et la liste
  ///   est relue si elle vient d'y entrer ;
  /// * un changement inconnu fait relire la liste, ses lignes restant à
  ///   l'écran.
  ///
  /// Une personne qui n'est pas dans les pages chargées n'a pas de ligne à
  /// reporter — sa page arrivera à jour —, mais le **total** de la liste, lui,
  /// a pu changer : sans filtre, elle en faisait partie et le total perd un ;
  /// sous un filtre, on ne sait pas si elle lui correspondait, et la liste
  /// est relue. Une liste entièrement chargée qui ne la montre pas ne la
  /// comptait pas.
  void apply(TeamMembersChange change) {
    if (change.teamSlug != _filters.teamSlug || !mounted) return;
    final String? userId = change.userId;
    if (userId == null) {
      unawaited(refresh());
      return;
    }
    MemberDto? shown;
    for (final MemberDto member in state.items) {
      if (member.user.id == userId) shown = member;
    }
    final TeamRole? role = change.role;
    final TeamRole? filter = _filters.role;
    if (change.removed || role == null) {
      if (shown != null) {
        unawaited(removeItem(shown.id));
      } else if (state.hasMore) {
        if (_filters.isFiltered) {
          unawaited(refresh());
        } else {
          final int? total = state.total;
          if (total != null && total > 0) {
            state = state.copyWith(total: total - 1);
          }
        }
      }
      return;
    }
    if (shown == null) {
      // Sous le filtre de son nouveau rôle, la personne vient d'entrer dans
      // la liste, à une place que seul le serveur connaît ; sous un autre,
      // elle vient peut-être d'en sortir, sur une page pas encore lue.
      if (filter == role || (filter != null && state.hasMore)) {
        unawaited(refresh());
      }
      return;
    }
    if (filter != null && filter != role) {
      unawaited(removeItem(shown.id));
    } else {
      replaceItem(shown.id, shown.copyWith(role: role.json));
    }
  }
}
