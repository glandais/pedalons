import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/locale_context.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/team_webhook_repository.dart';
import '../../providers/team_change.dart';

/// Les langues dans lesquelles un webhook écrit ses messages.
const List<String> kTeamWebhookLanguages = <String>['fr', 'en'];

/// Ouvre la feuille du webhook de [teamSlug], depuis les paramètres de
/// l'équipe (docs/LEDGER_*.md MOB-166).
Future<void> showTeamWebhookSheet(BuildContext context, String teamSlug) {
  return PdlFullSheet.show<void>(
    context: context,
    builder: (BuildContext _) => TeamWebhookSheet(teamSlug: teamSlug),
  );
}

/// Le webhook sortant d'une équipe — le pendant mobile de
/// `TeamWebhookSettings` du site : les annonces de l'équipe publiées dans
/// Slack, Discord, Mattermost ou sur une adresse https.
///
/// Une feuille, pas une section de l'écran : elle a son propre
/// « Enregistrer », distinct de celui du formulaire d'équipe.
///
/// **L'URL est un secret.** L'API ne la rend que masquée : le champ part
/// vide, l'adresse actuelle ne se lit que masquée, et un champ laissé vide
/// **garde** l'adresse — la requête n'en porte alors pas.
class TeamWebhookSheet extends ConsumerStatefulWidget {
  const TeamWebhookSheet({super.key, required this.teamSlug});

  final String teamSlug;

  @override
  ConsumerState<TeamWebhookSheet> createState() => _TeamWebhookSheetState();
}

class _TeamWebhookSheetState extends ConsumerState<TeamWebhookSheet> {
  final TextEditingController _url = TextEditingController();

  TeamWebhookDto? _webhook;
  Object? _loadError;

  String _language = kTeamWebhookLanguages.first;
  bool _enabled = true;

  bool _saving = false;
  bool _testing = false;
  bool _removing = false;
  String? _error;
  String? _notice;
  TeamWebhookTestDto? _testResult;

  bool get _busy => _saving || _testing || _removing;

  @override
  void initState() {
    super.initState();
    _url.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Le formulaire repart de l'état enregistré : la langue du webhook, sinon
  /// celle de l'app ; un nouveau webhook part activé — personne ne colle une
  /// URL pour la laisser éteinte.
  void _adopt(TeamWebhookDto webhook) {
    final String? language = webhook.language;
    final String appLanguage = getCurrentLocale();
    _webhook = webhook;
    _language = kTeamWebhookLanguages.contains(language)
        ? language!
        : kTeamWebhookLanguages.contains(appLanguage)
        ? appLanguage
        : kTeamWebhookLanguages.first;
    _enabled = webhook.configured ? webhook.enabled : true;
    _url.clear();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final TeamWebhookDto webhook = await ref
          .read(teamWebhookRepositoryProvider)
          .get(widget.teamSlug);
      if (mounted) setState(() => _adopt(webhook));
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  /// La première configuration exige une URL ; ensuite, un champ vide garde
  /// l'adresse actuelle.
  bool get _canSave {
    final TeamWebhookDto? webhook = _webhook;
    return webhook != null &&
        (webhook.configured || _url.text.trim().isNotEmpty);
  }

  Future<void> _save() async {
    if (_busy || !_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    final TeamWebhookRepository repository = ref.read(
      teamWebhookRepositoryProvider,
    );
    // Pris avant l'`await` : la feuille peut être fermée avant la réponse.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final String url = _url.text.trim();
    try {
      final TeamWebhookDto saved = await repository.save(
        widget.teamSlug,
        // Vide : l'adresse actuelle est gardée, le champ ne part pas.
        url: url.isEmpty ? null : url,
        language: _language,
        enabled: _enabled,
      );
      // Le tableau de bord montre l'état du webhook.
      notifyTeamChanged(container, widget.teamSlug);
      if (!mounted) return;
      setState(() {
        _adopt(saved);
        _saving = false;
        _testResult = null;
        _notice = 'teams.editor.webhook.saved'.tr();
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  /// Teste le webhook **enregistré**, pas ce qui est saisi.
  Future<void> _test() async {
    if (_busy) return;
    setState(() {
      _testing = true;
      _error = null;
      _notice = null;
      _testResult = null;
    });
    final TeamWebhookRepository repository = ref.read(
      teamWebhookRepositoryProvider,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      final TeamWebhookTestDto result = await repository.test(widget.teamSlug);
      notifyTeamChanged(container, widget.teamSlug);
      // Le test est un envoi : « Dernier envoi » a changé.
      TeamWebhookDto? refreshed;
      try {
        refreshed = await repository.get(widget.teamSlug);
      } catch (_) {
        // Le résultat du test reste vrai sans lui.
      }
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = result;
        if (refreshed != null) _webhook = refreshed;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    final bool confirmed = await confirmDestructive(
      context,
      title: 'teams.editor.webhook.removeTitle'.tr(),
      message: 'teams.editor.webhook.removeWarning'.tr(),
      confirmLabel: 'teams.editor.webhook.remove'.tr(),
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _removing = true;
      _error = null;
      _notice = null;
    });
    final TeamWebhookRepository repository = ref.read(
      teamWebhookRepositoryProvider,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      await repository.delete(widget.teamSlug);
      notifyTeamChanged(container, widget.teamSlug);
      if (!mounted) return;
      setState(() {
        _adopt(const TeamWebhookDto(configured: false, enabled: false));
        _removing = false;
        _testResult = null;
        _notice = 'teams.editor.webhook.removed'.tr();
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _removing = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  String _testMessage(TeamWebhookTestDto result) {
    final int? status = result.statusCode;
    if (result.success) {
      return 'teams.editor.webhook.testSuccess'.tr(
        namedArgs: <String, String>{'status': status?.toString() ?? '2xx'},
      );
    }
    final String error = result.error ?? '';
    if (status != null) {
      return 'teams.editor.webhook.testFailedStatus'
          .tr(namedArgs: <String, String>{'status': '$status', 'error': error})
          .trim();
    }
    return 'teams.editor.webhook.testFailed'.tr(
      namedArgs: <String, String>{'error': error},
    );
  }

  @override
  Widget build(BuildContext context) {
    final TeamWebhookDto? webhook = _webhook;
    return Padding(
      // Le pied (« Enregistrer ») reste au-dessus du clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: PdlFullSheet(
        key: keys.teamWebhook.sheet,
        title: 'teams.editor.webhook.title'.tr(),
        headerAction: PdlButton(
          key: keys.teamWebhook.closeButton,
          label: 'common.close'.tr(),
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          onPressed: () => Navigator.of(context).pop(),
        ),
        footer: webhook == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(PdlSpacing.section),
                  child: PdlButton(
                    key: keys.teamWebhook.saveButton,
                    label: 'routes.editor.save'.tr(),
                    loading: _saving,
                    loadingLabel: 'routes.editor.saving'.tr(),
                    enabled: _canSave && !_testing && !_removing,
                    fullWidth: true,
                    onPressed: _save,
                  ),
                ),
              ),
        bodyBuilder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.section,
            ),
            children: webhook == null
                ? _loadingChildren(context)
                : _formChildren(context, webhook),
          );
        },
      ),
    );
  }

  List<Widget> _loadingChildren(BuildContext context) {
    final Object? error = _loadError;
    if (error == null) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(PdlSpacing.section),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }
    return <Widget>[
      PdlEmptyState(
        key: keys.teamWebhook.loadError,
        variant: PdlEmptyVariant.error,
        title: 'teams.editor.webhook.loadError'.tr(),
        message: getErrorMessage(error),
        actions: <Widget>[
          PdlButton(label: 'common.retry'.tr(), onPressed: _load),
        ],
      ),
    ];
  }

  List<Widget> _formChildren(BuildContext context, TeamWebhookDto webhook) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String? maskedUrl = webhook.maskedUrl;
    final String? kind = webhook.kind;
    final String? lastStatus = webhook.lastStatus;
    final DateTime? lastAttempt = AppFormatters.tryParseDisplayTime(
      webhook.lastAttemptAt,
    );
    final TeamWebhookTestDto? testResult = _testResult;

    return <Widget>[
      Text(
        'teams.editor.webhook.description'.tr(),
        style: t.sub.copyWith(color: c.textDimmed),
      ),
      const SizedBox(height: PdlSpacing.section),

      if (_error != null) ...<Widget>[
        PdlBanner(
          key: keys.teamWebhook.errorBanner,
          tone: PdlBannerTone.danger,
          icon: PdlIcons.error,
          message: _error!,
          onDismiss: () => setState(() => _error = null),
          dismissSemanticLabel: 'common.close'.tr(),
        ),
        const SizedBox(height: PdlSpacing.section),
      ],
      if (_notice != null) ...<Widget>[
        PdlBanner(
          key: keys.teamWebhook.noticeBanner,
          tone: PdlBannerTone.info,
          icon: PdlIcons.checkCircle,
          message: _notice!,
          onDismiss: () => setState(() => _notice = null),
          dismissSemanticLabel: 'common.close'.tr(),
        ),
        const SizedBox(height: PdlSpacing.section),
      ],

      // ── Adresse actuelle ── Masquée par l'API : jamais plus que cela.
      if (webhook.configured && maskedUrl != null) ...<Widget>[
        Text('teams.editor.webhook.current'.tr(), style: t.bodyStrong),
        const SizedBox(height: PdlSpacing.badgeGap),
        Wrap(
          spacing: PdlSpacing.chipGap,
          runSpacing: PdlSpacing.badgeGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(maskedUrl, key: keys.teamWebhook.maskedUrl, style: t.sub),
            if (kind != null)
              PdlBadge(
                label: 'teams.dashboard.admin.webhook.kind.$kind'.tr(),
                tone: PdlFamily.gray.soft(c),
              ),
          ],
        ),
        const SizedBox(height: PdlSpacing.section),
      ],

      // ── URL ── Vide au départ : l'app n'a jamais l'URL entière.
      TextField(
        key: keys.teamWebhook.urlField,
        controller: _url,
        enabled: !_busy,
        keyboardType: TextInputType.url,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(kTeamWebhookUrlMaxLength),
        ],
        decoration: InputDecoration(
          labelText: 'teams.editor.webhook.urlLabel'.tr(),
          hintText: 'teams.editor.webhook.urlPlaceholder'.tr(),
          helperText: webhook.configured
              ? 'teams.editor.webhook.urlKeepHint'.tr()
              : 'teams.editor.webhook.urlHint'.tr(),
          helperMaxLines: 4,
        ),
      ),
      const SizedBox(height: PdlSpacing.section),

      // ── Langue ──
      Text('teams.editor.webhook.languageLabel'.tr(), style: t.bodyStrong),
      const SizedBox(height: PdlSpacing.badgeGap),
      Text(
        'teams.editor.webhook.languageHint'.tr(),
        style: t.xs.copyWith(color: c.textDimmed),
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      IgnorePointer(
        ignoring: _busy,
        child: PdlSegmented<String>(
          value: _language,
          onChanged: (String language) => setState(() => _language = language),
          segments: <PdlSegment<String>>[
            for (final String language in kTeamWebhookLanguages)
              PdlSegment<String>(
                key: keys.teamWebhook.language(language),
                value: language,
                label: 'languages.$language'.tr(),
              ),
          ],
        ),
      ),
      const SizedBox(height: PdlSpacing.chipGap),

      // ── Envoyer les annonces ──
      PdlSettingRow(
        padding: EdgeInsets.zero,
        title: 'teams.editor.webhook.enabledLabel'.tr(),
        subtitle: 'teams.editor.webhook.enabledHint'.tr(),
        trailing: PdlSwitch(
          key: keys.teamWebhook.enabledSwitch,
          value: _enabled,
          semanticLabel: 'teams.editor.webhook.enabledLabel'.tr(),
          onChanged: _busy
              ? null
              : (bool enabled) => setState(() => _enabled = enabled),
        ),
      ),

      // ── Dernier envoi ──
      if (webhook.configured && lastStatus != null) ...<Widget>[
        const SizedBox(height: PdlSpacing.section),
        Text('teams.editor.webhook.lastAttempt'.tr(), style: t.bodyStrong),
        const SizedBox(height: PdlSpacing.badgeGap),
        Wrap(
          spacing: PdlSpacing.chipGap,
          runSpacing: PdlSpacing.badgeGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            PdlBadge(
              key: keys.teamWebhook.lastStatus,
              label: 'teams.dashboard.admin.webhook.status.$lastStatus'.tr(),
              tone: switch (lastStatus) {
                'SENT' => PdlFamily.green.soft(c),
                'FAILED' => PdlFamily.red.soft(c),
                _ => PdlFamily.gray.soft(c),
              },
            ),
            if (lastAttempt != null)
              Text(
                AppFormatters.formatLongDateTime(lastAttempt),
                style: t.sub.copyWith(color: c.textDimmed),
              ),
          ],
        ),
        if (webhook.lastError != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.badgeGap),
          Text(webhook.lastError!, style: t.xs.copyWith(color: c.textDimmed)),
        ],
      ],

      // ── Tester, supprimer ── Le webhook enregistré seulement.
      if (webhook.configured) ...<Widget>[
        const SizedBox(height: PdlSpacing.section),
        if (testResult != null) ...<Widget>[
          PdlBanner(
            key: keys.teamWebhook.testResult,
            tone: testResult.success
                ? PdlBannerTone.info
                : PdlBannerTone.danger,
            icon: testResult.success ? PdlIcons.checkCircle : PdlIcons.error,
            message: _testMessage(testResult),
            onDismiss: () => setState(() => _testResult = null),
            dismissSemanticLabel: 'common.close'.tr(),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
        ],
        PdlButton(
          key: keys.teamWebhook.testButton,
          label: 'teams.editor.webhook.test'.tr(),
          variant: PdlButtonVariant.outline,
          loading: _testing,
          loadingLabel: 'teams.editor.webhook.testing'.tr(),
          enabled: !_saving && !_removing,
          fullWidth: true,
          onPressed: _test,
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlButton(
          key: keys.teamWebhook.removeButton,
          label: 'teams.editor.webhook.remove'.tr(),
          icon: PdlIcons.delete,
          variant: PdlButtonVariant.danger,
          loading: _removing,
          enabled: !_saving && !_testing,
          fullWidth: true,
          onPressed: _remove,
        ),
      ],
    ];
  }
}
