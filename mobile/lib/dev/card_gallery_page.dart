// Galerie des cartes de l'app — page de DEBUG (ledger `MOB-139`).
//
// Elle rend les **vraies cartes** de production avec les données fixes du
// cahier commun à l'app et au site
// (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/galerie.md`),
// pour les capturer et les comparer. Aucun appel réseau : chaque cas a son
// conteneur Riverpod, Dio coupé, session de Camille Durand
// (`card_gallery/gallery_scope.dart`).
//
// Comme la galerie des composants, elle n'existe qu'en debug : ses routes
// (`dev_routes.dart`) ne sont déclarées que sous `kDebugMode`, et le
// compilateur retire tout le dossier `dev/` d'une version livrée.
//
// - `/dev/cartes` : le sommaire ;
// - `/dev/cartes/<section>` : une section (`fil`, `accueil`, `agenda`,
//   `groupes`, `etapes`, `parcours`, `annonces`, `equipes`, `tableau`,
//   `divers`).
//
// Pour l'ouvrir au lancement :
// `flutter run --dart-define=DEV_ROUTE=/dev/cartes/fil`.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/pdl/pdl.dart';
import '../core/theme/pdl_colors.dart';
import '../core/theme/pdl_tokens.dart';
import '../core/theme/pdl_typography.dart';
import '../core/theme/pedalons_theme.dart';
import '../core/utils/formatters.dart';
import 'card_gallery/gallery_data.dart';
import 'card_gallery/gallery_images.dart';
import 'card_gallery/gallery_sections.dart';

/// L'adresse du sommaire ; une section est à `'$kCardGalleryPath/<id>'`.
const String kCardGalleryPath = '/dev/cartes';

/// La galerie : le sommaire sans [sectionId], une section sinon.
class CardGalleryPage extends StatefulWidget {
  const CardGalleryPage({
    super.key,
    this.sectionId,
    this.images = true,
    this.prepareImages = prepareGalleryImages,
    this.now,
  });

  final String? sectionId;

  /// Faux dans les tests : les cartes restent sans image, et rien n'est
  /// dessiné ni déposé dans le cache.
  final bool images;

  /// Prépare les images avant d'afficher les cartes, si [images]. Par défaut,
  /// les dépose dans le cache disque de `CachedNetworkImage` ; le test de
  /// capture, qui n'a pas ce cache, les pose lui-même en mémoire.
  final Future<void> Function() prepareImages;

  /// Le jour J ; maintenant par défaut.
  final DateTime? now;

  @override
  State<CardGalleryPage> createState() => _CardGalleryPageState();
}

class _CardGalleryPageState extends State<CardGalleryPage> {
  Brightness _brightness = Brightness.light;
  late final Future<void> _imagesReady = widget.images
      ? widget.prepareImages()
      : Future<void>.value();

  @override
  void initState() {
    super.initState();
    // La lectrice lit en français, à l'heure de Paris (cahier, § Règles).
    AppFormatters.setDisplayTimezone(kGalleryZone);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || EasyLocalization.of(context) == null) return;
      if (context.locale.languageCode != 'fr') {
        context.setLocale(const Locale('fr'));
      }
    });
  }

  void _open(String? sectionId) {
    final String location = sectionId == null
        ? kCardGalleryPath
        : '$kCardGalleryPath/$sectionId';
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(location);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardGalleryPage(
          sectionId: sectionId,
          images: widget.images,
          prepareImages: widget.prepareImages,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GallerySection? section = gallerySection(widget.sectionId);
    return Theme(
      data: PedalonsTheme.build(_brightness),
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: context.pdl.bg,
          appBar: AppBar(
            title: Text(
              section == null
                  ? 'Galerie des cartes'
                  : 'Cartes · ${section.title}',
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  0,
                  PdlSpacing.section,
                  9,
                ),
                child: PdlSegmented<Brightness>(
                  segments: const <PdlSegment<Brightness>>[
                    PdlSegment<Brightness>(
                      value: Brightness.light,
                      label: 'Clair',
                    ),
                    PdlSegment<Brightness>(
                      value: Brightness.dark,
                      label: 'Sombre',
                    ),
                  ],
                  value: _brightness,
                  onChanged: (Brightness b) => setState(() => _brightness = b),
                ),
              ),
            ),
          ),
          body: FutureBuilder<void>(
            future: _imagesReady,
            builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              return section == null
                  ? _Contents(unknown: widget.sectionId, onOpen: _open)
                  : _SectionBody(
                      section: section,
                      data: GalleryData(now: widget.now, images: widget.images),
                      onOpen: _open,
                    );
            },
          ),
        ),
      ),
    );
  }
}

/// Le sommaire : une ligne par section, avec ses cas.
class _Contents extends StatelessWidget {
  const _Contents({required this.unknown, required this.onOpen});

  final String? unknown;
  final ValueChanged<String?> onOpen;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return ListView(
      padding: const EdgeInsets.all(PdlSpacing.section),
      children: <Widget>[
        if (unknown != null) ...<Widget>[
          Text('Section inconnue : « $unknown ».', style: t.bodyStrong),
          const SizedBox(height: PdlSpacing.section),
        ],
        for (final GallerySection s in kGallerySections) ...<Widget>[
          PdlCard(
            key: ValueKey<String>('gallery-section-${s.id}'),
            onTap: () => onOpen(s.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.title, style: t.cardTitle),
                const SizedBox(height: 2),
                Text('$kCardGalleryPath/${s.id}', style: t.xs),
                const SizedBox(height: PdlSpacing.badgeGap),
                Text(
                  <String>[
                    for (final GalleryCase c in s.cases) c.id,
                    for (final String id in s.omitted.keys) '($id, omis)',
                  ].join(' · '),
                  style: t.sub,
                ),
              ],
            ),
          ),
          const SizedBox(height: PdlSpacing.feedGap),
        ],
      ],
    );
  }
}

/// Une section : la rangée des autres sections, puis chaque cas sous sa
/// légende, dans l'ordre du cahier.
///
/// Une colonne et non une liste paresseuse : tous les cas sont construits,
/// ce qui laisse le test les trouver tous, et une capture défiler d'un bloc.
class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.data,
    required this.onOpen,
  });

  final GallerySection section;
  final GalleryData data;
  final ValueChanged<String?> onOpen;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return SingleChildScrollView(
      key: ValueKey<String>('gallery-scroll-${section.id}'),
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: PdlSpacing.section,
              vertical: PdlSpacing.chipGap,
            ),
            child: Row(
              children: <Widget>[
                PdlButton(
                  label: 'Sommaire',
                  variant: PdlButtonVariant.text,
                  size: PdlButtonSize.sm,
                  onPressed: () => onOpen(null),
                ),
                for (final GallerySection s in kGallerySections)
                  if (s.id != section.id)
                    PdlButton(
                      label: s.id,
                      variant: PdlButtonVariant.text,
                      size: PdlButtonSize.sm,
                      onPressed: () => onOpen(s.id),
                    ),
              ],
            ),
          ),
          for (final GalleryCase c in section.cases)
            _CaseView(
              key: ValueKey<String>('gallery-${c.id}'),
              item: c,
              data: data,
            ),
          for (final MapEntry<String, String> o in section.omitted.entries)
            Padding(
              key: ValueKey<String>('gallery-omitted-${o.key}'),
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                PdlSpacing.section,
                PdlSpacing.section,
                0,
              ),
              child: Text('${o.key} — omis : ${o.value}', style: t.xs),
            ),
        ],
      ),
    );
  }
}

/// Un cas : sa légende (l'identifiant du cahier), en petit, puis la carte.
class _CaseView extends StatelessWidget {
  const _CaseView({super.key, required this.item, required this.data});

  final GalleryCase item;
  final GalleryData data;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final EdgeInsets side = const EdgeInsets.symmetric(
      horizontal: PdlSpacing.section,
    );
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: side.copyWith(bottom: PdlSpacing.badgeGap),
            child: Text(
              item.id,
              style: context.pdlText.xs.copyWith(color: c.textDimmed),
            ),
          ),
          Padding(
            padding: item.bleed ? EdgeInsets.zero : side,
            child: item.build(data),
          ),
        ],
      ),
    );
  }
}
