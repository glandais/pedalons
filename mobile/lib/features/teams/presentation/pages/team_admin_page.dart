import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../providers/team_access_probe.dart';
import '../../providers/team_permission_providers.dart';
import '../../providers/team_providers.dart';
import '../team_web_paths.dart';
import '../widgets/dashboard/dashboard_section.dart' show openTeamWebPage;

/// « Gestion de l'équipe » : le hub d'où partent les écrans d'administration
/// (docs/LEDGER_*.md MOB-165) — une liste, pas des onglets : l'app n'a pas de
/// barre d'onglets imbriquée.
///
/// Les lignes sont celles des onglets du site (`TeamAdminLayout`), dans le
/// même ordre. Ouvert aux organisateurs ; les lignes réservées à
/// l'administration ne sont rendues qu'à un administrateur. Quelqu'un d'autre
/// arrivé ici par un lien lit un refus — rendu par la page, jamais par le
/// routeur, qui ne lit pas l'authentification.
///
/// Tant que l'écran d'une ligne n'existe pas dans l'app, elle ouvre le site
/// ([TeamWebPaths]) et le dit ; chaque lot du plan
/// `docs/plans/2026-11-15-gestion-equipe-mobile.md` en fait passer dans l'app.
class TeamAdminPage extends ConsumerWidget {
  const TeamAdminPage({super.key, required this.teamSlug});

  final String teamSlug;

  /// [teamReadable] faux : l'équipe elle-même s'est refusée, sa page ne
  /// dirait qu'« Équipe indisponible » — le retour mène à « Mes équipes ».
  void _back(BuildContext context, {bool teamReadable = true}) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(teamReadable ? Paths.team(teamSlug) : Paths.teams());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget shell({Widget? body, List<Widget>? slivers}) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'teams.manage.title'.tr(),
        onBack: () => _back(context),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
      slivers: slivers,
    );

    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    Widget forbidden({required bool teamReadable}) => shell(
      body: PdlEmptyState(
        key: keys.teamAdmin.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'teams.manage.forbiddenTitle'.tr(),
        message: 'teams.manage.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamAdmin.forbiddenBack,
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => _back(context, teamReadable: teamReadable),
          ),
        ],
      ),
    );

    final Object? error = team.error;
    // Une équipe que le serveur refuse (403, ou 404 pour une équipe privée
    // dont on n'est pas membre) : un refus, pas une panne à réessayer.
    if (error != null && isTeamAccessRefusal(error)) {
      return forbidden(teamReadable: false);
    }
    if (error != null) {
      return shell(
        body: PdlEmptyState(
          key: keys.teamAdmin.loadError,
          variant: PdlEmptyVariant.error,
          title: 'common.loadError'.tr(),
          message: getErrorMessage(error),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () => ref.invalidate(teamDetailProvider(teamSlug)),
            ),
          ],
        ),
      );
    }

    // `null` tant que la fiche charge : ni lignes, ni refus.
    final bool? organizer = ref.watch(isTeamOrganizerProvider(teamSlug));
    final bool? admin = ref.watch(isTeamAdminProvider(teamSlug));
    if (organizer == null || admin == null) {
      return shell(
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (!organizer) return forbidden(teamReadable: true);

    final List<_AdminRow> rows = <_AdminRow>[
      _AdminRow(
        key: keys.teamAdmin.rideTemplates,
        icon: PdlIcons.template,
        label: 'teams.manage.rideTemplates'.tr(),
        appPath: Paths.rideTemplates(teamSlug),
      ),
      _AdminRow(
        key: keys.teamAdmin.places,
        icon: PdlIcons.place,
        label: 'teams.manage.places'.tr(),
        webPath: TeamWebPaths.places(teamSlug),
      ),
      if (admin) ...<_AdminRow>[
        _AdminRow(
          key: keys.teamAdmin.tags,
          icon: PdlIcons.tag,
          label: 'teams.manage.tags'.tr(),
          webPath: TeamWebPaths.tags(teamSlug),
        ),
        _AdminRow(
          key: keys.teamAdmin.pages,
          icon: PdlIcons.page,
          label: 'teams.manage.pages'.tr(),
          webPath: TeamWebPaths.pages(teamSlug),
        ),
        _AdminRow(
          key: keys.teamAdmin.members,
          icon: PdlIcons.people,
          label: 'teams.manage.members'.tr(),
          appPath: Paths.teamAdminMembers(teamSlug),
        ),
      ],
      _AdminRow(
        key: keys.teamAdmin.reports,
        icon: PdlIcons.report,
        label: 'teams.manage.reports'.tr(),
        webPath: TeamWebPaths.reports(teamSlug),
      ),
      if (admin)
        _AdminRow(
          key: keys.teamAdmin.settings,
          icon: PdlIcons.settings,
          label: 'teams.manage.settings'.tr(),
          appPath: Paths.teamSettings(teamSlug),
        ),
    ];

    final PdlColors c = context.pdl;
    return shell(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: PdlSpacing.chipGap),
          sliver: SliverList.list(
            children: <Widget>[
              for (final _AdminRow row in rows)
                PdlSettingRow(
                  key: row.key,
                  icon: row.icon,
                  title: row.label,
                  subtitle: row.webPath == null
                      ? null
                      : 'teams.manage.onSite'.tr(),
                  // Une page du site se signale : elle quitte l'app.
                  trailing: row.webPath == null
                      ? null
                      : Icon(
                          PdlIcons.openExternal,
                          size: 20,
                          color: c.textDimmed,
                        ),
                  showDivider: true,
                  onTap: () {
                    final String? appPath = row.appPath;
                    if (appPath != null) {
                      context.push(appPath);
                    } else {
                      openTeamWebPage(context, row.webPath!);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une ligne du hub : un écran de l'app ([appPath]) ou, tant qu'il n'existe
/// pas, une page du site ([webPath]).
class _AdminRow {
  const _AdminRow({
    required this.key,
    required this.icon,
    required this.label,
    this.appPath,
    this.webPath,
  }) : assert((appPath == null) != (webPath == null));

  final Key key;
  final IconData icon;
  final String label;
  final String? appPath;
  final String? webPath;
}
