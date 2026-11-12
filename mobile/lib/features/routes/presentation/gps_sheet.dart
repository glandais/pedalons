import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/theme/pdl_typography.dart';
import '../../../core/utils/share_file.dart';
import '../../../keys.dart';

/// Ce que la personne a choisi dans la feuille GPS ([showGpsSheet]).
///
/// La feuille ne fait rien elle-même : elle rend le choix, et c'est le
/// `GpsExportRunner` de l'écran appelant qui télécharge, envoie ou navigue —
/// une fois la feuille refermée, pour que l'attente et son bandeau se lisent
/// sur l'écran, pas sous une feuille.
sealed class GpsChoice {
  const GpsChoice();
}

/// Envoyer le parcours à un service connecté (Garmin, Wahoo, Karoo…).
final class GpsSendToService extends GpsChoice {
  const GpsSendToService(this.service);

  final GpsServiceConnectionDto service;
}

/// Remettre le fichier [asset] (GPX ou FIT) à [destination].
final class GpsDeliverFile extends GpsChoice {
  const GpsDeliverFile(this.asset, this.destination);

  final AssetDto asset;
  final AssetDestination destination;
}

/// « Connecter un compteur » : ouvrir l'écran des appareils du profil.
final class GpsConnectDevice extends GpsChoice {
  const GpsConnectDevice();
}

/// Le bouton GPS a-t-il quelque chose à proposer ?
///
/// Un fichier (GPX ou FIT), ou un parcours à envoyer et un service où
/// l'envoyer. Sans rien de tout cela — un parcours sans trace —, pas de
/// bouton : une feuille qui n'offrirait que « Connecter un compteur » mènerait
/// à un envoi qui n'aurait rien à envoyer.
bool gpsExportOffered({
  required AssetDto? gpx,
  required AssetDto? fit,
  required bool canSend,
}) => gpx != null || fit != null || canSend;

/// La feuille « GPS » : le seul chemin par lequel un parcours sort de l'app
/// (KIT §8, « Export du parcours »).
///
/// [subtitle] nomme ce qui part — « Groupe B · 78,0 km », le nom du parcours.
/// Dans l'ordre :
///
/// * « Vers un appareil », une ligne par service de [services] ;
/// * « Fichier GPX » puis « Fichier FIT, pour compteur », chacun seulement si
///   le fichier existe — sur **Android** « Enregistrer sur le téléphone » et
///   « Envoyer vers une autre app », sur **iOS** une ligne « Partager », dont
///   la feuille propose déjà « Enregistrer dans Fichiers » (même règle que
///   `pickAssetDestination`) ;
/// * « Connecter un compteur » tout en bas quand [offerConnect] — aucun
///   service n'est connecté —, à la place de la section appareil.
///
/// `null` si la personne referme la feuille.
Future<GpsChoice?> showGpsSheet(
  BuildContext context, {
  required String subtitle,
  required List<GpsServiceConnectionDto> services,
  required bool offerConnect,
  AssetDto? gpx,
  AssetDto? fit,
}) {
  return PdlSheet.show<GpsChoice>(
    context: context,
    builder: (BuildContext sheetContext) => GpsSheet(
      subtitle: subtitle,
      services: services,
      offerConnect: offerConnect,
      gpx: gpx,
      fit: fit,
      onChoice: (GpsChoice choice) => Navigator.of(sheetContext).pop(choice),
    ),
  );
}

/// Le corps de la feuille GPS, posé par [showGpsSheet].
class GpsSheet extends StatelessWidget {
  const GpsSheet({
    super.key,
    required this.subtitle,
    required this.services,
    required this.offerConnect,
    required this.onChoice,
    this.gpx,
    this.fit,
  });

  final String subtitle;
  final List<GpsServiceConnectionDto> services;
  final bool offerConnect;
  final AssetDto? gpx;
  final AssetDto? fit;
  final ValueChanged<GpsChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool android = defaultTargetPlatform == TargetPlatform.android;

    return PdlSheet(
      key: keys.gpsSheet.sheet,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('routes.gpsSheet.title'.tr(), style: t.sectionTitle),
          if (subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle,
              key: keys.gpsSheet.subtitle,
              style: t.sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      children: <Widget>[
        if (services.isNotEmpty) ...<Widget>[
          _SectionLabel(
            key: keys.gpsSheet.toDevice,
            label: 'routes.gpsSheet.toDevice'.tr(),
          ),
          for (final (int i, GpsServiceConnectionDto s) in services.indexed)
            _row(
              key: keys.gpsSheet.service(s.serviceType),
              title: s.displayName,
              icon: PdlIcons.device,
              divider: i < services.length - 1,
              choice: GpsSendToService(s),
            ),
        ],
        if (gpx != null)
          ..._fileSection(
            label: 'routes.gpsSheet.gpxFile'.tr(),
            asset: gpx!,
            android: android,
            saveKey: keys.gpsSheet.gpxSave,
            shareKey: keys.gpsSheet.gpxShare,
          ),
        if (fit != null)
          ..._fileSection(
            label: 'routes.gpsSheet.fitFile'.tr(),
            asset: fit!,
            android: android,
            saveKey: keys.gpsSheet.fitSave,
            shareKey: keys.gpsSheet.fitShare,
          ),
        if (offerConnect)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.chipGap,
              PdlSpacing.section,
              0,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.borderSubtle)),
              ),
              child: PdlSettingRow(
                key: keys.gpsSheet.connectDevice,
                title: 'routes.gpsSheet.connectDevice'.tr(),
                subtitle: 'routes.gpsSheet.connectDeviceHint'.tr(),
                leading: Icon(PdlIcons.add, size: 20, color: c.primary),
                onTap: () => onChoice(const GpsConnectDevice()),
              ),
            ),
          ),
      ],
    );
  }

  /// Le libellé d'une section de fichier, puis ses lignes : deux sur Android,
  /// une seule « Partager » ailleurs.
  List<Widget> _fileSection({
    required String label,
    required AssetDto asset,
    required bool android,
    required Key saveKey,
    required Key shareKey,
  }) => <Widget>[
    _SectionLabel(label: label),
    if (android) ...<Widget>[
      _row(
        key: saveKey,
        title: 'media.saveToDevice'.tr(),
        icon: PdlIcons.download,
        divider: true,
        choice: GpsDeliverFile(asset, AssetDestination.device),
      ),
      _row(
        key: shareKey,
        title: 'media.shareFile'.tr(),
        icon: PdlIcons.share,
        choice: GpsDeliverFile(asset, AssetDestination.share),
      ),
    ] else
      _row(
        key: shareKey,
        title: 'routes.share'.tr(),
        icon: PdlIcons.share,
        choice: GpsDeliverFile(asset, AssetDestination.share),
      ),
  ];

  /// Une ligne d'action, sans chevron : elle agit, elle ne mène nulle part.
  Widget _row({
    required Key key,
    required String title,
    required IconData icon,
    required GpsChoice choice,
    bool divider = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
    child: PdlSettingRow(
      key: key,
      title: title,
      icon: icon,
      showDivider: divider,
      trailing: const SizedBox.shrink(),
      onTap: () => onChoice(choice),
    ),
  );
}

/// « Vers un appareil », « Fichier GPX »… : aligné sur les icônes des lignes.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section * 2,
        PdlSpacing.sectionTightV,
        PdlSpacing.section * 2,
        PdlSpacing.badgeGap,
      ),
      child: Semantics(
        header: true,
        child: Text(label, style: context.pdlText.count),
      ),
    );
  }
}
