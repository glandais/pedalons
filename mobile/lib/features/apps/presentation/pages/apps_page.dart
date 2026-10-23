import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/adaptive/content_width_constraint.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../keys.dart';
import '../../data/beta_signup_repository.dart';

/// La release `karoo-latest`, réécrite à chaque tag `karoo.X.Y.Z`
/// (`karoo/PUBLISH.md`). Une URL GitHub exprès : Hammerhead n'a vérifié
/// l'installation par le Companion que pour des liens GitHub.
const String _kKarooApkUrl =
    'https://github.com/glandais/pedalons/releases/download/karoo-latest/pedalons.apk';

/// La release `mobile-latest`, réécrite à chaque tag `mobile.X.Y.Z.N` poussé
/// par `mobile/publish_beta.sh` (`.github/workflows/mobile-release.yml`) :
/// l'app pour les appareils Android sans Google Play.
const String _kMobileApkUrl =
    'https://github.com/glandais/pedalons/releases/download/mobile-latest/pedalons-android.apk';
const String _kKarooSideloadingUrl =
    'https://support.hammerhead.io/hc/en-us/articles/31576497036827-Companion-App-Sideloading';
const String _kAppStoreUrl = 'https://apps.apple.com/app/id6761760079';

/// La fiche du Connect IQ Store (`garmin-app/PUBLISH.md`) ; sans locale, le
/// store prend la langue du navigateur.
const String _kGarminStoreUrl =
    'https://apps.garmin.com/apps/262ea335-a5b7-4a6a-bb30-fc6f5db9b115';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(betaSignupRepositoryProvider)
          .signUp(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'apps.title'.tr(),
        leading: const BackOrHomeButton(),
      ),
      body: SingleChildScrollView(
        child: ContentWidthConstraint(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'apps.subtitle'.tr(),
                style: t.body.copyWith(color: context.pdl.textDimmed),
              ),
              const SizedBox(height: PdlSpacing.section),
              _AppTile(
                icon: PdlIcons.device,
                title: 'apps.mobile.title'.tr(),
                description: 'apps.mobile.description'.tr(),
                available: true,
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PdlButton(
                      label: 'apps.mobile.download'.tr(),
                      icon: PdlIcons.openExternal,
                      variant: PdlButtonVariant.outline,
                      onPressed: () => openLink(context, _kAppStoreUrl),
                    ),
                    PdlButton(
                      label: 'apps.mobile.apk'.tr(),
                      icon: PdlIcons.download,
                      variant: PdlButtonVariant.text,
                      size: PdlButtonSize.sm,
                      onPressed: () => openLink(context, _kMobileApkUrl),
                    ),
                    Text('apps.mobile.apkHint'.tr(), style: t.sub),
                  ],
                ),
              ),
              const SizedBox(height: PdlSpacing.cardTight),
              _AppTile(
                icon: PdlIcons.devices,
                title: 'apps.garmin.title'.tr(),
                description: 'apps.garmin.description'.tr(),
                available: true,
                action: PdlButton(
                  label: 'apps.garmin.download'.tr(),
                  icon: PdlIcons.openExternal,
                  variant: PdlButtonVariant.outline,
                  onPressed: () => openLink(context, _kGarminStoreUrl),
                ),
              ),
              const SizedBox(height: PdlSpacing.cardTight),
              _AppTile(
                icon: PdlIcons.ride,
                title: 'apps.karoo.title'.tr(),
                description: 'apps.karoo.description'.tr(),
                available: true,
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Builder(
                      builder: (BuildContext buttonContext) => PdlButton(
                        key: keys.apps.karooShareButton,
                        label: 'apps.karoo.share'.tr(),
                        icon: PdlIcons.share,
                        variant: PdlButtonVariant.outline,
                        onPressed: () => _shareKarooApk(buttonContext),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('apps.karoo.shareHint'.tr(), style: t.sub),
                    PdlButton(
                      label: 'apps.karoo.instructions'.tr(),
                      icon: PdlIcons.openExternal,
                      variant: PdlButtonVariant.text,
                      size: PdlButtonSize.sm,
                      onPressed: () => openLink(context, _kKarooSideloadingUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PdlSpacing.section),
              PdlCard(
                child: _sent
                    ? _SentState(key: keys.apps.betaSentState, t: t)
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text('apps.signup.title'.tr(), style: t.cardTitle),
                            const SizedBox(height: 4),
                            Text('apps.signup.subtitle'.tr(), style: t.sub),
                            const SizedBox(height: PdlSpacing.cardTight),
                            TextFormField(
                              key: keys.apps.betaEmailField,
                              controller: _emailController,
                              enabled: !_sending,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              style: t.body,
                              decoration: InputDecoration(
                                labelText: 'apps.signup.emailLabel'.tr(),
                                filled: true,
                                fillColor: context.pdl.surfaceAlt,
                                border: OutlineInputBorder(
                                  borderRadius: PdlRadii.mdAll,
                                  borderSide: BorderSide(
                                    color: context.pdl.border,
                                  ),
                                ),
                              ),
                              validator: (String? value) {
                                final String v = value?.trim() ?? '';
                                final RegExp emailPattern = RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                );
                                return emailPattern.hasMatch(v)
                                    ? null
                                    : 'apps.signup.validation.email'.tr();
                              },
                            ),
                            if (_error != null) ...<Widget>[
                              const SizedBox(height: PdlSpacing.cardTight),
                              PdlBanner(
                                tone: PdlBannerTone.danger,
                                message: _error!,
                              ),
                            ],
                            const SizedBox(height: PdlSpacing.cardTight),
                            PdlButton(
                              key: keys.apps.betaSubmitButton,
                              label: 'apps.signup.submit'.tr(),
                              loading: _sending,
                              fullWidth: true,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le Karoo s'installe par la feuille de partage : l'APK partagé vers
/// Hammerhead Companion fait apparaître « Install » sur le Karoo. Le lien
/// part en `uri`, que le Companion reçoit tel quel.
Future<void> _shareKarooApk(BuildContext context) async {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      uri: Uri.parse(_kKarooApkUrl),
      title: 'apps.karoo.title'.tr(),
      // Sur iPad la feuille s'ancre au bouton.
      sharePositionOrigin: box == null
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

class _SentState extends StatelessWidget {
  const _SentState({super.key, required this.t});

  final PdlTypography t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(PdlIcons.checkCircle, color: context.pdl.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text('apps.signup.sent.title'.tr(), style: t.cardTitle),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('apps.signup.sent.message'.tr(), style: t.sub),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.available,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool available;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final PdlColors c = context.pdl;
    final PdlTone statusTone = available
        ? PdlTone.pair(c.softGreen, c.success)
        : PdlTone.pair(c.softGray, c.neutral);
    return PdlCard(
      flat: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: c.primary),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(title, style: t.cardTitle)),
                    PdlBadge(
                      label:
                          (available
                                  ? 'apps.status.available'
                                  : 'apps.status.comingSoon')
                              .tr(),
                      tone: statusTone,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: t.sub),
                if (action != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.cardTight),
                  Align(alignment: Alignment.centerLeft, child: action),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
