// Galerie des listes de l'app — page de DEBUG.
//
// Elle monte **les vraies pages de liste** de production avec les données
// fixes du cahier commun à l'app et au site
// (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/galerie.md`),
// dans chacun de leurs états, pour les capturer et les comparer. Rien ne part
// sur le réseau : chaque cas a son conteneur Riverpod (celui de la galerie des
// cartes, `card_gallery/gallery_scope.dart`, session de Camille Durand), dont
// le Dio répond depuis le serveur factice du cas (`list_gallery/gallery_api.dart`).
// Les pages, leurs fournisseurs, leurs dépôts et leur pagination tournent
// tels quels.
//
// Comme les autres galeries, elle n'existe qu'en debug : ses routes
// (`dev_routes.dart`) ne sont déclarées que sous `kDebugMode`.
//
// - `/dev/listes` : le sommaire ;
// - `/dev/listes/<section>` : les cas d'une section ;
// - `/dev/listes/<section>/<cas>` : un cas, la page entière.
//
// Les cas dont l'état demande un geste (une feuille ouverte, une recherche
// tapée dans un champ tenu par l'écran) s'ouvrent ici sans ce geste ; le test
// de capture le joue (`test/dev/list_gallery_capture_test.dart`).
//
// **Une limite dans l'app** : une feuille (`PdlSheet.show`) s'ouvre sur le
// navigateur racine, donc hors du conteneur du cas, et lit les fournisseurs
// de l'app — sa session, son réseau. La feuille des personnes inscrites et
// celles des filtres ne sont donc fidèles que dans le test de capture, qui
// pose le conteneur du cas **au-dessus** de l'application
// (`ListGalleryPage.scoped` faux, `ListCaseScope`).
//
// Pour l'ouvrir au lancement :
// `flutter run --dart-define=DEV_ROUTE=/dev/listes/parcours/parcours-repos`.

import 'package:dio/dio.dart';
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
import 'card_gallery/gallery_scope.dart';
import 'list_gallery/gallery_api.dart';
import 'list_gallery/list_sections.dart';

/// L'adresse du sommaire.
const String kListGalleryPath = '/dev/listes';

/// La hauteur de la légende posée au-dessus d'un cas.
const double kListCaptionHeight = 22;

/// La galerie : le sommaire, une section, ou un cas.
class ListGalleryPage extends StatefulWidget {
  const ListGalleryPage({
    super.key,
    this.sectionId,
    this.caseId,
    this.images = true,
    this.prepareImages = prepareGalleryImages,
    this.now,
    this.onApi,
    this.scoped = true,
  });

  final String? sectionId;
  final String? caseId;

  /// Faux dans les tests : les vignettes restent vides.
  final bool images;

  /// Prépare les images avant d'afficher un cas, si [images] (voir la
  /// galerie des cartes).
  final Future<void> Function() prepareImages;

  /// Le jour J ; maintenant par défaut.
  final DateTime? now;

  /// Reçoit le serveur factice du cas : les tests relisent ses requêtes.
  final ValueChanged<GalleryApi>? onApi;

  /// Faux quand le conteneur du cas est déjà posé au-dessus de l'application
  /// ([ListCaseScope]) : le cas n'en ouvre pas un second.
  final bool scoped;

  @override
  State<ListGalleryPage> createState() => _ListGalleryPageState();
}

class _ListGalleryPageState extends State<ListGalleryPage> {
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

  void _open(String location) {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(location);
      return;
    }
    final List<String> parts = location
        .substring(kListGalleryPath.length)
        .split('/')
        .where((String p) => p.isNotEmpty)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListGalleryPage(
          sectionId: parts.isEmpty ? null : parts[0],
          caseId: parts.length < 2 ? null : parts[1],
          images: widget.images,
          prepareImages: widget.prepareImages,
          now: widget.now,
        ),
      ),
    );
  }

  Widget _caseView(ListCase item) {
    final GalleryData data = GalleryData(
      now: widget.now,
      images: widget.images,
    );
    final Widget view = ListCaseView(
      key: ValueKey<String>('list-gallery-${item.id}'),
      item: item,
      data: data,
    );
    if (!widget.scoped) return view;
    return ListCaseScope(
      item: item,
      data: data,
      onApi: widget.onApi,
      child: view,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ListSection? section = listSection(widget.sectionId);
    final ListCase? item = listCase(widget.sectionId, widget.caseId);
    return Theme(
      data: PedalonsTheme.build(Brightness.light),
      child: Builder(
        builder: (BuildContext context) {
          if (item != null) {
            return FutureBuilder<void>(
              future: _imagesReady,
              builder: (BuildContext context, AsyncSnapshot<void> snapshot) =>
                  snapshot.connectionState != ConnectionState.done
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator.adaptive()),
                    )
                  : _caseView(item),
            );
          }
          return Scaffold(
            backgroundColor: context.pdl.bg,
            appBar: AppBar(
              title: Text(
                section == null
                    ? 'Galerie des listes'
                    : 'Listes · ${section.title}',
              ),
            ),
            body: _Contents(
              section: section,
              unknown: section == null ? widget.sectionId : widget.caseId,
              onOpen: _open,
            ),
          );
        },
      ),
    );
  }
}

/// Le sommaire (toutes les sections) ou les cas d'une [section].
class _Contents extends StatelessWidget {
  const _Contents({
    required this.section,
    required this.unknown,
    required this.onOpen,
  });

  final ListSection? section;
  final String? unknown;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final ListSection? s = section;
    return ListView(
      padding: const EdgeInsets.all(PdlSpacing.section),
      children: <Widget>[
        if (unknown != null) ...<Widget>[
          Text('Inconnu : « $unknown ».', style: t.bodyStrong),
          const SizedBox(height: PdlSpacing.section),
        ],
        if (s == null)
          for (final ListSection each in kListSections) ...<Widget>[
            PdlCard(
              key: ValueKey<String>('list-gallery-section-${each.id}'),
              onTap: () => onOpen('$kListGalleryPath/${each.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(each.title, style: t.cardTitle),
                  const SizedBox(height: 2),
                  Text('$kListGalleryPath/${each.id}', style: t.xs),
                  const SizedBox(height: PdlSpacing.badgeGap),
                  Text(
                    <String>[
                      for (final ListCase c in each.cases) c.id,
                      for (final String id in each.omitted.keys) '($id, omis)',
                    ].join(' · '),
                    style: t.sub,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PdlSpacing.feedGap),
          ]
        else ...<Widget>[
          for (final ListCase c in s.cases)
            PdlSettingRow(
              key: ValueKey<String>('list-gallery-open-${c.id}'),
              title: c.id,
              subtitle: c.steps.isEmpty
                  ? null
                  : 'Geste joué par le test de capture : ${c.steps.length}',
              onTap: () => onOpen('$kListGalleryPath/${s.id}/${c.id}'),
            ),
          for (final MapEntry<String, String> o in s.omitted.entries)
            Padding(
              key: ValueKey<String>('list-gallery-omitted-${o.key}'),
              padding: const EdgeInsets.only(top: PdlSpacing.section),
              child: Text('${o.key} — omis : ${o.value}', style: t.xs),
            ),
        ],
      ],
    );
  }
}

/// Le conteneur d'un cas : celui de la galerie des cartes ([GalleryScope],
/// session de Camille Durand), dont le Dio répond depuis le serveur factice
/// du cas, avec l'état initial du cas par-dessus.
class ListCaseScope extends StatefulWidget {
  const ListCaseScope({
    super.key,
    required this.item,
    required this.data,
    required this.child,
    this.onApi,
  });

  final ListCase item;
  final GalleryData data;
  final Widget child;

  /// Reçoit le serveur factice : les tests relisent ses requêtes.
  final ValueChanged<GalleryApi>? onApi;

  @override
  State<ListCaseScope> createState() => _ListCaseScopeState();
}

class _ListCaseScopeState extends State<ListCaseScope> {
  late final GalleryApi _api = GalleryApi(widget.item.api(widget.data));
  late final Dio _dio = _api.dio();

  @override
  void initState() {
    super.initState();
    widget.onApi?.call(_api);
  }

  @override
  Widget build(BuildContext context) => GalleryScope(
    data: widget.data,
    dio: _dio,
    overrides: widget.item.overrides(widget.data),
    child: widget.child,
  );
}

/// Un cas : sa légende (l'identifiant du cahier), en petit, puis la page de
/// production. Le conteneur du cas ([ListCaseScope]) est au-dessus.
class ListCaseView extends StatelessWidget {
  const ListCaseView({super.key, required this.item, required this.data});

  final ListCase item;
  final GalleryData data;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final MediaQueryData media = MediaQuery.of(context);
    return Material(
      color: c.surface,
      child: Column(
        children: <Widget>[
          // La légende occupe la place de la barre d'état ; la page dessous
          // ne la compte plus.
          Padding(
            padding: EdgeInsets.only(top: media.padding.top),
            child: SizedBox(
              height: kListCaptionHeight,
              width: double.infinity,
              child: Center(
                child: Text(
                  item.id,
                  style: context.pdlText.xs.copyWith(color: c.textDimmed),
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Builder(builder: (BuildContext _) => item.page(data)),
            ),
          ),
        ],
      ),
    );
  }
}
