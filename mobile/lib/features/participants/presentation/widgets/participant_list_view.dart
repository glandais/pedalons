import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../../keys.dart';
import '../../domain/participant_query.dart';
import '../../providers/participant_list_provider.dart';

/// La liste des participants, **lue et cherchée côté serveur** (ledger
/// `API-12`) : champ de recherche, pages successives derrière « Afficher
/// plus », états vide, filtré et d'erreur, marque du meneur.
///
/// Le corps de `ParticipantsSheet`, et l'onglet Participants de la page d'un
/// groupe (ledger `MOB-67`), qui l'embarque tel quel.
class ParticipantListView extends ConsumerStatefulWidget {
  const ParticipantListView({
    super.key,
    required this.source,
    required this.count,
    this.organizerId,
    this.emptyMessageKey = 'participants.emptyMessage',
    this.team,
    this.alwaysSearchable = false,
    this.searchHintKey,
    this.noMatchMessageKey,
  });

  /// De qui lister les participants.
  final ParticipantSource source;

  /// Le total connu avant la première page.
  final int count;

  /// Le meneur **désigné**, quand il y en a un. `null` est le cas courant, et
  /// il n'y a jamais de repli sur `createdBy`.
  final String? organizerId;

  final String emptyMessageKey;

  /// L'équipe qui modère un membre signalé depuis cette liste. Sans elle, les
  /// lignes ne s'ouvrent pas.
  final TeamPublicationDto? team;

  /// Montrer la recherche quel que soit le total ; sinon, au-delà de huit.
  final bool alwaysSearchable;

  /// Le texte d'invite de la recherche, par défaut `participants.search`.
  final String? searchHintKey;

  /// Le message de la recherche sans résultat, par défaut celui qui cite la
  /// saisie (`participants.noMatchMessage`).
  final String? noMatchMessageKey;

  @override
  ConsumerState<ParticipantListView> createState() =>
      _ParticipantListViewState();
}

class _ParticipantListViewState extends ConsumerState<ParticipantListView> {
  /// La recherche partie au serveur — `PdlSearchField` débat déjà la saisie.
  String _search = '';

  Future<void> _openMemberMenu(PublicUserDto person) {
    final TeamPublicationDto team = widget.team!;
    return showModerationMenu(
      context,
      title: person.displayName,
      subject: ModerationSubject(
        teamSlug: team.slug,
        type: ReportTargetType.member,
        id: person.id,
        teamName: team.name,
        memberName: person.displayName,
      ),
      blockUserId: person.id,
      blockUserName: person.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );

    final ParticipantQuery query = ParticipantQuery(
      widget.source,
      search: _search,
    );
    final PagedListState<PublicUserDto> state = ref.watch(
      participantListProvider(query),
    );
    final ParticipantListNotifier notifier = ref.read(
      participantListProvider(query).notifier,
    );

    // `leader` nul est le **cas courant** : la plupart des groupes n'en
    // désignent pas. Rien n'est alors rendu — et surtout jamais un repli sur
    // `createdBy`, qui vaut le créateur de la sortie sur tous ses groupes.
    final String? leaderId = widget.organizerId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Au-delà de ce que le détail embarque, la liste ne tient plus d'un
        // coup d'œil : la recherche devient utile.
        if (widget.alwaysSearchable || widget.count > 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: PdlSearchField(
              value: _search,
              hintText: (widget.searchHintKey ?? 'participants.search').tr(),
              onChanged: (String? v) =>
                  setState(() => _search = (v ?? '').trim()),
              clearTooltip: 'common.clearSearch'.tr(),
            ),
          ),
        if (state.isLoadingInitial && state.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (state.initialError != null)
          PdlEmptyState(
            variant: PdlEmptyVariant.error,
            title: 'common.loadError'.tr(),
            message: getErrorMessage(state.initialError!),
            actions: <Widget>[
              PdlButton(
                label: 'common.retry'.tr(),
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                onPressed: notifier.loadFirstPage,
              ),
            ],
          )
        else if (state.items.isEmpty && _search.isEmpty)
          PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            title: 'participants.emptyTitle'.tr(),
            message: widget.emptyMessageKey.tr(),
          )
        else if (state.items.isEmpty)
          PdlEmptyState(
            variant: PdlEmptyVariant.filtered,
            title: 'participants.noMatchTitle'.tr(),
            message: widget.noMatchMessageKey != null
                ? widget.noMatchMessageKey!.tr()
                : 'participants.noMatchMessage'.tr(
                    namedArgs: <String, String>{'search': _search},
                  ),
            actions: <Widget>[
              PdlButton(
                label: 'common.clearSearch'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: () => setState(() => _search = ''),
              ),
            ],
          )
        else ...<Widget>[
          for (final PublicUserDto person in state.items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PdlPersonRow(
                key: keys.participants.person(person.id),
                name: person.displayName,
                imageUrl: person.avatarUrl,
                isCurrentUser: person.id == currentUserId,
                // Conditionnel deux fois : il faut un meneur désigné **et**
                // qu'il participe à ce groupe. Un meneur qui ne roule pas
                // n'apparaît pas dans cette liste, et rien ne le signale ici.
                organizerFlag: leaderId != null && person.id == leaderId,
                organizerLabel: 'participants.groupOrganizer'.tr(),
                // Signaler ou bloquer un participant — jamais soi-même. La
                // liste, elle, ne change pas : un blocage ne touche pas
                // l'organisation des sorties.
                onTap: widget.team == null || person.id == currentUserId
                    ? null
                    : () => _openMemberMenu(person),
              ),
            ),
          // Un bouton plutôt qu'un préchargement au défilement : la feuille
          // construit toutes ses lignes d'un coup, un déclenchement « à trois
          // lignes de la fin » y chargerait toutes les pages d'affilée.
          if (state.hasMore && !state.isLoadingNext && state.nextError == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: <Widget>[
                  // Le pied commun se tait entre deux pages ; ici la liste
                  // attend un geste, elle doit dire où on en est.
                  Text(
                    'pagination.progressNamed'.tr(
                      namedArgs: <String, String>{
                        'loaded': '${state.items.length}',
                        'noun': 'participants.noun'.tr(),
                        'total': '${state.total ?? widget.count}',
                      },
                    ),
                    key: keys.participants.progress,
                    textAlign: TextAlign.center,
                    style: t.xs,
                  ),
                  const SizedBox(height: PdlSpacing.chipGap),
                  PdlButton(
                    key: keys.participants.loadMore,
                    label: 'participants.loadMore'.tr(),
                    variant: PdlButtonVariant.outline,
                    size: PdlButtonSize.sm,
                    onPressed: notifier.loadNextPage,
                  ),
                ],
              ),
            ),
          PagedListFooter(
            key: keys.participants.footer,
            state: state,
            onRetry: notifier.retryNextPage,
            itemNoun: 'participants.noun'.tr(),
          ),
        ],
      ],
    );
  }
}
