import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/share_link.dart';
import '../../providers/team_membership_controller.dart';
import '../../providers/team_providers.dart';
import '../../../../keys.dart';
import 'my_teams_sheet.dart';
import 'team_sections.dart';

/// Hauteur de la barre — le plancher de l'en-tête rétracté.
const double _kBarHeight = PdlMetrics.appBar;

/// Hauteur du bloc déployé, sous la barre.
///
/// 56 px : l'avatar de 56 et rien de plus. Avec la barre, l'en-tête déployé
/// mesure donc **112 px**, sous le plafond de 120 px du plan — un en-tête plus
/// haut repousse la première carte du fil hors de l'écran.
const double _kExpandedBlock = 56;

/// L'en-tête d'une équipe : barre, identité, et l'action d'adhésion.
///
/// **L'action ne vit pas dans la partie qui se replie.** C'est le point de
/// conception : le bouton « Rejoindre » ou « Quitter » est dans la rangée de
/// barre, donc atteignable à n'importe quelle position de défilement. Une
/// action posée dans le bloc déployé disparaîtrait au premier geste, et il
/// faudrait remonter toute la page pour la retrouver.
///
/// [t] va de 0 (déployé) à 1 (rétracté) : l'avatar passe de 56 à 26, le titre
/// de 20 à 17, et les badges s'effacent. Rien ne saute — c'est une
/// interpolation, pas une bascule à seuil.
///
/// **Le nom ouvre « Mes équipes »** (ledger `MOB-87`) dès que j'ai une autre
/// équipe que celle affichée — un `▾` le signale. Sans autre équipe, ni `▾`
/// ni feuille : le nom mène au tableau de bord, comme avant.
class TeamHeader extends ConsumerWidget {
  const TeamHeader({
    super.key,
    required this.team,
    required this.section,
    required this.t,
    this.topPadding = 0,
  });

  final TeamDetailDto team;

  /// La section affichée sous l'en-tête : celle où mène « Mes équipes » dans
  /// l'autre équipe, quand elle l'a.
  final TeamSectionKind section;

  /// Facteur de rétraction, 0 → 1.
  final double t;

  /// Encoche et barre d'état, quand l'en-tête est **le premier élément** de
  /// l'écran — c'est le cas en sliver, où plus aucune `AppBar` ne les tient.
  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    // Mes équipes, quand l'une d'elles n'est pas celle affichée — sinon pas de
    // menu, chargement et échec compris. Un visiteur y voit les siennes.
    final List<TeamDetailDto>? teams = ref.watch(myTeamsProvider).value;
    final _Switcher? switcher =
        teams != null && teams.any((TeamDetailDto x) => x.id != team.id)
        ? (section: section, teams: teams)
        : null;

    return Material(
      color: c.overlaySolid,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: topPadding),
          SizedBox(
            height: _kBarHeight,
            child: _Bar(team: team, t: t, switcher: switcher),
          ),
          // Le bloc se replie **en hauteur** et non seulement en opacité :
          // laisser 56 px vides derrière un contenu effacé ferait remonter le
          // fil moitié moins vite que le doigt.
          ClipRect(
            child: Align(
              alignment: Alignment.topLeft,
              heightFactor: math.max(0, 1 - t),
              child: Opacity(
                opacity: (1 - t * 1.6).clamp(0, 1),
                child: SizedBox(
                  height: _kExpandedBlock,
                  child: _Identity(team: team, switcher: switcher),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// De quoi ouvrir « Mes équipes » : la section d'où l'on part, et la liste.
typedef _Switcher = ({TeamSectionKind section, List<TeamDetailDto> teams});

/// Retour, identité compacte (qui apparaît en se rétractant), action, partage.
class _Bar extends ConsumerWidget {
  const _Bar({required this.team, required this.t, required this.switcher});

  final TeamDetailDto team;
  final double t;
  final _Switcher? switcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography ty = context.pdlText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          PdlAppBarAction(
            icon: PdlIcons.back,
            semanticLabel: 'teams.title'.tr(),
            onPressed: () => context.go(Paths.teams()),
          ),
          // L'identité compacte n'apparaît qu'en se rétractant : déployée,
          // elle ferait doublon avec le titre de 20 px juste dessous.
          Expanded(
            child: _IdentityTap(
              team: team,
              switcher: switcher,
              // Invisible tant que l'en-tête est déployé : on ne tape pas sur
              // ce qu'on ne voit pas — le nom du bloc dessous y mène déjà.
              enabled: t > 0.4,
              child: Opacity(
                opacity: ((t - 0.4) / 0.6).clamp(0, 1),
                child: Row(
                  children: <Widget>[
                    PdlAvatar(
                      name: team.name,
                      imageUrl: team.logoUrl,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    // Flexible et non Expanded : le `▾` suit le nom.
                    Flexible(
                      child: Text(
                        team.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ty.barTitle.copyWith(color: c.text),
                      ),
                    ),
                    if (switcher != null)
                      Icon(PdlIcons.chevronDown, size: 18, color: c.textDimmed),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MembershipAction(team: team),
          PdlAppBarAction(
            icon: PdlIcons.share,
            semanticLabel: 'routes.share'.tr(),
            onPressed: () => shareAppLink(
              context,
              title: team.name,
              path: Paths.team(team.slug),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Toutes mes équipes », avatar 56, titre 20, badges.
class _Identity extends StatelessWidget {
  const _Identity({required this.team, required this.switcher});

  final TeamDetailDto team;
  final _Switcher? switcher;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        0,
        PdlSpacing.section,
        8,
      ),
      child: _IdentityTap(
        team: team,
        switcher: switcher,
        child: Row(
          children: <Widget>[
            PdlAvatar(name: team.name, imageUrl: team.logoUrl, size: 48),
            const SizedBox(width: PdlSpacing.cardTight),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          team.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.screenTitle.copyWith(fontSize: 20),
                        ),
                      ),
                      if (switcher != null)
                        Icon(
                          PdlIcons.chevronDown,
                          size: 20,
                          color: c.textDimmed,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      PdlBadge(
                        label: 'visibility.${team.visibility.toLowerCase()}'
                            .tr(),
                        tone: Visibility.fromJson(team.visibility).tone(c),
                        icon: switch (Visibility.fromJson(team.visibility)) {
                          Visibility.public => PdlIcons.visibilityPublic,
                          Visibility.publicUnlisted =>
                            PdlIcons.visibilityUnlisted,
                          _ => PdlIcons.visibilityTeam,
                        },
                      ),
                      if (team.role != null) ...<Widget>[
                        const SizedBox(width: PdlSpacing.badgeGap),
                        Flexible(
                          child: PdlBadge(
                            label: 'teams.discovery.memberBadge'.tr(),
                            tone: PdlDerivedTones.registered(c),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'identité de l'équipe ouvre « Mes équipes » quand [switcher] est là, et
/// mène sinon à son tableau de bord, son adresse propre.
class _IdentityTap extends StatelessWidget {
  const _IdentityTap({
    required this.team,
    required this.switcher,
    required this.child,
    this.enabled = true,
  });

  final TeamDetailDto team;
  final _Switcher? switcher;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final _Switcher? switcher = this.switcher;
    return Semantics(
      button: true,
      label: switcher != null
          ? 'teams.switcher.open'.tr()
          : 'teams.tabs.dashboard'.tr(),
      child: GestureDetector(
        key: keys.team.headerIdentity,
        behavior: HitTestBehavior.opaque,
        onTap: switcher != null
            ? () => showMyTeamsSheet(
                context,
                team: team,
                section: switcher.section,
                teams: switcher.teams,
              )
            : () => context.go(Paths.team(team.slug)),
        child: child,
      ),
    );
  }
}

/// « Rejoindre » ou « Quitter », et rien tant que l'équipe n'est pas là.
///
/// **Sur invitation** quand l'équipe n'est pas joignable et qu'on n'en est pas
/// membre : le bouton reste, désactivé, plutôt que de disparaître — l'absence
/// n'explique rien.
class _MembershipAction extends ConsumerWidget {
  const _MembershipAction({required this.team});

  final TeamDetailDto team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeamMembershipState state = ref.watch(
      teamMembershipControllerProvider(team.slug),
    );
    final TeamMembershipController controller = ref.read(
      teamMembershipControllerProvider(team.slug).notifier,
    );

    if (state.pending) {
      // Le libellé suit le **sens de l'appel**, pas le rôle courant : celui-ci
      // a déjà basculé en optimiste.
      final String label = state.pendingJoin
          ? 'teams.membership.joining'.tr()
          : 'teams.membership.leaving'.tr();
      return PdlButton(
        label: label,
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        loading: true,
        loadingLabel: label,
      );
    }

    if (state.isMember) {
      // Contour, jamais plein : la règle « au plus une action pleine et
      // colorée par écran » réserve le plein à ce qu'on veut encourager, et
      // quitter une équipe n'en fait pas partie.
      return PdlButton(
        key: keys.team.leaveButton,
        label: 'teams.membership.leave'.tr(),
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        onPressed: () => _confirmLeave(context, controller),
      );
    }

    if (!team.joinable) {
      return PdlButton(
        key: keys.team.inviteOnlyButton,
        label: 'teams.discovery.inviteOnly'.tr(),
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        enabled: false,
      );
    }

    return PdlButton(
      key: keys.team.joinButton,
      label: 'teams.membership.join'.tr(),
      size: PdlButtonSize.sm,
      onPressed: controller.join,
    );
  }

  /// Une **question fermée** et sa conséquence, pas un « Êtes-vous sûr ? » nu.
  Future<void> _confirmLeave(
    BuildContext context,
    TeamMembershipController controller,
  ) async {
    final bool? confirmed = await PdlSheet.show<bool>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title: 'teams.membership.leaveTitle'.tr(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Text(
            'teams.membership.leaveMessage'.tr(),
            style: context.pdlText.sub,
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: PdlButton(
                    label: 'common.cancel'.tr(),
                    variant: PdlButtonVariant.outline,
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                  ),
                ),
                const SizedBox(width: PdlSpacing.chipGap),
                Expanded(
                  child: PdlButton(
                    key: keys.team.leaveConfirmButton,
                    label: 'teams.membership.leave'.tr(),
                    variant: PdlButtonVariant.danger,
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) await controller.leave();
  }
}

/// L'en-tête en sliver épinglé, pour les sections qui sont une liste.
///
/// Les autres — calendrier, parcours, annonces, membres — possèdent leur propre
/// défileur et reçoivent l'en-tête **déjà rétracté**, en boîte fixe : y greffer
/// une interpolation demanderait un `NestedScrollView`, qui leur retirerait le
/// statut de défileur primaire dont dépend le retour en haut par la barre
/// d'état (lot 3).
class TeamHeaderSliver extends StatelessWidget {
  const TeamHeaderSliver({
    super.key,
    required this.team,
    required this.section,
  });

  final TeamDetailDto team;
  final TeamSectionKind section;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TeamHeaderDelegate(
        team: team,
        section: section,
        // L'en-tête est le premier pixel de l'écran : il n'y a pas d'`AppBar`
        // au-dessus de lui, c'est donc à lui de tenir la barre d'état.
        topPadding: MediaQuery.paddingOf(context).top,
      ),
    );
  }
}

class _TeamHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TeamHeaderDelegate({
    required this.team,
    required this.section,
    required this.topPadding,
  });

  final TeamDetailDto team;
  final TeamSectionKind section;
  final double topPadding;

  @override
  double get maxExtent => topPadding + _kBarHeight + _kExpandedBlock;

  @override
  double get minExtent => topPadding + _kBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // L'enfant mesure **exactement** l'étendue que le sliver épinglé calcule
    // de son côté (`maxExtent - scrollOffset`, bornée par le plancher), avec
    // les mêmes opérandes : sa hauteur naturelle — barre, plus le bloc replié
    // à `1 - t` — est une autre somme de flottants, qui tombe parfois un ulp
    // sous la première. Le sliver prend alors une `paintExtent` plus petite
    // que sa `layoutExtent`, et l'assertion « SliverGeometry is not valid »
    // saute au rebond d'une page courte
    // (test/features/teams/team_header_sliver_test.dart).
    return SizedBox(
      height: math.max(minExtent, maxExtent - shrinkOffset),
      child: TeamHeader(
        team: team,
        section: section,
        t: (shrinkOffset / _kExpandedBlock).clamp(0, 1),
        topPadding: topPadding,
      ),
    );
  }

  @override
  bool shouldRebuild(_TeamHeaderDelegate oldDelegate) =>
      oldDelegate.team != team ||
      oldDelegate.section != section ||
      oldDelegate.topPadding != topPadding;
}

/// L'en-tête rétracté, en boîte fixe.
class TeamHeaderBar extends StatelessWidget {
  const TeamHeaderBar({super.key, required this.team, required this.section});

  final TeamDetailDto team;
  final TeamSectionKind section;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _kBarHeight,
    child: TeamHeader(team: team, section: section, t: 1),
  );
}
