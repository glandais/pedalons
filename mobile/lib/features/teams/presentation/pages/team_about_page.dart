import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../../keys.dart';

/// A team's About section: its presentation and its free pages.
///
/// **Une seule requête à l'ouverture.** La version précédente montait une carte
/// par page libre et chargeait le contenu de chacune : N pages valaient N
/// requêtes simultanées à l'affichage de l'onglet, pour du texte que personne
/// n'avait demandé. `TeamDetailDto.pages[]` porte déjà titre et slug ; le corps
/// n'est chargé qu'à l'ouverture de la page, sur son propre écran.
///
/// `TeamHomePage` owns the header and the team's loading state; this page
/// renders the section proper, with the pinned row of sections it is handed as
/// a sliver of its own scroll view.
class TeamAboutPage extends ConsumerWidget {
  final String teamSlug;
  final TeamDetailDto team;

  /// The pinned section row.
  final Widget? toolbar;

  /// Slivers rendus au-dessus de la rangée de sections.
  final List<Widget> leadingSlivers;

  const TeamAboutPage({
    super.key,
    required this.teamSlug,
    required this.team,
    this.toolbar,
    this.leadingSlivers = const <Widget>[],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final List<TeamPageSummaryDto> pages =
        (team.pages ?? const <TeamPageSummaryDto>[])
            .where((TeamPageSummaryDto p) => !p.deleted)
            .toList()
          ..sort(
            (TeamPageSummaryDto a, TeamPageSummaryDto b) =>
                a.order.compareTo(b.order),
          );
    // Il n'y a pas de `foundedYear` au contrat : c'est l'année de `createdAt`,
    // la création de l'équipe sur la plateforme.
    final DateTime? created = DateTime.tryParse(team.createdAt);

    return CustomScrollView(
      primary: true,
      slivers: <Widget>[
        ...leadingSlivers,
        ?toolbar,
        SliverPadding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          sliver: SliverList.list(
            children: <Widget>[
              if (created != null) ...<Widget>[
                Text(
                  'teams.aboutPage.founded'.tr(
                    namedArgs: <String, String>{'year': '${created.year}'},
                  ),
                  style: t.sub,
                ),
                const SizedBox(height: PdlSpacing.section),
              ],
              if (team.about.markdown.trim().isNotEmpty) ...<Widget>[
                PdlSectionHeader(title: 'teams.about'.tr()),
                MarkdownContent(
                  data: team.about.markdown,
                  images: team.about.assets.images,
                ),
                const SizedBox(height: PdlSpacing.section),
              ],
              if (team.about.assets.attachments.isNotEmpty) ...<Widget>[
                MediaAttachments(
                  attachments: team.about.assets.attachments,
                  spacingBefore: 0,
                ),
                const SizedBox(height: PdlSpacing.section),
              ],
              if (pages.isNotEmpty) ...<Widget>[
                PdlSectionHeader(title: 'teams.aboutPage.pages'.tr()),
                Text('teams.aboutPage.pagesHint'.tr(), style: t.xs),
                const SizedBox(height: 4),
                for (int i = 0; i < pages.length; i++)
                  PdlSettingRow(
                    key: keys.team.aboutPageRow(pages[i].slug),
                    icon: PdlIcons.page,
                    title: pages[i].title,
                    showDivider: i < pages.length - 1,
                    onTap: () =>
                        context.push(Paths.teamPage(teamSlug, pages[i].slug)),
                  ),
              ],
              if (team.about.markdown.trim().isEmpty &&
                  team.about.assets.attachments.isEmpty &&
                  pages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: PdlEmptyState(
                    variant: PdlEmptyVariant.empty,
                    icon: PdlIcons.info,
                    title: 'teams.aboutPage.empty'.tr(),
                    message: 'teams.aboutPage.emptyHint'.tr(),
                  ),
                ),
            ],
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }
}
