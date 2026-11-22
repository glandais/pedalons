import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/lists/list_states.dart';
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
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/gpx_preview_repository.dart';
import '../../providers/gpx_preview_provider.dart';

/// « Mes fichiers » (docs/LEDGER_*.md MOB-178) : les aperçus encore
/// disponibles de la personne, page après page, avec pour chacun son départ
/// (en tête, jamais une stat atténuée parmi d'autres — `BRAND-8`), sa
/// distance, ses dénivelés et son âge ; toucher une ligne ouvre sa fiche,
/// « Supprimer » demande confirmation.
class MyGpxPreviewsPage extends ConsumerStatefulWidget {
  const MyGpxPreviewsPage({super.key});

  @override
  ConsumerState<MyGpxPreviewsPage> createState() => _MyGpxPreviewsPageState();
}

class _MyGpxPreviewsPageState extends ConsumerState<MyGpxPreviewsPage> {
  /// L'aperçu en cours de suppression : un geste à la fois.
  String? _deleting;
  Object? _error;

  Future<void> _delete(GpxPreviewSummaryDto preview) async {
    if (_deleting != null) return;
    setState(() {
      _deleting = preview.id;
      _error = null;
    });
    try {
      final bool ok = await confirmDestructive(
        context,
        title: 'gpxTools.preview.deleteConfirmTitle'.tr(),
        message: 'gpxTools.preview.deleteConfirm'.tr(),
        confirmLabel: 'gpxTools.preview.delete'.tr(),
      );
      if (!ok || !mounted) return;
      await ref.read(gpxPreviewRepositoryProvider).delete(preview.id);
      if (!mounted) return;
      notifyGpxPreviewChanged(ref, previewId: preview.id);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PagedListState<GpxPreviewSummaryDto> state = ref.watch(
      myGpxPreviewsProvider,
    );
    final MyGpxPreviewsNotifier notifier = ref.read(
      myGpxPreviewsProvider.notifier,
    );
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'gpxTools.listFiles.title'.tr(),
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      onRefresh: notifier.refresh,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.section,
            PdlSpacing.section,
            PdlSpacing.chipGap,
          ),
          sliver: SliverList.list(
            children: <Widget>[
              Text(
                'gpxTools.retentionNotice'.tr(),
                style: t.sub.copyWith(color: c.textDimmed),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.chipGap),
                PdlBanner(
                  tone: PdlBannerTone.danger,
                  message: getErrorMessage(_error!),
                  onDismiss: () => setState(() => _error = null),
                  dismissSemanticLabel: 'common.close'.tr(),
                ),
              ],
            ],
          ),
        ),
        ..._list(state, notifier),
      ],
    );
  }

  List<Widget> _list(
    PagedListState<GpxPreviewSummaryDto> state,
    MyGpxPreviewsNotifier notifier,
  ) {
    if (state.isLoadingInitial) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          sliver: SliverList.list(
            children: const <Widget>[
              PdlSkeleton(height: 72),
              SizedBox(height: PdlSpacing.feedGap),
              PdlSkeleton(height: 72),
              SizedBox(height: PdlSpacing.feedGap),
              PdlSkeleton(height: 72),
            ],
          ),
        ),
      ];
    }
    if (state.initialError != null) {
      return <Widget>[
        ListStateSliver(
          child: ListLoadError(
            error: state.initialError!,
            onRetry: notifier.loadFirstPage,
          ),
        ),
      ];
    }
    if (state.isEmpty) {
      return <Widget>[
        ListStateSliver(
          child: PdlEmptyState(
            key: keys.gpxTools.listEmpty,
            variant: PdlEmptyVariant.empty,
            icon: PdlIcons.gpx,
            title: 'gpxTools.listFiles.empty'.tr(),
            actions: <Widget>[
              PdlButton(
                label: 'gpxTools.viewFile.submit'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        key: keys.gpxTools.list,
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: PdlSpacing.feedGap),
          itemBuilder: (BuildContext context, int index) {
            notifier.onItemBuilt(index);
            final GpxPreviewSummaryDto preview = state.items[index];
            return _PreviewRow(
              key: keys.gpxTools.row(preview.id),
              preview: preview,
              deleting: _deleting == preview.id,
              enabled: _deleting == null,
              onDelete: () => _delete(preview),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(PdlSpacing.section),
        sliver: SliverToBoxAdapter(
          child: PagedListFooter(
            state: state,
            onRetry: notifier.retryNextPage,
            itemNounKey: 'gpxTools.listFiles.noun',
          ),
        ),
      ),
    ];
  }
}

class _PreviewRow extends ConsumerWidget {
  const _PreviewRow({
    super.key,
    required this.preview,
    required this.deleting,
    required this.enabled,
    required this.onDelete,
  });

  final GpxPreviewSummaryDto preview;
  final bool deleting;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final DateTime? departure = DateTime.tryParse(preview.departureTime ?? '');
    final DateTime? createdAt = DateTime.tryParse(preview.createdAt);
    final String stats = <String>[
      AppFormatters.formatDistance(preview.distance, units),
      '↑ ${AppFormatters.formatElevation(preview.elevationGain, units)}',
      '↓ ${AppFormatters.formatElevation(preview.elevationLoss, units)}',
      if (createdAt != null) AppFormatters.formatRelative(createdAt),
    ].join(' · ');

    return PdlCard(
      onTap: () => context.push(Paths.gpxToolsView(preview.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            preview.name,
            style: t.cardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (departure != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.badgeGap),
            PdlDepartureLine(
              headline: AppFormatters.formatDeparture(
                departure,
                preview.departureTimezone,
              ),
            ),
          ],
          const SizedBox(height: PdlSpacing.badgeGap),
          Text(stats, style: t.sub.copyWith(color: c.textDimmed)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PdlButton(
              key: keys.gpxTools.rowDelete(preview.id),
              label: 'gpxTools.preview.delete'.tr(),
              icon: PdlIcons.delete,
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              loading: deleting,
              enabled: enabled,
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
