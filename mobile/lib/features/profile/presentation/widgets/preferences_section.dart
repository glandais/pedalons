import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import 'timezone_sheet.dart';

/// Les réglages d'affichage — système d'unités, fuseau horaire, thème,
/// langue —, appliqués **immédiatement, sans bouton**. Les mêmes quatre que le
/// site, sur le même champ utilisateur.
///
/// Ils consomment `userPreferencesProvider` (F-TH-7) et ne le dupliquent pas :
/// c'est ce provider qui tient la chaîne d'autorité serveur → miroir local, et
/// en écrire une seconde ici ferait diverger le thème du premier cadre de
/// celui de l'écran qui le règle.
///
/// L'échec est **contextuel** : un bandeau sous la section, et la valeur revient
/// à ce qu'elle était — le provider s'en charge, l'écran ne fait que le dire.
class PreferencesSection extends ConsumerStatefulWidget {
  const PreferencesSection({super.key});

  @override
  ConsumerState<PreferencesSection> createState() => _PreferencesSectionState();
}

/// La langue effective quand l'utilisateur n'a jamais choisi.
///
/// `Localizations.localeOf` et non `context.locale` : le second exige que
/// `EasyLocalization` soit monté au-dessus, ce qui est vrai dans l'app et faux
/// dans un test de widget — et la préférence de langue n'a pas à dépendre de
/// l'endroit d'où on la regarde.
String _deviceLanguage(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

class _PreferencesSectionState extends ConsumerState<PreferencesSection> {
  String? _error;

  Future<void> _apply(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _error = getErrorMessage(error, stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UserPreferences prefs = ref.watch(userPreferencesProvider);
    final UserPreferencesNotifier notifier = ref.read(
      userPreferencesProvider.notifier,
    );
    final String? timezone = ref.watch(
      authProvider.select((AuthState s) => s.user?.timezone),
    );

    return PdlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'profile.units'.tr(),
            style: t.xs.copyWith(color: c.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          PdlSegmented<UnitSystem>(
            value: prefs.unitSystem == UnitSystem.$unknown
                ? UnitSystem.metric
                : prefs.unitSystem,
            onChanged: (UnitSystem value) =>
                _apply(() => notifier.setUnitSystem(value)),
            segments: <PdlSegment<UnitSystem>>[
              PdlSegment<UnitSystem>(
                key: keys.profile.unitSegment(UnitSystem.metric),
                value: UnitSystem.metric,
                label: 'profile.unitOptions.metric'.tr(),
              ),
              PdlSegment<UnitSystem>(
                key: keys.profile.unitSegment(UnitSystem.imperial),
                value: UnitSystem.imperial,
                label: 'profile.unitOptions.imperial'.tr(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // **L'exemple chiffré reflète le réglage** : c'est lui qui rend le
          // choix concret, et il serait absurde qu'il reste en métrique après
          // un passage à l'impérial.
          Text(
            key: keys.profile.unitsExample,
            'profile.unitsExample'.tr(
              namedArgs: <String, String>{
                'distance': AppFormatters.formatDistance(
                  66500,
                  prefs.unitSystem,
                ),
                'elevation': AppFormatters.formatElevation(
                  413,
                  prefs.unitSystem,
                ),
                'speed': AppFormatters.formatSpeed(26, prefs.unitSystem),
              },
            ),
            style: t.xs,
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          PdlSettingRow(
            key: keys.profile.timezoneRow,
            icon: PdlIcons.time,
            title: 'profile.timezone'.tr(),
            subtitle: 'profile.timezoneHint'.tr(),
            padding: EdgeInsets.zero,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    timezone ?? 'profile.status.deviceTimezone'.tr(),
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    style: t.sub,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(PdlIcons.chevronRight, size: 20, color: c.textPlaceholder),
              ],
            ),
            onTap: () => _pickTimezone(context, notifier, timezone),
          ),
          const SizedBox(height: PdlSpacing.section),
          Text(
            'profile.theme'.tr(),
            style: t.xs.copyWith(color: c.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          PdlSegmented<ThemePreference>(
            value: prefs.theme == ThemePreference.$unknown
                ? ThemePreference.system
                : prefs.theme,
            onChanged: (ThemePreference value) =>
                _apply(() => notifier.setTheme(value)),
            segments: <PdlSegment<ThemePreference>>[
              PdlSegment<ThemePreference>(
                key: keys.profile.themeSegment(ThemePreference.system),
                value: ThemePreference.system,
                label: 'profile.themeOptions.system'.tr(),
              ),
              PdlSegment<ThemePreference>(
                key: keys.profile.themeSegment(ThemePreference.light),
                value: ThemePreference.light,
                label: 'profile.themeOptions.light'.tr(),
              ),
              PdlSegment<ThemePreference>(
                key: keys.profile.themeSegment(ThemePreference.dark),
                value: ThemePreference.dark,
                label: 'profile.themeOptions.dark'.tr(),
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          PdlSettingRow(
            key: keys.profile.languageRow,
            padding: EdgeInsets.zero,
            icon: PdlIcons.language,
            title: 'profile.language'.tr(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'languages.${prefs.language ?? _deviceLanguage(context)}'
                      .tr(),
                  style: t.sub,
                ),
                const SizedBox(width: 4),
                Icon(PdlIcons.chevronRight, size: 20, color: c.textPlaceholder),
              ],
            ),
            onTap: () => _pickLanguage(context, notifier),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(tone: PdlBannerTone.danger, message: _error!),
          ],
        ],
      ),
    );
  }

  /// Le fuseau : une feuille cherchable, la liste étant longue de quelques
  /// centaines de noms. Rien ne part tant qu'on n'a pas choisi.
  Future<void> _pickTimezone(
    BuildContext context,
    UserPreferencesNotifier notifier,
    String? current,
  ) async {
    final String? picked = await showTimezoneSheet(context, current: current);
    if (picked != null && picked != current) {
      await _apply(() => notifier.setTimezone(picked));
    }
  }

  /// La feuille de langue : la sélection porte une **coche indigo**, pas un
  /// bouton radio — c'est un choix qui s'applique en se fermant, pas un
  /// formulaire à valider.
  Future<void> _pickLanguage(
    BuildContext context,
    UserPreferencesNotifier notifier,
  ) async {
    final PdlColors c = context.pdl;
    final String current =
        ref.read(userPreferencesProvider).language ?? _deviceLanguage(context);

    final String? picked = await PdlSheet.show<String>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title: 'profile.language'.tr(),
        headerAction: PdlButton(
          label: 'common.cancel'.tr(),
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
        bodyPadding: EdgeInsets.zero,
        footer: const SafeArea(top: false, child: SizedBox(height: 8)),
        children: <Widget>[
          for (final String code in <String>['fr', 'en'])
            PdlSettingRow(
              key: keys.profile.languageOption(code),
              title: 'languages.$code'.tr(),
              trailing: code == current
                  ? Icon(PdlIcons.check, size: 20, color: c.primary)
                  : const SizedBox.shrink(),
              onTap: () => Navigator.of(sheetContext).pop(code),
            ),
        ],
      ),
    );
    if (picked != null) await _apply(() => notifier.setLanguage(picked));
  }
}
