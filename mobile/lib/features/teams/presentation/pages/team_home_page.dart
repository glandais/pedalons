import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../ads/presentation/pages/ads_page.dart';
import '../../../feed/presentation/widgets/publication_feed_view.dart';
import '../../../routes/presentation/pages/routes_page.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/team_membership_controller.dart';
import '../../providers/team_providers.dart';
import '../widgets/team_header.dart';
import '../widgets/team_sections.dart';
import '../widgets/team_sections_bar.dart';
import 'team_about_page.dart';
import 'team_dashboard_page.dart';
import 'team_agenda_page.dart';
import 'team_members_page.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';

/// A team, whatever section of it is being looked at.
///
/// **One page owns the team's loading and error state.** Every team section is
/// this page with another [section]; the sections themselves receive a team
/// that has already arrived. That is the whole point of the task: the router
/// used to wrap each section in a widget that watched the team *and* rendered
/// an error of its own, while the section rendered a second one under it —
/// hence two stacked errors on a cold deep link, or a blank screen when the
/// wrapper answered with `SizedBox.shrink()`.
///
/// The row of sections is [content](TeamSectionsBar), pinned under the team
/// header, and the five global tabs stay visible: entering a team no longer
/// replaces the app's navigation.
class TeamHomePage extends ConsumerWidget {
  const TeamHomePage({
    super.key,
    required this.teamSlug,
    required this.section,
    this.agendaType,
    this.agendaScope = AgendaScope.upcoming,
    this.agendaView = AgendaView.list,
  });

  final String teamSlug;
  final TeamSectionKind section;

  /// Le type sur lequel l'Agenda s'ouvre — `teamTrips`, `?type=ride` —, puis
  /// libre. Sans effet hors de [TeamSectionKind.agenda].
  final PublicationType? agendaType;

  /// La période sur laquelle l'Agenda s'ouvre (`?w=me` : « Je participe »).
  final AgendaScope agendaScope;

  /// La vue sur laquelle l'Agenda s'ouvre : `teamCalendar` l'ouvre en
  /// calendrier.
  final AgendaView agendaView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le contrôleur d'adhésion **fait autorité** sur le détail rendu : c'est
    // lui qui porte la bascule optimiste. Il adopte `teamDetailProvider` et
    // le rend inchangé le reste du temps.
    final AsyncValue<TeamDetailDto> teamAsync = ref.watch(
      teamMembershipControllerProvider(teamSlug)
          .select((TeamMembershipState s) => s.team),
    );

    // Un lien sous un **ancien slug** : l'API répond avec l'équipe sous son
    // slug actuel. Tout ce qui est rendu dessous — le bouton d'adhésion de
    // l'en-tête, le bandeau d'échec, les sections — lit ses providers par
    // `team.slug`. La page passe donc elle aussi sur ce slug, pour qu'il n'y
    // ait qu'un contrôleur d'adhésion : sinon l'en-tête en ouvrirait un second,
    // encore en chargement, et proposerait « Sur invitation » à un membre.
    final String? currentSlug = teamAsync.value?.slug;
    if (currentSlug != null && currentSlug != teamSlug) {
      return TeamHomePage(
        teamSlug: currentSlug,
        section: section,
        agendaType: agendaType,
        agendaScope: agendaScope,
        agendaView: agendaView,
      );
    }

    return teamAsync.when(
      data: (TeamDetailDto team) => _TeamSectionScaffold(
        team: team,
        section: section,
        agendaType: agendaType,
        agendaScope: agendaScope,
        agendaView: agendaView,
      ),
      loading: () => const _TeamChrome.bare(
        // Défilable : trois gabarits dépassent la hauteur d'un écran, et un
        // gabarit qui déborde rend une bande d'erreur rayée.
        body: SingleChildScrollView(
          padding: EdgeInsets.all(PdlSpacing.section),
          child: PdlSkeletonCardList(count: 3),
        ),
      ),
      error: (Object error, StackTrace stack) => _TeamChrome.bare(
        body: Center(
          child: SingleChildScrollView(
            child: PdlEmptyState(
              key: keys.team.loadError,
              variant: PdlEmptyVariant.error,
              title: 'teams.loadError.title'.tr(),
              message: getErrorMessage(error),
              actions: <Widget>[
                PdlButton(
                  key: keys.team.loadErrorRetryButton,
                  label: 'common.retry'.tr(),
                  onPressed: () => ref.invalidate(teamDetailProvider(teamSlug)),
                ),
                PdlButton(
                  label: 'teams.title'.tr(),
                  variant: PdlButtonVariant.outline,
                  onPressed: () => context.go(Paths.teams()),
                ),
                ReportProblemButton(error: error, stackTrace: stack),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The frame every section hangs from.
///
/// The [Scaffold] is also what makes an iOS status-bar tap scroll a section
/// back to the top: it animates the [PrimaryScrollController] of **its own**
/// route, and `MainShell`'s Scaffold lives in the root navigator's route while
/// a team lives in the Teams branch — two different controllers.
class _TeamChrome extends StatelessWidget {
  /// L'équipe est là : son en-tête porte déjà la flèche de retour, l'action
  /// d'adhésion et le partage. [header] est `null` quand cet en-tête vit dans
  /// les slivers du corps (Agenda en liste, Publications, à propos) — **pas** de barre de plus alors,
  /// sans quoi l'écran affiche deux retours l'un sous l'autre.
  const _TeamChrome({required this.header, required this.body})
    : ownBar = false;

  /// Chargement et erreur : rien à rétracter, pas d'identité à inventer, mais
  /// il faut de quoi sortir. C'est le seul cas qui pose une barre à lui.
  const _TeamChrome.bare({required this.body}) : header = null, ownBar = true;

  final Widget? header;

  final Widget body;

  final bool ownBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pdl.bg,
      appBar: ownBar
          ? PdlAppBar(
              onBack: () => context.go(Paths.teams()),
              backSemanticLabel: 'teams.title'.tr(),
            )
          : null,
      body: header == null
          ? body
          : Column(
              children: <Widget>[
                SafeArea(bottom: false, child: header!),
                Expanded(child: body),
              ],
            ),
    );
  }
}

/// Dispatches to the section's body, team in hand.
class _TeamSectionScaffold extends ConsumerWidget {
  const _TeamSectionScaffold({
    required this.team,
    required this.section,
    required this.agendaType,
    required this.agendaScope,
    required this.agendaView,
  });

  final TeamDetailDto team;
  final TeamSectionKind section;
  final PublicationType? agendaType;
  final AgendaScope agendaScope;
  final AgendaView agendaView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `team.role` est le vrai rôle, nul pour un administrateur de la
    // plateforme qui n'est pas membre (docs/LEDGER_*.md API-137) : ses droits
    // viennent de son rôle de plateforme.
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    final List<TeamSection> sections = buildTeamSections(
      team,
      platformAdmin: platformAdmin,
    );
    final List<Widget> headerSlivers = <Widget>[
      TeamHeaderSliver(team: team, section: section),
      SliverToBoxAdapter(child: _MembershipBanner(team: team)),
    ];

    // Les sections qui sont **une liste de slivers** portent l'en-tête
    // interpolé : il se rétracte de 112 à 56 px sous le doigt. Les autres
    // possèdent leur propre défileur et reçoivent l'en-tête déjà
    // rétracté — voir [TeamHeaderSliver].
    return switch (section) {
      // Le tableau de bord, pour tout le monde : un visiteur y lit la partie
      // publique (ledger `API-86`).
      TeamSectionKind.dashboard => _TeamChrome(
        header: null,
        body: TeamDashboardPage(
          team: team,
          leadingSlivers: <Widget>[
            TeamHeaderSliver(team: team, section: section),
            SliverToBoxAdapter(child: _MembershipBanner(team: team)),
          ],
          toolbar: TeamSectionsToolbar(sections: sections, current: section),
        ),
      ),
      TeamSectionKind.agenda => TeamAgendaPage(
        team: team,
        sections: sections,
        leadingSlivers: headerSlivers,
        initialType: agendaType,
        initialScope: agendaScope,
        initialView: agendaView,
        platformAdmin: platformAdmin,
        chrome: ({required Widget? header, required Widget body}) =>
            _TeamChrome(header: header, body: body),
      ),
      // Les publications seules, la plus récente d'abord : pas de filtre de
      // date, pas de chip de type (plan §2).
      TeamSectionKind.posts => _TeamChrome(
        header: null,
        body: PublicationFeedView(
          teamSlug: team.slug,
          filterScope: 'posts/${team.slug}',
          leadingSlivers: <Widget>[
            ...headerSlivers,
            TeamSectionsToolbar(sections: sections, current: section),
          ],
          typeOptions: const <PublicationType?>[],
          selectedType: PublicationType.post,
          searchHint: 'teams.posts.searchPlaceholder'.tr(),
          emptyMessage: 'teams.posts.empty'.tr(),
          emptyHint: 'teams.posts.emptyHint'.tr(),
        ),
      ),
      TeamSectionKind.about => _TeamChrome(
        header: null,
        body: TeamAboutPage(
          teamSlug: team.slug,
          team: team,
          leadingSlivers: headerSlivers,
          toolbar: TeamSectionsToolbar(sections: sections, current: section),
        ),
      ),
      TeamSectionKind.routes => _TeamChrome(
        header: TeamHeaderBar(team: team, section: section),
        body: _WithSectionsBar(
          sections: sections,
          current: section,
          child: RoutesPage(teamSlug: team.slug, embedded: true),
        ),
      ),
      TeamSectionKind.ads => _TeamChrome(
        header: TeamHeaderBar(team: team, section: section),
        body: _WithSectionsBar(
          sections: sections,
          current: section,
          child: AdsPage(teamSlug: team.slug, team: team),
        ),
      ),
      TeamSectionKind.members => _TeamChrome(
        header: TeamHeaderBar(team: team, section: section),
        body: _WithSectionsBar(
          sections: sections,
          current: section,
          child: TeamMembersPage(
            teamSlug: team.slug,
            // Les rôles ne reviennent qu'à un admin, ou à tous une fois le
            // trombinoscope ouvert (docs/LEDGER_*.md SEC-18).
            rolesShown:
                team.role == 'ADMIN' ||
                platformAdmin ||
                team.enableMemberDirectory,
          ),
        ),
      ),
    };
  }
}

/// Le bandeau d'échec d'adhésion, nommant sa cause.
class _MembershipBanner extends ConsumerWidget {
  const _MembershipBanner({required this.team});

  final TeamDetailDto team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? failure = ref.watch(
      teamMembershipControllerProvider(team.slug)
          .select((TeamMembershipState s) => s.failure),
    );
    if (failure == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.chipGap,
        PdlSpacing.section,
        0,
      ),
      child: PdlBanner(
        tone: PdlBannerTone.danger,
        title: 'teams.membership.failed'.tr(),
        message: failure,
        onDismiss: () => ref
            .read(teamMembershipControllerProvider(team.slug).notifier)
            .dismissFailure(),
        dismissSemanticLabel: 'common.close'.tr(),
      ),
    );
  }
}

class _WithSectionsBar extends StatelessWidget {
  const _WithSectionsBar({
    required this.sections,
    required this.current,
    required this.child,
  });

  final List<TeamSection> sections;
  final TeamSectionKind current;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TeamSectionsBar(sections: sections, current: current),
        Expanded(child: child),
      ],
    );
  }
}
