import 'dart:convert';

import 'package:dio/dio.dart' show DioException;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/app_config.dart';
import '../../../../config/locale_context.dart';
import '../../../../config/paths.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/geo/location_service.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../rides/presentation/widgets/editor/editor_media_actions.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_media_section.dart';
import '../../../rides/presentation/widgets/editor/slug_edit_sheet.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../visibility/domain/content_visibility.dart';
import '../../../visibility/domain/incompatible_visibility.dart';
import '../../../visibility/presentation/visibility_field.dart';
import '../../../visibility/presentation/visibility_refusal.dart';
import '../../data/gpx_file_source.dart';
import '../../data/planner_bridge.dart';
import '../../data/planner_load.dart';
import '../../domain/route_generator.dart';
import '../../data/planner_web_view.dart';
import '../../../gpxtools/data/gpx_files_picker.dart';
import '../../data/route_repository.dart';
import '../../domain/gpx_check.dart';
import '../../domain/planner_quota.dart';
import '../../domain/planner_result.dart';
import '../../domain/route_form.dart';
import '../../providers/route_changes.dart';
import '../../providers/route_detail_provider.dart';
import '../../providers/route_editor_providers.dart';
import '../widgets/editor/gpx_pick_step.dart';
import '../widgets/editor/planner_quota_message.dart';
import '../widgets/editor/route_track_section.dart';
import 'route_planner_screen.dart';

/// Créer ([routeSlug] nul) ou modifier un parcours — le pendant mobile de
/// `CreateRoutePage` / `EditRoutePage` du site (docs/LEDGER_*.md MOB-79). Le
/// tracé vient d'un fichier GPX ou, là où l'équipe a le planificateur
/// (`enableRoutePlanner`), du **planificateur du site embarqué** dans une
/// WebView plein écran (`RoutePlannerScreen`, ledger `MOB-170`) : rien du
/// planificateur n'est réécrit en Dart, et ce qui part du tracé est le
/// fragment que la page a calculé (`RouteForm.toRequest`).
///
/// Ouvert aux organisateurs et administrateurs de l'équipe (et à l'admin de
/// plateforme), module parcours actif : la règle de `RouteAccessChecker`.
/// Quelqu'un d'autre arrivé ici par un lien lit un refus plutôt qu'un
/// formulaire qui finirait en 403.
///
/// [pickGpx] fait ouvrir le sélecteur de fichier dès que l'écran s'affiche —
/// « Remplacer le fichier GPX » du menu de la fiche en modification,
/// « Importer un GPX » du bouton « Créer » de la liste à la création ;
/// rien ne part sans « Enregistrer ».
class RouteEditorPage extends ConsumerStatefulWidget {
  const RouteEditorPage({
    super.key,
    required this.teamSlug,
    this.routeSlug,
    this.pickGpx = false,
    this.draw = false,
    this.generated,
  });

  final String teamSlug;
  final String? routeSlug;
  final bool pickGpx;

  /// À la création, « Tracer sur la carte » : le planificateur s'ouvre dès que
  /// l'écran s'affiche, sans passer par la page de choix.
  final bool draw;

  /// Une proposition du générateur ou d'une retouche : le planificateur
  /// s'ouvre aussitôt dessus. À la création (docs/LEDGER_*.md MOB-154), le
  /// nom et le revêtement viennent d'elle ; en modification d'un parcours à
  /// une trace (« Modifier » d'une retouche, MOB-185), elle remplace la trace
  /// et rien d'autre ne change.
  final GeneratedHandoff? generated;

  @override
  ConsumerState<RouteEditorPage> createState() => _RouteEditorPageState();
}

class _RouteEditorPageState extends ConsumerState<RouteEditorPage> {
  String get teamSlug => widget.teamSlug;
  String? get routeSlug => widget.routeSlug;
  bool get pickGpx => widget.pickGpx;
  bool get _isEdit => routeSlug != null;

  @override
  void initState() {
    super.initState();
    // L'équipe déjà en cache (ouverte depuis sa page) porte le quota du
    // planificateur de ce moment-là : il a pu être libéré depuis (changement
    // de mois, déblocage par l'admin de plateforme). Elle est relue à chaque
    // ouverture de l'éditeur, sans écran d'attente — la valeur en cache reste
    // affichée pendant la relecture (docs/LEDGER_*.md MOB-176).
    //
    // Après la première image, jamais dans initState : la page est montée
    // pendant un build, et invalider là marque le ProviderScope à
    // reconstruire en plein build — l'assertion de Flutter casse l'éditeur
    // en mode debug (vu par les tests Patrol route_editor et route_planner).
    if (ref.read(teamDetailProvider(teamSlug).exists)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(teamDetailProvider(teamSlug));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = _isEdit
        ? 'routes.editor.editTitle'.tr()
        : 'routes.editor.createTitle'.tr();

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    Widget loadError(Object error, VoidCallback retry) => shell(
      PdlEmptyState(
        key: keys.routeEditor.loadError,
        variant: PdlEmptyVariant.error,
        title: 'common.loadError'.tr(),
        message: getErrorMessage(error),
        actions: <Widget>[
          PdlButton(label: 'common.retry'.tr(), onPressed: retry),
        ],
      ),
    );

    // 1. L'équipe et le droit — rien d'autre n'est lu avant.
    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    // Une relecture de l'équipe qui échoue (le quota relu après un refus ou un
    // enregistrement, ledger `MOB-170`) ne remplace pas un formulaire ouvert
    // par un écran d'erreur : l'équipe déjà lue reste.
    final Object? teamError = team.hasValue ? null : team.error;
    if (teamError != null) {
      return loadError(
        teamError,
        () => ref.invalidate(teamDetailProvider(teamSlug)),
      );
    }
    final bool? canManage = ref.watch(canManageRoutesProvider(teamSlug));
    final TeamDetailDto? teamValue = team.value;
    if (teamValue == null || canManage == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }

    Widget forbidden() => shell(
      PdlEmptyState(
        key: keys.routeEditor.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'routes.editor.forbiddenTitle'.tr(),
        message: teamValue.enableRoutes
            ? 'routes.editor.forbiddenMessage'.tr()
            : 'routes.editor.modulesOffMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );

    // 2. Le refus est tranché **avant** de lire le parcours : un simple
    // membre qui l'écouterait lirait le 403 du serveur (parcours d'équipe
    // privé) au lieu de l'écran de refus. La création n'a pas d'entité : la
    // règle de rôle est la seule (aucun champ calculé ne la porte).
    if (!canManage || !teamValue.enableRoutes) return forbidden();

    // 3. Le parcours à modifier.
    final String? slug = routeSlug;
    RouteDetailDto? route;
    if (slug != null) {
      final RouteKey key = RouteKey(teamSlug: teamSlug, routeSlug: slug);
      final AsyncValue<RouteDetailDto> detail = ref.watch(
        routeDetailProvider(key),
      );
      final Object? routeError = detail.error;
      if (routeError != null) {
        return loadError(
          routeError,
          () => ref.invalidate(routeDetailProvider(key)),
        );
      }
      route = detail.value;
      if (route == null) {
        return shell(const Center(child: CircularProgressIndicator.adaptive()));
      }
      // Puis le droit que le backend calcule pour **ce** parcours
      // (docs/LEDGER_*.md MOB-137) : c'est lui qui tranche.
      if (!route.permissions.canEdit) return forbidden();
    }

    return _RouteEditorForm(
      // Un parcours rechargé sous l'écran (slug changé, autre appareil) ne
      // réécrit pas un formulaire en cours : la clé ne suit que son id.
      key: ValueKey<String>(route?.id ?? 'new-$teamSlug'),
      team: teamValue,
      route: route,
      pickGpx: pickGpx,
      draw: widget.draw && route == null,
      generated: route == null || isSingleTrack(route)
          ? widget.generated
          : null,
      title: title,
    );
  }
}

class _RouteEditorForm extends ConsumerStatefulWidget {
  const _RouteEditorForm({
    super.key,
    required this.team,
    required this.route,
    required this.pickGpx,
    required this.draw,
    required this.title,
    this.generated,
  });

  final TeamDetailDto team;
  final RouteDetailDto? route;
  final bool pickGpx;
  final bool draw;
  final GeneratedHandoff? generated;
  final String title;

  @override
  ConsumerState<_RouteEditorForm> createState() => _RouteEditorFormState();
}

class _RouteEditorFormState extends ConsumerState<_RouteEditorForm>
    with EditorMediaActions<_RouteEditorForm> {
  late RouteForm _form;
  late final String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _markdown;

  /// Pour faire remonter l'écran jusqu'à la section Tracé quand le serveur
  /// refuse le fichier : le bouton « Enregistrer » est loin dessous.
  final GlobalKey _trackKey = GlobalKey();

  /// Le fichier GPX choisi : requis à la création, remplaçant à la
  /// modification.
  GpxFile? _gpx;

  /// Le dernier fichier refusé, localement ou par le serveur.
  GpxRefused? _refused;

  // ── Planificateur embarqué (docs/LEDGER_*.md MOB-170) ───────────────────

  /// Le pont et sa page. Créé à la première ouverture du planificateur, il
  /// **vit jusqu'à la fin du formulaire** : l'écran plein s'y rattache à
  /// chaque ouverture, et `load` n'est envoyé qu'une fois.
  PlannerBridge? _planner;

  /// Le dernier « Terminer » : ce qui partira du tracé, et son aperçu. Un
  /// fichier choisi ensuite dans le formulaire ([_gpx]) passe devant.
  PlannerResult? _drawn;

  /// Le nom pris du GPX : tant que le champ le porte tel quel, une aide le
  /// dit, et un autre fichier peut le remplacer.
  String? _suggestedName;

  bool _reading = false;
  bool _uploading = false;
  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  RouteDetailDto? get _route => widget.route;
  String get _teamSlug => widget.team.slug;

  /// L'app revenue au premier plan relit l'équipe : un quota libéré pendant
  /// qu'elle dormait rouvre « Tracer sur la carte » (docs/LEDGER_*.md MOB-176).
  late final AppLifecycleListener _resumeListener = AppLifecycleListener(
    onResume: () {
      if (mounted) ref.invalidate(teamDetailProvider(_teamSlug));
    },
  );

  @override
  void initState() {
    super.initState();
    _resumeListener;
    final RouteDetailDto? route = _route;
    final RouteForm initial = route == null
        ? RouteForm.initial(widget.team)
        : RouteForm.fromRoute(route, planner: widget.team.enableRoutePlanner);
    // Une proposition du générateur garde l'état de départ d'une création
    // vide : la quitter demande confirmation.
    _initialJson = _json(initial);
    final GeneratedHandoff? generated = widget.generated;
    _form = generated == null || route != null
        ? initial
        : initial.copyWith(
            name: generated.name,
            surfaceType: surfaceTypeOfGenerated(generated.type),
          );
    _name = TextEditingController(text: _form.name)
      ..addListener(() => _update(_form.copyWith(name: _name.text)));
    _markdown = TextEditingController(text: _form.media.markdown)
      ..addListener(
        () => _update(
          _form.copyWith(media: _form.media.copyWith(markdown: _markdown.text)),
        ),
      );
    if (generated != null && widget.team.enableRoutePlanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPlanner();
      });
    }
    // « Tracer sur la carte » : le planificateur tout de suite, sauf quota du
    // mois épuisé — la page de choix dit alors pourquoi.
    if (widget.draw &&
        generated == null &&
        widget.team.enableRoutePlanner &&
        !isPlannerQuotaSpent(
          widget.team.plannerQuota,
          platformAdmin:
              ref.read(authProvider).user?.platformRole == 'PLATFORM_ADMIN',
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPlanner();
      });
    }
    if (widget.pickGpx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // À la création, « Importer des GPX » : plusieurs fichiers permis.
        if (mounted) _pickGpx(many: route == null);
      });
    }
  }

  @override
  void dispose() {
    _resumeListener.dispose();
    _planner?.dispose();
    _name.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(RouteForm form) => jsonEncode(form.toRequest().toJson());

  /// Un tracé dessiné compte, même quitté sans « Terminer » : il vit encore
  /// dans la page, et partir du formulaire le perdrait.
  bool get _dirty =>
      !_saved &&
      (_gpx != null ||
          _drawn != null ||
          (_planner?.dirty.value ?? false) ||
          _json(_form) != _initialJson);

  /// Ce que l'enregistrement prendra du planificateur : rien quand un fichier
  /// choisi dans le formulaire passe devant.
  PlannerResult? get _plannerSource => _gpx == null ? _drawn : null;

  bool get _plannerBusy => _planner?.busy.value ?? false;

  void _update(RouteForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  // ── Médias ─────────────────────────────────────────────────────────────
  //
  // Les gestes sont ceux de [EditorMediaActions] ; l'écran dit où vivent le
  // formulaire et le texte.

  @override
  String get mediaTeamSlug => _teamSlug;

  @override
  MediaDto get editedMedia => _form.media;

  @override
  void applyMedia(MediaDto media) => _update(_form.copyWith(media: media));

  @override
  TextEditingController get markdownController => _markdown;

  @override
  void setMediaUploading(bool uploading) => setState(() {
    _uploading = uploading;
    if (uploading) _error = null;
  });

  @override
  void showMediaError(String message) => setState(() => _error = message);

  // ── Fichier GPX ────────────────────────────────────────────────────────

  /// Choisit un fichier, le contrôle localement (extension, début du
  /// contenu), puis l'adopte ou le refuse. Un refus laisse en place le
  /// fichier précédent, s'il y en avait un.
  ///
  /// [many] (« Importer des GPX », à la création) permet d'en choisir
  /// plusieurs : un seul suit ce chemin, plusieurs deviennent chacun un
  /// parcours ([_importAll]), comme au site.
  Future<void> _pickGpx({bool many = false}) async {
    if (_reading || _saving) return;
    final GpxFile? picked;
    try {
      if (many) {
        final List<GpxFile> files = await ref
            .read(gpxFilesPickerProvider)
            .pickMany();
        if (files.length > 1) {
          if (mounted) await _importAll(files);
          return;
        }
        picked = files.isEmpty ? null : files.single;
      } else {
        picked = await ref.read(gpxFilePickerProvider).pick();
      }
    } on PlatformException catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
      return;
    }
    if (picked == null || !mounted) return;

    setState(() {
      _reading = true;
      _error = null;
    });
    final GpxCheck check;
    try {
      check = await inspectGpxFile(picked);
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _reading = false;
          _error = getErrorMessage(error, stackTrace);
        });
      }
      return;
    }
    if (!mounted) return;

    switch (check) {
      case final GpxRefused refused:
        setState(() {
          _reading = false;
          _refused = refused;
        });
      case final GpxAccepted accepted:
        // Le nom du fichier ne remplace qu'un nom vide ou celui qu'il avait
        // proposé : jamais ce que l'organisateur a tapé.
        final String typed = _name.text;
        if (_route == null &&
            (typed.trim().isEmpty || typed == _suggestedName)) {
          final String suggestion = suggestedRouteName(accepted);
          _suggestedName = suggestion;
          _name.text = suggestion;
        }
        setState(() {
          _reading = false;
          _gpx = accepted.file;
          _refused = null;
        });
    }
  }

  /// Plusieurs GPX : un parcours par fichier, nommé d'après lui, avec la
  /// visibilité par défaut de l'équipe et le revêtement « route » — l'import
  /// du site (`useGpxUpload`). Un fichier refusé n'arrête pas les autres ; le
  /// bilan dit lesquels, puis l'éditeur se ferme sur la liste relue.
  Future<void> _importAll(List<GpxFile> files) async {
    setState(() {
      _reading = true;
      _error = null;
      _refused = null;
    });
    final RouteRepository repo = ref.read(routeRepositoryProvider);
    final List<String> refused = <String>[];
    int imported = 0;
    for (final GpxFile file in files) {
      try {
        final GpxCheck check = await inspectGpxFile(file);
        if (check is! GpxAccepted) {
          refused.add(file.name);
          continue;
        }
        await repo.createRoute(
          _teamSlug,
          RouteForm.initial(widget.team)
              .copyWith(name: suggestedRouteName(check))
              .toRequest(),
          gpx: check.file,
        );
        imported++;
      } catch (_) {
        refused.add(file.name);
      }
    }
    if (!mounted) return;
    if (imported > 0) notifyRouteChanged(ref, teamSlug: _teamSlug);
    final String message = refused.isEmpty
        ? 'routes.create.imported'.plural(imported)
        : 'routes.create.importedWithRefused'.plural(
            imported,
            namedArgs: <String, String>{'names': refused.join(', ')},
          );
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
    if (imported == 0) {
      setState(() => _reading = false);
      return;
    }
    _saved = true;
    Navigator.of(context).pop();
  }

  // ── Planificateur ──────────────────────────────────────────────────────

  void _onPlannerChanged() {
    if (mounted) setState(() {});
  }

  PlannerBridge _createPlanner() {
    final RouteDetailDto? route = _route;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String routeName = _name.text;
    final PlannerBridge bridge = PlannerBridge(
      dio: ref.read(dioProvider),
      picker: () => ref.read(gpxFilePickerProvider),
      location: ref.read(locationServiceProvider),
      webViewFactory: ref.read(plannerWebViewFactoryProvider),
      load: () async => buildPlannerLoad(
        team: widget.team,
        route: route == null ? null : plannerTrackOfRoute(route),
        routeName: routeName,
        config: await ref.read(appConfigProvider.future),
        // Les documents de style sont publics : le client sans session.
        dio: ref.read(baseDioProvider),
        apiBaseUrl: AppConfig.apiBaseUrl,
        readState: () => ref
            .read(routeRepositoryProvider)
            .getPlannerState(_teamSlug, route!.slug),
        dark: dark,
        locale: getCurrentLocale(),
        units: ref.read(unitSystemProvider),
        generated: widget.generated,
      ),
      onDone: _onPlannerDone,
      onQuotaRefused: _onQuotaRefused,
    );
    for (final Listenable state in <Listenable>[
      bridge.busy,
      bridge.dirty,
      bridge.unvalidated,
      bridge.stateReadFailed,
    ]) {
      state.addListener(_onPlannerChanged);
    }
    return bridge;
  }

  /// « Tracer sur la carte », « Modifier le tracé » : l'écran plein, sur la
  /// page gardée en vie.
  Future<void> _openPlanner() async {
    if (_saving || _reading) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    await openRoutePlanner(context, _planner ??= _createPlanner());
  }

  /// « Terminer » dans le planificateur.
  void _onPlannerDone(PlannerResult result) {
    if (!mounted) return;
    // Le nom du fichier importé ne remplit qu'un nom vide.
    final String? suggestion = result.nameSuggestion;
    if (suggestion != null && _name.text.trim().isEmpty) {
      final String name = suggestion.length > kRouteNameMaxLength
          ? suggestion.substring(0, kRouteNameMaxLength)
          : suggestion;
      _suggestedName = name;
      _name.text = name;
    }
    setState(() {
      _drawn = result.isEmpty ? null : result;
      // Le tracé dessiné devient la source : le fichier choisi avant, non.
      if (result.hasTrack) {
        _gpx = null;
        _refused = null;
      }
    });
  }

  /// Un refus de quota — d'un calcul dans la page, ou de l'enregistrement :
  /// sa feuille, et l'équipe relue pour que le bouton d'entrée le sache.
  Future<void> _onQuotaRefused(PlannerQuotaRefusal refusal) async {
    if (!mounted) return;
    ref.invalidate(teamDetailProvider(_teamSlug));
    await showPlannerQuotaSheet(context, refusal);
  }

  /// « Garder le tracé actuel » : renonce au fichier choisi.
  void _cancelReplace() => setState(() {
    _gpx = null;
    _refused = null;
  });

  // ── Tags ───────────────────────────────────────────────────────────────

  Future<void> _editTags(List<TagWithUsageDto> vocabulary) async {
    final List<String>? picked = await showTagPickerSheet(
      context,
      vocabulary: vocabulary,
      selected: _form.tagIds,
      title: 'routes.editor.tagsPickerTitle'.tr(),
      hint: 'routes.editor.tagsPickerHint'.tr(),
      maxSelected: kRouteMaxTags,
    );
    if (picked == null) return;
    _update(_form.copyWith(tagIds: picked));
  }

  String _tagLabels(List<TagWithUsageDto> vocabulary) {
    final Map<String, String> labels = <String, String>{
      for (final TagWithUsageDto t in vocabulary) t.id: t.label,
    };
    return _form.tagIds
        .map((String id) => labels[id])
        .whereType<String>()
        .join(', ');
  }

  // ── Adresse (slug) ─────────────────────────────────────────────────────

  Future<void> _editSlug() async {
    final RouteDetailDto route = _route!;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    final String? slug = await showSlugEditSheet(
      context,
      route.slug,
      fieldKey: keys.routeEditor.slugField,
      saveKey: keys.routeEditor.slugSave,
    );
    if (slug == null || slug == route.slug || !mounted) return;
    try {
      final RouteDetailDto updated = await ref
          .read(routeRepositoryProvider)
          .changeSlug(_teamSlug, route.slug, slug);
      if (!mounted) return;
      notifyRouteChanged(
        ref,
        teamSlug: _teamSlug,
        routeKey: RouteKey(teamSlug: _teamSlug, routeSlug: route.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // L'ancienne adresse ne mène plus nulle part : la pile repart de la
      // nouvelle, fiche dessous.
      context.go(Paths.routeEdit(_teamSlug, updated.slug));
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    }
  }

  // ── Enregistrer ────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() => confirmDestructive(
    context,
    title: 'rides.editor.discardTitle'.tr(),
    message: 'rides.editor.discardMessage'.tr(),
    confirmLabel: 'rides.editor.discardConfirm'.tr(),
  );

  Future<void> _save() async {
    // Un calcul en vol dans le planificateur n'est pas encore dans son
    // résultat : enregistrer maintenant le laisserait tomber.
    if (_saving || _uploading || _reading || _plannerBusy) return;
    final RouteDetailDto? route = _route;
    final PlannerResult? drawn = _plannerSource;
    // Le fichier choisi dans le formulaire, ou celui que le planificateur a
    // importé et laissé intact (`file: true`) : le pont l'a gardé.
    final GpxFile? gpx =
        _gpx ?? (drawn != null && drawn.file ? _planner?.fileFor(drawn) : null);
    // La création part d'un fichier ou d'un tracé d'au moins deux points (le
    // formulaire n'est pas affiché avant) ; et un résultat `file` sans son
    // fichier n'a rien à envoyer.
    final bool noTrack =
        route == null && gpx == null && !(drawn?.hasTrack ?? false);
    final bool fileLost = (drawn?.file ?? false) && gpx == null;
    if (noTrack || fileLost) {
      setState(() => _error = 'routes.editor.pointsRequired'.tr());
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_form.isValid) {
      setState(() {
        _showErrors = true;
        _error = 'routes.editor.invalid'.tr();
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _refused = null;
    });
    final RouteRepository routes = ref.read(routeRepositoryProvider);
    final RouteRequest request = _form.toRequest(planner: drawn);
    try {
      final RouteDto saved = route == null
          ? await routes.createRoute(_teamSlug, request, gpx: gpx)
          : await routes.updateRoute(_teamSlug, route.slug, request, gpx: gpx);
      if (!mounted) return;
      // Un tracé dessiné a compté dans le quota de l'équipe : elle est relue
      // après chaque enregistrement, comme au site.
      ref.invalidate(teamDetailProvider(_teamSlug));
      notifyRouteChanged(
        ref,
        teamSlug: _teamSlug,
        routeKey: RouteKey(teamSlug: _teamSlug, routeSlug: saved.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            // L'avertissement du site, une fois l'enregistrement réussi
            // seulement : « Tracé enregistré sans ses points de contrôle… »
            // dit aussi que c'est enregistré.
            (drawn?.tooLarge ?? false)
                ? 'routes.planner.stateTooLarge'.tr()
                : route == null
                ? 'routes.editor.created'.tr()
                : 'routes.editor.saved'.tr(),
          ),
        ),
      );
      final GoRouter router = GoRouter.of(context);
      if (route == null) {
        // La création laisse place à la fiche du parcours créé.
        router.pushReplacement(Paths.route(_teamSlug, saved.slug));
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.route(_teamSlug, saved.slug));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      // Un refus du fichier par le serveur (illisible, vide, trop long, trop
      // gros) se lit dans la section Tracé, formulaire conservé ; tout autre
      // échec est une erreur de l'écran.
      // Décision D6 : un parcours qui sert publiquement ne passe pas en
      // « Équipe ». Le refus liste ses usages dans une feuille, formulaire
      // conservé — pas le message générique en plus.
      final IncompatibleVisibility? incompatible = incompatibleVisibilityOf(
        error,
      );
      if (incompatible != null && incompatible.usages.isNotEmpty) {
        setState(() => _saving = false);
        await showRouteInUseRefusal(
          context,
          teamSlug: _teamSlug,
          usages: incompatible.usages,
        );
        return;
      }
      // Le quota s'est épuisé entre-temps (docs/LEDGER_*.md BILL-10) : rien
      // n'est enregistré ni perdu, le tracé reste dans le formulaire — pour
      // un import de GPX, ou pour le mois prochain.
      final PlannerQuotaRefusal? quota = plannerQuotaRefusalOf(error);
      if (quota != null) {
        setState(() => _saving = false);
        await _onQuotaRefused(quota);
        return;
      }
      final GpxRefusal? refusal = _refusalOf(error, stackTrace);
      setState(() {
        _saving = false;
        if (refusal != null && gpx != null) {
          _refused = GpxRefused(gpx.name, refusal);
          // Le fichier venait du planificateur : son résultat part avec lui
          // (le tracé, lui, est toujours dans la page).
          if (drawn?.file ?? false) _drawn = null;
          // Le fichier refusé est oublié : un nouvel appui sur Créer ou
          // Enregistrer ne le renverrait que pour un second refus. En
          // modification on revient au tracé actuel, en création à l'étape 1
          // (le reste du formulaire est gardé). Le refus local fait
          // l'inverse, exprès : il garde le fichier précédent, accepté.
          _gpx = null;
        } else {
          _error = getErrorMessage(error, stackTrace);
        }
      });
      if (refusal != null && gpx != null) _revealTrack();
    }
  }

  static GpxRefusal? _refusalOf(Object error, StackTrace stackTrace) {
    final GpxRefusal? byCode = gpxRefusalOfApiCode(
      resolveApiError(error, stackTrace).code,
    );
    if (byCode != null) return byCode;
    // Un proxy qui coupe un envoi trop gros répond 413 sans corps lisible.
    if (error is DioException && error.response?.statusCode == 413) {
      return GpxRefusal.tooLarge;
    }
    return null;
  }

  void _revealTrack() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _trackKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, duration: PdlMotion.stateChange);
    });
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  static IconData _surfaceIcon(SurfaceType s) => switch (s) {
    SurfaceType.road => PdlIcons.surfaceRoad,
    SurfaceType.gravel => PdlIcons.surfaceGravel,
    SurfaceType.mtb => PdlIcons.surfaceMtb,
    SurfaceType.mixed || SurfaceType.$unknown => PdlIcons.surfaceMixed,
  };

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final RouteDetailDto? route = _route;
    final bool creating = route == null;
    // La création commence par le tracé — un fichier, ou un dessin d'au moins
    // deux points : pas de formulaire avant.
    final bool picking =
        creating && _gpx == null && !(_drawn?.hasTrack ?? false);
    final bool busy = _saving || _uploading || _reading;

    // Le planificateur : ouvert à l'équipe par l'admin de plateforme, pour un
    // parcours neuf ou à une seule trace. Quota du mois épuisé : l'entrée
    // reste en vue, désactivée, avec sa raison — mais un planificateur déjà
    // ouvert n'est pas repris (le tracé y vit, son refus s'y lit).
    final TeamDetailDto team = widget.team;
    final bool plannerOpen =
        team.enableRoutePlanner && (route == null || isSingleTrack(route));
    final PlannerQuotaDto? quota = team.plannerQuota;
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    final PlannerQuotaRefusal? quotaSpent =
        plannerOpen &&
            _planner == null &&
            isPlannerQuotaSpent(quota, platformAdmin: platformAdmin)
        ? PlannerQuotaRefusal(
            team: true,
            limit: quota!.limit!,
            resetsOn: quota.resetsOn,
            teamName: team.name,
          )
        : null;
    final VoidCallback? onDraw = plannerOpen ? _openPlanner : null;

    final List<TagWithUsageDto> vocabulary =
        ref
            .watch(
              teamTagsProvider((teamSlug: _teamSlug, type: TagTarget.route)),
            )
            .value ??
        const <TagWithUsageDto>[];

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _saved = true;
          navigator.pop();
        }
      },
      child: PdlScreenScaffold(
        appBar: PdlAppBar(
          title: widget.title,
          onBack: () => Navigator.of(context).maybePop(),
          backSemanticLabel: 'common.back'.tr(),
        ),
        actionBar: picking
            ? null
            : PdlActionBar(
                children: <Widget>[
                  PdlButton(
                    key: keys.routeEditor.saveButton,
                    label: creating
                        ? 'routes.editor.create'.tr()
                        : 'routes.editor.save'.tr(),
                    loading: _saving,
                    loadingLabel: 'routes.editor.saving'.tr(),
                    enabled: !_uploading && !_reading && !_plannerBusy,
                    onPressed: _save,
                  ),
                ],
              ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section * 2,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  PdlBanner(
                    key: keys.routeEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],
                if (picking)
                  GpxPickStep(
                    onPick: () => _pickGpx(many: true),
                    busy: _reading,
                    refused: _refused,
                    onDraw: onDraw,
                    // Le générateur à la place de cette page vide : sa
                    // proposition rouvre un éditeur par-dessus lui.
                    onGenerate: onDraw == null
                        ? null
                        : () => context.pushReplacement(
                            Paths.routeGenerate(_teamSlug),
                          ),
                    quotaSpent: quotaSpent,
                  )
                else ...<Widget>[
                  // ── Tracé ──
                  KeyedSubtree(
                    key: _trackKey,
                    child: RouteTrackSection(
                      current: route == null
                          ? null
                          : currentTrackOfRoute(route),
                      picked: _gpx,
                      refused: _refused,
                      busy: busy,
                      onPick: _pickGpx,
                      onCancelReplace: route == null || _gpx == null
                          ? null
                          : _cancelReplace,
                      onDraw: onDraw,
                      quotaSpent: quotaSpent,
                      drawn: _drawn,
                      unvalidated: _planner?.unvalidated.value ?? false,
                      plannerWarning: (_planner?.stateReadFailed.value ?? false)
                          ? 'routes.planner.stateReadFailed'.tr()
                          : null,
                    ),
                  ),

                  // ── Nom et adresse ──
                  TextField(
                    key: keys.routeEditor.nameField,
                    controller: _name,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(kRouteNameMaxLength),
                    ],
                    style: t.bodyStrong,
                    decoration: InputDecoration(
                      labelText: 'routes.editor.name'.tr(),
                      hintText: 'routes.editor.namePlaceholder'.tr(),
                      helper:
                          _suggestedName != null && _name.text == _suggestedName
                          ? Text(
                              'routes.editor.nameFromGpx'.tr(),
                              key: keys.routeEditor.nameFromGpxHint,
                            )
                          : null,
                      errorText: _showErrors && !_form.nameValid
                          ? 'routes.editor.nameError'.tr()
                          : null,
                    ),
                  ),
                  if (route != null)
                    PdlSettingRow(
                      key: keys.routeEditor.slugRow,
                      padding: EdgeInsets.zero,
                      icon: PdlIcons.link,
                      title: 'rides.editor.slug'.tr(),
                      subtitle: route.slug,
                      onTap: busy ? null : _editSlug,
                    ),
                  const SizedBox(height: PdlSpacing.section),

                  // ── Surface et visibilité ──
                  EditorSection(
                    title: 'routes.editor.surface'.tr(),
                    child: PdlSegmented<SurfaceType>(
                      key: keys.routeEditor.surface,
                      value: _form.surfaceType,
                      onChanged: (SurfaceType s) =>
                          _update(_form.copyWith(surfaceType: s)),
                      segments: <PdlSegment<SurfaceType>>[
                        for (final SurfaceType s in SurfaceType.$valuesDefined)
                          PdlSegment<SurfaceType>(
                            key: keys.routeEditor.surfaceOption(s),
                            value: s,
                            label: 'routes.surfaceType.${s.json!.toLowerCase()}'
                                .tr(),
                            icon: _surfaceIcon(s),
                          ),
                      ],
                    ),
                  ),
                  // ── Générateur de parcours ── Là où le planificateur est
                  // ouvert seulement, comme au site.
                  if (_form.excludedFromGenerator case final bool excluded)
                    PdlSettingRow(
                      padding: EdgeInsets.zero,
                      title: 'routes.editor.excludedFromGenerator'.tr(),
                      subtitle: 'routes.editor.excludedFromGeneratorHint'.tr(),
                      trailing: PdlSwitch(
                        key: keys.routeEditor.excludedFromGenerator,
                        value: excluded,
                        semanticLabel: 'routes.editor.excludedFromGenerator'
                            .tr(),
                        onChanged: busy
                            ? null
                            : (bool on) => _update(
                                _form.copyWith(excludedFromGenerator: on),
                              ),
                      ),
                    ),
                  // Les valeurs que le backend permet à ce parcours : moins
                  // « Équipe » s'il sert publiquement, et parfois aucune
                  // (docs/LEDGER_*.md MOB-137).
                  VisibilityField(
                    title: 'routes.editor.visibility'.tr(),
                    selectorKey: keys.routeEditor.visibility,
                    allowed: allowedVisibilitiesFor(
                      widget.team,
                      VisibilityKind.route,
                      permissions: route?.permissions,
                    ),
                    value: _form.visibility,
                    onChanged: (Visibility v) =>
                        _update(_form.copyWith(visibility: v)),
                    teamPrivate: isPrivateTeam(widget.team),
                    enabled: !busy,
                  ),

                  // ── Tags ── Rien à proposer sans vocabulaire, sauf à
                  // garder des tags déjà posés.
                  if (vocabulary.isNotEmpty || _form.tagIds.isNotEmpty)
                    EditorSection(
                      title: 'routes.editor.tags'.tr(),
                      child: PdlSettingRow(
                        key: keys.routeEditor.tagsRow,
                        padding: EdgeInsets.zero,
                        icon: PdlIcons.tag,
                        title: _form.tagIds.isEmpty
                            ? 'routes.editor.tagsNone'.tr()
                            : _tagLabels(vocabulary),
                        onTap: busy || vocabulary.isEmpty
                            ? null
                            : () => _editTags(vocabulary),
                      ),
                    ),

                  // ── Description et médias ──
                  EditorSection(
                    title: 'routes.editor.description'.tr(),
                    child: RichMarkdownEditorField(
                      title: 'routes.editor.description'.tr(),
                      fieldKey: keys.routeEditor.markdownField,
                      controller: _markdown,
                      hintText: 'routes.editor.markdownPlaceholder'.tr(),
                      images: _form.media.assets.images,
                      enabled: !_saving,
                      imageBusy: _uploading,
                      onInsertImage: addImage,
                      errorText: _form.markdownValid
                          ? null
                          : 'rides.editor.markdownTooLong'.tr(),
                    ),
                  ),
                  EditorSection(
                    title: 'routes.editor.media'.tr(),
                    child: RideMediaSection(
                      assets: _form.media.assets,
                      busy: _saving || _uploading,
                      onPickLogo: pickLogo,
                      onRemoveLogo: removeLogo,
                      onAddImage: addImageFromSection,
                      onRemoveImage: removeImage,
                      onAddAttachment: addAttachments,
                      onRemoveAttachment: removeAttachment,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
