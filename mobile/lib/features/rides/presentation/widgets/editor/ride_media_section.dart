import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/authenticated_image.dart';
import '../../../../../keys.dart';

/// Le logo, les images et les pièces jointes d'une sortie (`media.assets`),
/// comme le `MediaEditor` du site (ledger `MOB-76`). Chaque ajout est un
/// envoi immédiat (`POST …/assets`) : l'asset rendu n'est rattaché à la
/// sortie qu'à l'enregistrement, et un asset retiré ici n'y sera pas.
class RideMediaSection extends StatelessWidget {
  const RideMediaSection({
    super.key,
    required this.assets,
    required this.busy,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
  });

  final AssetsDto assets;

  /// Un envoi est en cours : les boutons d'ajout attendent.
  final bool busy;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onAddImage;
  final ValueChanged<AssetDto> onRemoveImage;
  final VoidCallback onAddAttachment;
  final ValueChanged<AssetDto> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final AssetDto? logo = assets.logo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ── Logo ──
        Text('rides.editor.logo'.tr(), style: t.bodyStrong),
        const SizedBox(height: PdlSpacing.chipGap),
        Row(
          children: <Widget>[
            if (logo != null) ...<Widget>[
              _Thumb(asset: logo),
              const SizedBox(width: PdlSpacing.cardTight),
            ],
            Expanded(
              child: Wrap(
                spacing: PdlSpacing.chipGap,
                runSpacing: PdlSpacing.chipGap,
                children: <Widget>[
                  PdlButton(
                    key: keys.rideEditor.logoButton,
                    label: 'rides.editor.logoAdd'.tr(),
                    icon: PdlIcons.image,
                    variant: PdlButtonVariant.outline,
                    size: PdlButtonSize.sm,
                    enabled: !busy,
                    onPressed: onPickLogo,
                  ),
                  if (logo != null)
                    PdlButton(
                      label: 'rides.editor.logoRemove'.tr(),
                      variant: PdlButtonVariant.text,
                      size: PdlButtonSize.sm,
                      enabled: !busy,
                      onPressed: onRemoveLogo,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PdlSpacing.section),

        // ── Images ──
        Text('rides.editor.images'.tr(), style: t.bodyStrong),
        const SizedBox(height: PdlSpacing.badgeGap),
        Text(
          'rides.editor.imagesHint'.tr(),
          style: t.xs.copyWith(color: c.textDimmed),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        Wrap(
          spacing: PdlSpacing.chipGap,
          runSpacing: PdlSpacing.chipGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final AssetDto image in assets.images)
              _RemovableThumb(
                asset: image,
                semanticLabel: 'rides.editor.imageRemove'.tr(
                  namedArgs: <String, String>{'file': image.fileName},
                ),
                onRemove: busy ? null : () => onRemoveImage(image),
              ),
            PdlButton(
              key: keys.rideEditor.imageAddButton,
              label: 'rides.editor.imageAdd'.tr(),
              icon: PdlIcons.imageAdd,
              variant: PdlButtonVariant.outline,
              size: PdlButtonSize.sm,
              enabled: !busy,
              onPressed: onAddImage,
            ),
          ],
        ),
        const SizedBox(height: PdlSpacing.section),

        // ── Pièces jointes ──
        Text('rides.editor.attachments'.tr(), style: t.bodyStrong),
        const SizedBox(height: PdlSpacing.badgeGap),
        for (final AssetDto file in assets.attachments)
          PdlAttachmentRow(
            name: file.fileName,
            subtitle: file.size == null
                ? null
                : AppFormatters.formatFileSize(file.size!),
            actionIcon: PdlIcons.remove,
            actionSemanticLabel: 'rides.editor.attachmentRemove'.tr(
              namedArgs: <String, String>{'file': file.fileName},
            ),
            onAction: busy ? null : () => onRemoveAttachment(file),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PdlButton(
            key: keys.rideEditor.attachmentAddButton,
            label: 'rides.editor.attachmentAdd'.tr(),
            icon: PdlIcons.fileAdd,
            variant: PdlButtonVariant.outline,
            size: PdlButtonSize.sm,
            enabled: !busy,
            onPressed: onAddAttachment,
          ),
        ),
        if (busy) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          Text(
            'rides.editor.uploading'.tr(),
            style: t.xs.copyWith(color: c.textDimmed),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.asset});

  final AssetDto asset;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final String? url = asset.imageUrl;
    return ClipRRect(
      borderRadius: PdlRadii.mdAll,
      child: SizedBox(
        width: PdlMetrics.thumbMd,
        height: PdlMetrics.thumbMd,
        child: url == null
            ? ColoredBox(
                color: c.surfaceAlt,
                child: Icon(PdlIcons.image, color: c.textDimmed),
              )
            : AuthenticatedImage(
                imageUrl: url,
                size: 256,
                fit: BoxFit.cover,
                width: PdlMetrics.thumbMd,
                height: PdlMetrics.thumbMd,
              ),
      ),
    );
  }
}

class _RemovableThumb extends StatelessWidget {
  const _RemovableThumb({
    required this.asset,
    required this.semanticLabel,
    required this.onRemove,
  });

  final AssetDto asset;
  final String semanticLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return SizedBox(
      width: PdlMetrics.thumbMd + PdlSpacing.chipGap,
      height: PdlMetrics.thumbMd + PdlSpacing.chipGap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(left: 0, bottom: 0, child: _Thumb(asset: asset)),
          Positioned(
            right: -PdlSpacing.cardTight,
            top: -PdlSpacing.cardTight,
            child: Semantics(
              button: true,
              label: semanticLabel,
              child: InkResponse(
                onTap: onRemove,
                radius: PdlMetrics.tapTarget / 2,
                child: SizedBox(
                  width: PdlMetrics.tapTarget,
                  height: PdlMetrics.tapTarget,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(PdlIcons.close, size: 16, color: c.text),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
