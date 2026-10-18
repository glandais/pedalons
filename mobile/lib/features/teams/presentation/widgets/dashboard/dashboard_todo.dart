import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../config/paths.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../team_web_paths.dart';
import 'dashboard_section.dart';

/// « À traiter » : ce qui attend un organisateur — brouillons, sorties sans
/// parcours, groupes complets, signalements.
///
/// Rendu pour un organisateur **et** un administrateur, c'est-à-dire dès que
/// l'API envoie le bloc `organizer` : l'écran ne relit pas le rôle pour en
/// décider. Les deux tuiles de sorties suivent l'activation des sorties (leur
/// liste vient `null` sinon) ; brouillons et signalements sont toujours là.
class DashboardTodo extends StatelessWidget {
  const DashboardTodo({super.key, required this.teamSlug, required this.data});

  final String teamSlug;
  final TeamDashboardOrganizerDto data;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final PublicationListResponse? withoutRoute = data.ridesWithoutRoute;
    final PublicationListResponse? fullGroup = data.ridesWithFullGroup;

    return Padding(
      key: keys.teamDashboard.todo,
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlSectionHeader(
            title: 'teams.dashboard.todo.title'.tr(),
            padding: EdgeInsets.zero,
          ),
          Text(
            'teams.dashboard.todo.hint'.tr(),
            style: t.xs.copyWith(color: context.pdl.textDimmed),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          DashboardCardColumn(
            children: <Widget>[
              _drafts(context),
              if (withoutRoute != null) _withoutRoute(context, withoutRoute),
              if (fullGroup != null) _fullGroup(context, fullGroup),
              _reports(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drafts(BuildContext context) {
    final List<PublicationDto> rows = data.drafts.publications;
    return _TodoTile(
      key: keys.teamDashboard.todoDrafts,
      count: data.drafts.total,
      label: 'teams.dashboard.todo.drafts'.plural(data.drafts.total),
      icon: PdlIcons.draft,
      detail: _names(
        rows.map((PublicationDto p) => p.name).toList(),
        data.drafts.total,
      ),
      actionLabel: 'teams.dashboard.todo.draftsAction'.tr(),
      onAction: rows.isEmpty
          ? null
          : () => _pick(
              context,
              title: 'teams.dashboard.todo.drafts'.plural(data.drafts.total),
              entries: <_PickEntry>[
                for (final PublicationDto p in rows)
                  _PickEntry(
                    title: p.name,
                    icon: switch (p) {
                      PublicationDtoRide() => PdlIcons.ride,
                      PublicationDtoPost() => PdlIcons.post,
                      PublicationDtoTrip() => PdlIcons.trip,
                    },
                    onTap: () => _openEdit(context, p),
                  ),
              ],
            ),
    );
  }

  Widget _withoutRoute(BuildContext context, PublicationListResponse list) {
    final List<PublicationDtoRide> rides = list.publications
        .whereType<PublicationDtoRide>()
        .toList();
    return _TodoTile(
      key: keys.teamDashboard.todoWithoutRoute,
      count: list.total,
      label: 'teams.dashboard.todo.withoutRoute'.plural(list.total),
      icon: PdlIcons.route,
      detail: rides.isEmpty ? null : _rideWithDate(rides.first),
      actionLabel: 'teams.dashboard.todo.withoutRouteAction'.tr(),
      onAction: rides.isEmpty
          ? null
          : () => _pick(
              context,
              title: 'teams.dashboard.todo.withoutRoute'.plural(list.total),
              entries: <_PickEntry>[
                for (final PublicationDtoRide r in rides)
                  _PickEntry(
                    title: _rideWithDate(r),
                    icon: PdlIcons.ride,
                    onTap: () =>
                        context.push(Paths.rideEdit(r.team.slug, r.slug)),
                  ),
              ],
            ),
    );
  }

  Widget _fullGroup(BuildContext context, PublicationListResponse list) {
    final List<PublicationDtoRide> rides = list.publications
        .whereType<PublicationDtoRide>()
        .toList();
    String? detail;
    if (rides.isNotEmpty) {
      final PublicationDtoRide ride = rides.first;
      final RideGroupSummaryDto? group = ride.groupSummaries
          .where((RideGroupSummaryDto g) => g.full)
          .firstOrNull;
      detail = group == null || group.maxParticipants == null
          ? ride.name
          : 'teams.dashboard.todo.fullGroupLine'.plural(
              group.countParticipants,
              namedArgs: <String, String>{
                'group': group.name,
                'ride': ride.name,
                'count': '${group.countParticipants}',
                'max': '${group.maxParticipants}',
              },
            );
    }
    return _TodoTile(
      key: keys.teamDashboard.todoFullGroup,
      count: list.total,
      label: 'teams.dashboard.todo.fullGroup'.plural(list.total),
      icon: PdlIcons.seats,
      detail: detail,
      actionLabel: 'teams.dashboard.todo.fullGroupAction'.tr(),
      onAction: rides.isEmpty
          ? null
          : () {
              if (rides.length == 1) {
                context.push(
                  Paths.ride(rides.first.team.slug, rides.first.slug),
                );
                return;
              }
              _pick(
                context,
                title: 'teams.dashboard.todo.fullGroup'.plural(list.total),
                entries: <_PickEntry>[
                  for (final PublicationDtoRide r in rides)
                    _PickEntry(
                      title: _rideWithDate(r),
                      icon: PdlIcons.ride,
                      onTap: () =>
                          context.push(Paths.ride(r.team.slug, r.slug)),
                    ),
                ],
              );
            },
    );
  }

  Widget _reports(BuildContext context) {
    final TeamDashboardReportsDto reports = data.reports;
    final List<String> lines = <String>[
      if (reports.latestTargetType != null)
        <String>[
          'teams.dashboard.todo.reportTarget.${reports.latestTargetType}'.tr(),
          if (reports.latestReason != null)
            'moderation.reason.${reports.latestReason}'.tr(),
        ].join(' — '),
      if (reports.latestExcerpt != null && reports.latestExcerpt!.isNotEmpty)
        '« ${reports.latestExcerpt} »',
    ];
    return _TodoTile(
      key: keys.teamDashboard.todoReports,
      count: reports.openCount,
      label: 'teams.dashboard.todo.reports'.plural(reports.openCount),
      icon: PdlIcons.report,
      urgent: true,
      detail: lines.isEmpty ? null : lines.join('\n'),
      actionLabel: 'teams.dashboard.todo.reportsAction'.tr(),
      onAction: () => openTeamWebPage(context, TeamWebPaths.reports(teamSlug)),
    );
  }

  /// « Sortie du samedi, Sortie découverte et 3 autres ».
  static String? _names(List<String> names, int total) {
    if (names.isEmpty) return null;
    final List<String> shown = names.take(2).toList();
    final int rest = total - shown.length;
    final String joined = shown.join(', ');
    if (rest <= 0) return joined;
    return '$joined ${'teams.dashboard.todo.more'.plural(rest)}';
  }

  static String _rideWithDate(PublicationDtoRide ride) {
    // Le jour de la sortie dans son fuseau (docs/LEDGER_*.md API-60).
    final DateTime? at = AppFormatters.tryParseZoneTime(
      ride.dateTime,
      ride.timezone,
    );
    return at == null
        ? ride.name
        : '${ride.name}, ${AppFormatters.formatFullDate(at)}';
  }

  /// Reprendre un brouillon : une sortie dans l'éditeur de l'app (ledger
  /// `MOB-80`), une publication ou un voyage sur le site.
  static void _openEdit(BuildContext context, PublicationDto p) => switch (p) {
    PublicationDtoRide(:final team, :final slug) => context.push(
      Paths.rideEdit(team.slug, slug),
    ),
    PublicationDtoPost(:final team, :final slug) => openTeamWebPage(
      context,
      TeamWebPaths.postEdit(team.slug, slug),
    ),
    PublicationDtoTrip(:final team, :final slug) => openTeamWebPage(
      context,
      TeamWebPaths.tripEdit(team.slug, slug),
    ),
  };

  /// Un seul élément : on y va. Plusieurs : on demande lequel.
  static Future<void> _pick(
    BuildContext context, {
    required String title,
    required List<_PickEntry> entries,
  }) async {
    if (entries.length == 1) {
      entries.first.onTap();
      return;
    }
    final _PickEntry? picked = await PdlSheet.show<_PickEntry>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title: title,
        children: <Widget>[
          for (final _PickEntry e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.section,
              ),
              child: PdlSettingRow(
                title: e.title,
                icon: e.icon,
                onTap: () => Navigator.of(sheetContext).pop(e),
              ),
            ),
        ],
      ),
    );
    picked?.onTap();
  }
}

class _PickEntry {
  const _PickEntry({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

/// Une tuile : le compte, ce qu'il compte, le premier cas, et le geste qui le
/// traite. À zéro, la tuile reste — « Rien en attente » est une réponse — mais
/// perd son geste.
class _TodoTile extends StatelessWidget {
  const _TodoTile({
    super.key,
    required this.count,
    required this.label,
    required this.icon,
    required this.actionLabel,
    this.detail,
    this.onAction,
    this.urgent = false,
  });

  final int count;
  final String label;
  final IconData icon;
  final String? detail;
  final String actionLabel;
  final VoidCallback? onAction;

  /// Un signalement ouvert se teinte en danger, le reste en avertissement.
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool pending = count > 0;
    final Color tint = !pending
        ? c.textDimmed
        : urgent
        ? c.danger
        : c.warning;

    return PdlCard(
      flat: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: tint),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      '$count',
                      style: t.statBigValue.copyWith(
                        color: pending ? c.text : c.textDimmed,
                      ),
                    ),
                    const SizedBox(width: PdlSpacing.chipGap),
                    Expanded(child: Text(label, style: t.bodyStrong)),
                  ],
                ),
                // « Rien en attente » seulement quand rien ne l'est : un compte
                // non nul dont le premier cas n'est pas décrit n'a pas de ligne.
                if (!pending || detail != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    pending ? detail! : 'teams.dashboard.todo.nothing'.tr(),
                    style: t.sub,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (pending && onAction != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PdlButton(
                      label: actionLabel,
                      variant: PdlButtonVariant.text,
                      size: PdlButtonSize.sm,
                      onPressed: onAction,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
