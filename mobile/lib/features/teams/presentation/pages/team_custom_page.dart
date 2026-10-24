import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';

/// Le contenu d'une page libre, chargé **à son ouverture** et pas avant.
final teamPageProvider =
    FutureProvider.family<TeamPageDto, ({String teamSlug, String pageSlug})>((
      ref,
      params,
    ) async {
      return ref
          .watch(teamPagesClientProvider)
          .getPage(teamSlug: params.teamSlug, pageSlug: params.pageSlug);
    });

/// A free-form page published by a team (`/teams/{slug}/pages/{pageSlug}`).
///
/// Un écran propre et deeplinkable, et c'est ce qui supprime le N+1 de la
/// section « À propos » : celle-ci ne liste plus que des titres, et une seule
/// page se charge — celle qu'on ouvre.
class TeamCustomPage extends ConsumerWidget {
  final String teamSlug;
  final String pageSlug;

  const TeamCustomPage({
    super.key,
    required this.teamSlug,
    required this.pageSlug,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (teamSlug: teamSlug, pageSlug: pageSlug);
    final AsyncValue<TeamPageDto> pageAsync = ref.watch(
      teamPageProvider(params),
    );

    return Scaffold(
      backgroundColor: context.pdl.bg,
      appBar: PdlAppBar(
        // Pas de titre : le corps le porte déjà en 22/700, juste dessous.
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: pageAsync.when(
        data: (TeamPageDto page) => SingleChildScrollView(
          primary: true,
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Pas de `onTap`, à dessein (ledger `MOB-90`) : la page est une
              // sous-route de l'équipe, qui est toujours la page dessous — le
              // retour y mène, et la toucher en empilerait une seconde copie.
              PdlTeamLine(label: page.team.name, imageUrl: page.team.logoUrl),
              const SizedBox(height: PdlSpacing.chipGap),
              Text(
                page.title,
                key: keys.team.customPageTitle,
                style: context.pdlText.screenTitle,
              ),
              const SizedBox(height: PdlSpacing.cardTight),
              MarkdownContent(
                key: keys.team.customPageBody,
                data: page.media.markdown,
                images: page.media.assets.images,
              ),
              MediaAttachments(attachments: page.media.assets.attachments),
              const SizedBox(height: 32),
            ],
          ),
        ),
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(PdlSpacing.section),
          child: PdlSkeletonCardList(count: 2),
        ),
        error: (Object error, StackTrace stack) => Center(
          child: SingleChildScrollView(
            child: PdlEmptyState(
              variant: PdlEmptyVariant.error,
              title: 'common.loadError'.tr(),
              message: getErrorMessage(error, stack),
              actions: <Widget>[
                PdlButton(
                  label: 'common.retry'.tr(),
                  variant: PdlButtonVariant.outline,
                  onPressed: () => ref.invalidate(teamPageProvider(params)),
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
