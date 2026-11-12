import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../../feedback/presentation/feedback_sheet.dart';
import '../widgets/profile_subpage.dart';

final _serverVersionProvider = FutureProvider<VersionDto>((ref) async {
  return ref.watch(serverVersionClientProvider).getVersion();
});

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// La version de l'app telle qu'on l'affiche : « 1.4.0 (57) », ou une chaîne
/// vide tant qu'elle n'est pas connue.
String appVersionLabel(WidgetRef ref) => ref
    .watch(packageInfoProvider)
    .maybeWhen(
      data: (PackageInfo info) => info.buildNumber.isEmpty
          ? info.version
          : '${info.version} (${info.buildNumber})',
      orElse: () => '',
    );

/// Aide et à propos : les applications compagnons, « Signaler un problème »,
/// les pages légales, puis les versions de l'app et du serveur.
class ProfileHelpPage extends ConsumerWidget {
  const ProfileHelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;

    // Une version absente n'est pas une erreur d'écran : on n'affiche rien
    // plutôt qu'un « Chargement impossible » pour un numéro de build.
    final String appVersion = appVersionLabel(ref);
    final String serverVersion = ref
        .watch(_serverVersionProvider)
        .maybeWhen(
          data: (VersionDto version) => version.apiVersion,
          orElse: () => '',
        );

    return ProfileSubpage(
      title: 'profile.nav.help'.tr(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: ProfileSection(
            child: PdlCard(
              padding: PdlCardPadding.none,
              child: Column(
                children: <Widget>[
                  PdlSettingRow(
                    key: keys.profile.appsRow,
                    icon: PdlIcons.devices,
                    title: 'profile.apps'.tr(),
                    onTap: () => context.push(Paths.apps()),
                    showDivider: true,
                  ),
                  PdlSettingRow(
                    key: keys.profile.reportProblemRow,
                    icon: PdlIcons.bug,
                    title: 'feedback.reportProblem'.tr(),
                    onTap: () => showFeedbackSheet(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.help.legalTitle'.tr(),
            child: PdlCard(
              padding: PdlCardPadding.none,
              child: Column(
                children: <Widget>[
                  PdlSettingRow(
                    icon: PdlIcons.privacy,
                    title: 'profile.privacy'.tr(),
                    onTap: () => context.push(Paths.privacy()),
                    showDivider: true,
                  ),
                  PdlSettingRow(
                    icon: PdlIcons.page,
                    title: 'profile.terms'.tr(),
                    onTap: () => context.push(Paths.terms()),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.about'.tr(),
            child: PdlCard(
              padding: PdlCardPadding.none,
              child: Column(
                children: <Widget>[
                  PdlSettingRow(
                    title: 'profile.version'.tr(),
                    trailing: Text(appVersion, style: t.mono),
                    showDivider: true,
                  ),
                  PdlSettingRow(
                    title: 'profile.serverVersion'.tr(),
                    trailing: Text(serverVersion, style: t.mono),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
