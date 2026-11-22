import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../../core/config/config_provider.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../routes/data/gpx_file_source.dart';
import '../../../routes/domain/gpx_check.dart';
import '../../../routes/domain/planner_quota.dart';
import '../../../routes/presentation/widgets/editor/gpx_refused_banner.dart';
import '../../../routes/presentation/widgets/editor/planner_quota_message.dart';
import '../../data/gpx_files_picker.dart';
import '../../data/gpx_preview_repository.dart';
import '../../providers/gpx_preview_provider.dart';
import '../widgets/gpx_tool_card.dart';

/// Les bornes d'une fusion, vérifiées avant l'envoi — le serveur les
/// revérifie, et borne la taille cumulée des fichiers comme un envoi seul.
const int kGpxMergeMinFiles = 2;
const int kGpxMergeMaxFiles = 10;

/// L'accueil des outils GPX (docs/LEDGER_*.md MOB-178), ouvert depuis
/// l'onglet Parcours : les cartes du site (`GpxToolsPage`) — visualiser un
/// fichier, en fusionner plusieurs, en tracer un (si le domaine ouvre le
/// planificateur), lister les siens —, et la mention de conservation.
///
/// « Visualiser » et « Fusionner » envoient dès le choix, comme au site : le
/// serveur choisit l'ordre et le sens des traces d'une fusion, il n'y a rien à
/// ranger ici. Ni date de départ ni vitesse : elles se posent ensuite, depuis
/// la modification de l'aperçu.
///
/// **Un geste à la fois** : pendant la lecture ou l'envoi d'un fichier, les
/// deux boutons d'envoi sont inactifs.
class GpxToolsPage extends ConsumerStatefulWidget {
  const GpxToolsPage({super.key});

  @override
  ConsumerState<GpxToolsPage> createState() => _GpxToolsPageState();
}

enum _Busy { none, view, merge }

class _GpxToolsPageState extends ConsumerState<GpxToolsPage> {
  _Busy _busy = _Busy.none;

  /// Un fichier refusé, localement ou par le serveur, avec son nom.
  GpxRefused? _refused;

  /// Le mot d'une sélection hors des bornes d'une fusion.
  String? _countWarning;

  /// Un autre échec d'envoi (réseau, droits).
  Object? _error;

  bool get _idle => _busy == _Busy.none;

  void _clearMessages() {
    _refused = null;
    _countWarning = null;
    _error = null;
  }

  Future<void> _viewFile() async {
    if (!_idle) return;
    setState(() {
      _busy = _Busy.view;
      _clearMessages();
    });
    GpxFile? picked;
    try {
      picked = await ref.read(gpxFilePickerProvider).pick();
      if (picked == null || !mounted) return;
      final GpxCheck check = await inspectGpxFile(picked);
      if (!mounted) return;
      if (check is GpxRefused) {
        setState(() => _refused = check);
        return;
      }
      final GpxPreviewDto preview = await ref
          .read(gpxPreviewRepositoryProvider)
          .createFromFile(picked);
      _opened(preview);
    } catch (error, stackTrace) {
      _failed(error, stackTrace, fileName: picked?.name);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _merge() async {
    if (!_idle) return;
    setState(() {
      _busy = _Busy.merge;
      _clearMessages();
    });
    List<GpxFile> files = const <GpxFile>[];
    try {
      files = await ref.read(gpxFilesPickerProvider).pickMany();
      if (files.isEmpty || !mounted) return;
      if (files.length < kGpxMergeMinFiles ||
          files.length > kGpxMergeMaxFiles) {
        setState(
          () => _countWarning = 'gpxTools.merge.fileCount'.tr(
            namedArgs: <String, String>{
              'min': '$kGpxMergeMinFiles',
              'max': '$kGpxMergeMaxFiles',
              'selected': '${files.length}',
            },
          ),
        );
        return;
      }
      for (final GpxFile file in files) {
        final GpxCheck check = await inspectGpxFile(file);
        if (!mounted) return;
        if (check is GpxRefused) {
          setState(() => _refused = check);
          return;
        }
      }
      final GpxPreviewDto preview = await ref
          .read(gpxPreviewRepositoryProvider)
          .merge(files);
      _opened(preview);
    } catch (error, stackTrace) {
      // Le serveur ne dit pas lequel : la phrase les nomme tous.
      _failed(
        error,
        stackTrace,
        fileName: files.map((GpxFile f) => f.name).join(', '),
      );
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  /// L'aperçu existe : « Mes fichiers » se relit, et sa fiche s'ouvre.
  void _opened(GpxPreviewDto preview) {
    notifyGpxPreviewChanged(ref);
    if (!mounted) return;
    context.push(Paths.gpxToolsView(preview.id));
  }

  /// Un refus du serveur qui tient au fichier se dit comme un refus local ;
  /// tout autre échec, en bandeau d'erreur.
  void _failed(
    Object error,
    StackTrace stackTrace, {
    required String? fileName,
  }) {
    if (!mounted) return;
    if (error is PlatformException) {
      setState(() => _error = error);
      return;
    }
    final GpxRefusal? refusal = gpxRefusalOfApiCode(
      resolveApiError(error, stackTrace).code,
    );
    setState(() {
      if (refusal != null) {
        _refused = GpxRefused(fileName ?? '', refusal);
      } else {
        _error = error;
      }
    });
  }

  bool get _plannerEnabled =>
      ref.watch(appConfigProvider).value?.enableGpxPlanner ?? false;

  /// « Créer un parcours » : fermé, avec sa raison, quand les enregistrements
  /// du mois d'un tracé dessiné sont tous utilisés (quota personnel,
  /// `BILL-10`). Aucun compteur avant ; les cartes des fichiers restent
  /// ouvertes.
  Widget _drawCard() {
    final PlannerQuotaDto? quota = ref.watch(
      authProvider.select((AuthState s) => s.user?.plannerQuota),
    );
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    final bool spent = isPlannerQuotaSpent(quota, platformAdmin: platformAdmin);
    return GpxToolCard(
      icon: PdlIcons.route,
      title: 'gpxTools.createFromScratch.title'.tr(),
      description: 'gpxTools.createFromScratch.description'.tr(),
      extra: spent
          ? PlannerQuotaMessage(
              key: keys.gpxTools.quotaMessage,
              refusal: PlannerQuotaRefusal(
                team: false,
                limit: quota!.limit!,
                resetsOn: quota.resetsOn,
              ),
              help: true,
            )
          : null,
      action: PdlButton(
        key: keys.gpxTools.drawButton,
        label: 'gpxTools.createFromScratch.submit'.tr(),
        variant: PdlButtonVariant.outline,
        enabled: !spent,
        onPressed: () => context.push(Paths.gpxToolsNew()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    const SizedBox gap = SizedBox(height: PdlSpacing.feedGap);

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'gpxTools.title'.tr(),
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      slivers: <Widget>[
        SliverPadding(
          key: keys.gpxTools.hub,
          padding: const EdgeInsets.all(PdlSpacing.section),
          sliver: SliverList.list(
            children: <Widget>[
              Text(
                'gpxTools.subtitle'.tr(),
                style: t.sub.copyWith(color: c.textDimmed),
              ),
              gap,
              if (_refused != null) ...<Widget>[
                GpxRefusedBanner(
                  refused: _refused!,
                  busy: !_idle,
                  onPickAnother: _viewFile,
                ),
                gap,
              ],
              if (_countWarning != null) ...<Widget>[
                PdlBanner(
                  tone: PdlBannerTone.warn,
                  message: _countWarning!,
                  onDismiss: () => setState(() => _countWarning = null),
                  dismissSemanticLabel: 'common.close'.tr(),
                ),
                gap,
              ],
              if (_error != null) ...<Widget>[
                PdlBanner(
                  key: keys.gpxTools.hubError,
                  tone: PdlBannerTone.danger,
                  message: getErrorMessage(_error!),
                  onDismiss: () => setState(() => _error = null),
                  dismissSemanticLabel: 'common.close'.tr(),
                ),
                gap,
              ],
              GpxToolCard(
                icon: PdlIcons.gpx,
                title: 'gpxTools.viewFile.title'.tr(),
                description: 'gpxTools.viewFile.description'.tr(),
                action: PdlButton(
                  key: keys.gpxTools.viewFileButton,
                  label: 'gpxTools.viewFile.submit'.tr(),
                  icon: PdlIcons.fileAdd,
                  loading: _busy == _Busy.view,
                  enabled: _idle,
                  onPressed: _viewFile,
                ),
              ),
              gap,
              GpxToolCard(
                icon: PdlIcons.copy,
                title: 'gpxTools.merge.title'.tr(),
                description: 'gpxTools.merge.description'.tr(),
                action: PdlButton(
                  key: keys.gpxTools.mergeButton,
                  label: 'gpxTools.merge.submit'.tr(),
                  variant: PdlButtonVariant.outline,
                  loading: _busy == _Busy.merge,
                  enabled: _idle,
                  onPressed: _merge,
                ),
              ),
              gap,
              // Tracer de zéro est une affaire du domaine ; les cartes des
              // fichiers restent.
              if (_plannerEnabled) ...<Widget>[_drawCard(), gap],
              GpxToolCard(
                icon: PdlIcons.list,
                title: 'gpxTools.listFiles.title'.tr(),
                description: 'gpxTools.listFiles.description'.tr(),
                action: PdlButton(
                  key: keys.gpxTools.listButton,
                  label: 'gpxTools.listFiles.submit'.tr(),
                  variant: PdlButtonVariant.outline,
                  onPressed: () => context.push(Paths.gpxToolsList()),
                ),
              ),
              gap,
              Text(
                'gpxTools.retentionNotice'.tr(),
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
