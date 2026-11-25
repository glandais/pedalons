import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/material.dart';
import '../../../../core/pagination/pagination.dart';
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
import '../../../routes/data/gpx_file_source.dart';
import '../../../routes/domain/gpx_check.dart';
import '../../../routes/domain/planner_quota.dart';
import '../../../routes/presentation/widgets/editor/gpx_refused_banner.dart';
import '../../../routes/presentation/widgets/editor/planner_quota_message.dart';
import '../../data/gpx_files_picker.dart';
import '../../data/gpx_preview_repository.dart';
import '../../providers/gpx_preview_provider.dart';

/// Les bornes d'une fusion, vérifiées avant l'envoi — le serveur les
/// revérifie, et borne la taille cumulée des fichiers comme un envoi seul.
const int kGpxMergeMinFiles = 2;
const int kGpxMergeMaxFiles = 10;

/// Le nombre de fichiers récents que l'accueil montre avant « Tout voir ».
const int kGpxHubRecentFiles = 2;

/// L'accueil des outils GPX (docs/LEDGER_*.md MOB-178), sans barre : l'onglet
/// « Outils GPX » d'Explorer le pose sous son sélecteur, `GpxToolsPage` sous
/// sa barre quand un lien ouvre `/outils-gpx` (docs/LEDGER_*.md MOB-192).
///
/// De haut en bas : « Visualiser un fichier », le geste principal, en grande
/// cible ; une liste des autres gestes (fusionner, tracer si le domaine ouvre
/// le planificateur, ouvrir une carte) ; les derniers fichiers déposés avec
/// « Tout voir » ; la mention de conservation.
///
/// « Visualiser » et « Fusionner » envoient dès le choix, comme au site : le
/// serveur choisit l'ordre et le sens des traces d'une fusion, il n'y a rien à
/// ranger ici. Ni date de départ ni vitesse : elles se posent ensuite, depuis
/// la modification de l'aperçu.
///
/// **Un geste à la fois** : pendant la lecture ou l'envoi d'un fichier, les
/// deux gestes d'envoi sont inactifs.
class GpxToolsHub extends ConsumerStatefulWidget {
  const GpxToolsHub({super.key});

  @override
  ConsumerState<GpxToolsHub> createState() => _GpxToolsHubState();
}

enum _Busy { none, view, merge }

class _GpxToolsHubState extends ConsumerState<GpxToolsHub> {
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

  /// « Créer un parcours » : inactif, avec sa raison, quand les
  /// enregistrements du mois d'un tracé dessiné sont tous utilisés (quota
  /// personnel, `BILL-10`). Aucun compteur avant ; les gestes sur les fichiers
  /// restent ouverts.
  Widget _drawRow(PdlColors c) {
    final PlannerQuotaDto? quota = ref.watch(
      authProvider.select((AuthState s) => s.user?.plannerQuota),
    );
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    final bool spent = isPlannerQuotaSpent(quota, platformAdmin: platformAdmin);
    return GpxToolRow(
      key: keys.gpxTools.drawButton,
      icon: PdlIcons.route,
      chip: c.blueSoft,
      onChip: c.blueOnSoft,
      title: 'gpxTools.createFromScratch.title'.tr(),
      subtitle: 'gpxTools.createFromScratch.short'.tr(),
      enabled: !spent,
      divider: true,
      onTap: () => context.push(Paths.gpxToolsNew()),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    const SizedBox gap = SizedBox(height: PdlSpacing.section);

    return CustomScrollView(
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
              _ViewFileTile(
                key: keys.gpxTools.viewFileButton,
                loading: _busy == _Busy.view,
                enabled: _idle,
                onTap: _viewFile,
              ),
              gap,
              PdlCard(
                padding: PdlCardPadding.none,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GpxToolRow(
                      key: keys.gpxTools.mergeButton,
                      icon: PdlIcons.copy,
                      chip: c.orangeSoft,
                      onChip: c.orangeOnSoft,
                      title: 'gpxTools.merge.title'.tr(),
                      subtitle: 'gpxTools.merge.short'.tr(),
                      loading: _busy == _Busy.merge,
                      enabled: _idle,
                      onTap: _merge,
                    ),
                    // Tracer de zéro est une affaire du domaine ; les gestes
                    // sur les fichiers restent.
                    if (_plannerEnabled) _drawRow(c),
                    GpxToolRow(
                      key: keys.gpxTools.blankMapButton,
                      icon: PdlIcons.map,
                      chip: c.tealSoft,
                      onChip: c.tealOnSoft,
                      title: 'gpxTools.blankMap.title'.tr(),
                      subtitle: 'gpxTools.blankMap.short'.tr(),
                      divider: true,
                      onTap: () => context.push(Paths.gpxToolsBlankMap()),
                    ),
                  ],
                ),
              ),
              gap,
              PdlSectionHeader(
                title: 'gpxTools.listFiles.title'.tr(),
                action: PdlButton(
                  key: keys.gpxTools.listButton,
                  label: 'common.viewAll'.tr(),
                  variant: PdlButtonVariant.text,
                  size: PdlButtonSize.sm,
                  onPressed: () => context.push(Paths.gpxToolsList()),
                ),
              ),
              const _RecentFiles(),
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

/// « Visualiser un fichier » : le geste principal de l'accueil, en grande
/// cible sur fond `primarySoft`.
class _ViewFileTile extends StatelessWidget {
  const _ViewFileTile({
    super.key,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool active = enabled && !loading;
    return Semantics(
      button: true,
      enabled: active,
      child: Material(
        color: c.primarySoft,
        shape: RoundedRectangleBorder(
          borderRadius: PdlRadii.cardAll,
          side: BorderSide(color: c.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: active ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PdlSpacing.card,
              vertical: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 32,
                  child: loading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.primaryOnSoft,
                          ),
                        )
                      : Icon(
                          PdlIcons.fileAdd,
                          size: 32,
                          color: c.primaryOnSoft,
                        ),
                ),
                const SizedBox(height: PdlSpacing.chipGap),
                Text(
                  'gpxTools.viewFile.title'.tr(),
                  textAlign: TextAlign.center,
                  style: t.cardTitle.copyWith(color: c.primaryOnSoft),
                ),
                const SizedBox(height: PdlSpacing.badgeGap),
                Text(
                  'gpxTools.viewFile.short'.tr(),
                  textAlign: TextAlign.center,
                  style: t.sub.copyWith(color: c.primaryOnSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une ligne de la liste des gestes de l'accueil : une pastille d'icône
/// colorée, un titre et sa phrase, un chevron ; la ligne entière est la
/// cible. [extra] se pose sous le texte : le mot du quota épuisé sous
/// « Créer un parcours ».
class GpxToolRow extends StatelessWidget {
  const GpxToolRow({
    super.key,
    required this.icon,
    required this.chip,
    required this.onChip,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
    this.divider = false,
    this.extra,
  });

  final IconData icon;
  final Color chip;
  final Color onChip;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  /// Un trait au-dessus : toutes les lignes sauf la première.
  final bool divider;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool active = enabled && !loading;
    final Color titleColor = active ? c.text : c.disabledText;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: c.borderSubtle)) : null,
      ),
      child: Semantics(
        button: true,
        enabled: active,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: active ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: PdlSettingRow.minHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PdlSpacing.card,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: active ? chip : c.disabledBg,
                        borderRadius: PdlRadii.mdAll,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: active ? onChip : c.disabledText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            style: t.bodyStrong.copyWith(color: titleColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: t.sub.copyWith(color: c.textDimmed),
                          ),
                          if (extra != null) ...<Widget>[
                            const SizedBox(height: PdlSpacing.chipGap),
                            extra!,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.textDimmed,
                              ),
                            )
                          : Icon(
                              PdlIcons.chevronRight,
                              size: 20,
                              color: c.textPlaceholder,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les [kGpxHubRecentFiles] derniers fichiers encore disponibles, chacun
/// ouvrant sa fiche ; la liste entière est derrière « Tout voir ».
class _RecentFiles extends ConsumerWidget {
  const _RecentFiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final PagedListState<GpxPreviewSummaryDto> state = ref.watch(
      myGpxPreviewsProvider,
    );
    if (state.isLoadingInitial) {
      return const PdlSkeleton(height: 64);
    }
    // Une erreur de lecture ne bloque aucun geste : « Tout voir » la redira.
    if (state.initialError != null || state.isEmpty) {
      return Text(
        'gpxTools.listFiles.empty'.tr(),
        style: t.sub.copyWith(color: c.textDimmed),
      );
    }
    final UnitSystem units = ref.watch(unitSystemProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final GpxPreviewSummaryDto preview in state.items.take(
          kGpxHubRecentFiles,
        )) ...<Widget>[
          PdlCard(
            key: keys.gpxTools.recent(preview.id),
            padding: PdlCardPadding.tight,
            onTap: () => context.push(Paths.gpxToolsView(preview.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  preview.name,
                  style: t.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _stats(preview, units),
                  style: t.sub.copyWith(color: c.textDimmed),
                ),
              ],
            ),
          ),
          const SizedBox(height: PdlSpacing.feedGap),
        ],
      ],
    );
  }

  static String _stats(GpxPreviewSummaryDto preview, UnitSystem units) {
    final DateTime? createdAt = DateTime.tryParse(preview.createdAt);
    return <String>[
      AppFormatters.formatDistance(preview.distance, units),
      '↑ ${AppFormatters.formatElevation(preview.elevationGain, units)}',
      if (createdAt != null) AppFormatters.formatRelative(createdAt),
    ].join(' · ');
  }
}
