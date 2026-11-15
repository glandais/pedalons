import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../rides/presentation/widgets/editor/editor_media_actions.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_media_section.dart';
import '../../../rides/presentation/widgets/editor/slug_edit_sheet.dart';
import '../../../visibility/domain/content_visibility.dart';
import '../../../visibility/presentation/visibility_field.dart';
import '../../domain/team_page_form.dart';
import '../../providers/team_access_probe.dart';
import '../../providers/team_pages_provider.dart';
import '../../providers/team_permission_providers.dart';
import '../../providers/team_providers.dart';
import 'team_custom_page.dart' show teamPageProvider;

/// Créer ([pageSlug] nul) ou modifier une page personnalisée de l'équipe — le
/// pendant mobile de `CreateTeamPagePage` / `EditTeamPagePage` du site
/// (docs/LEDGER_*.md MOB-169) : titre, adresse, texte markdown, logo, images
/// et pièces jointes, visibilité.
///
/// **Réservé à l'administration de l'équipe** (et à l'admin de plateforme).
/// Le refus est tranché **avant** de lire la page ; modifier exige ensuite le
/// droit que le backend calcule pour cette page (`permissions.canEdit`,
/// ledger `MOB-137`).
class TeamPageEditorPage extends ConsumerWidget {
  const TeamPageEditorPage({super.key, required this.teamSlug, this.pageSlug});

  final String teamSlug;
  final String? pageSlug;

  bool get _isEdit => pageSlug != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _isEdit
        ? 'teams.pages.editor.editTitle'.tr()
        : 'teams.pages.editor.createTitle'.tr();

    // Le retour mène à la liste des pages ; [teamReadable] faux — l'équipe
    // elle-même s'est refusée —, à « Mes équipes ».
    void back({bool teamReadable = true}) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          teamReadable ? Paths.teamAdminPages(teamSlug) : Paths.teams(),
        );
      }
    }

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: back,
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    Widget loadError(Object error, VoidCallback retry) => shell(
      PdlEmptyState(
        key: keys.teamPageEditor.loadError,
        variant: PdlEmptyVariant.error,
        title: 'common.loadError'.tr(),
        message: getErrorMessage(error),
        actions: <Widget>[
          PdlButton(label: 'common.retry'.tr(), onPressed: retry),
        ],
      ),
    );

    Widget forbidden({required bool teamReadable}) => shell(
      PdlEmptyState(
        key: keys.teamPageEditor.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'teams.pages.forbiddenTitle'.tr(),
        message: 'teams.pages.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamPageEditor.forbiddenBack,
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => back(teamReadable: teamReadable),
          ),
        ],
      ),
    );

    // 1. L'équipe et le droit — rien d'autre n'est lu avant.
    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final TeamDetailDto? teamValue = team.value;
    final Object? teamError = team.error;
    // Une fiche déjà lue reste le formulaire en cours : une relecture en
    // échec ne le remplace pas par une erreur.
    if (teamValue == null && teamError != null) {
      // Une équipe que le serveur refuse (403, ou 404 pour une équipe privée
      // dont on n'est pas membre) : un refus, pas une panne à réessayer.
      if (isTeamAccessRefusal(teamError)) return forbidden(teamReadable: false);
      return loadError(
        teamError,
        () => ref.invalidate(teamDetailProvider(teamSlug)),
      );
    }
    // `null` tant que la fiche charge : ni formulaire, ni refus.
    final bool? admin = ref.watch(isTeamAdminProvider(teamSlug));
    if (teamValue == null || admin == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }

    // 2. Le refus est tranché **avant** de lire la page : quelqu'un qui
    // n'administre pas l'équipe ne déclenche aucune requête de page.
    if (!admin) return forbidden(teamReadable: true);

    // 3. La page à modifier.
    final String? slug = pageSlug;
    TeamPageDto? page;
    if (slug != null) {
      final ({String teamSlug, String pageSlug}) key = (
        teamSlug: teamSlug,
        pageSlug: slug,
      );
      final AsyncValue<TeamPageDto> detail = ref.watch(teamPageProvider(key));
      page = detail.value;
      if (page == null) {
        final Object? pageError = detail.error;
        if (pageError != null) {
          return loadError(
            pageError,
            () => ref.invalidate(teamPageProvider(key)),
          );
        }
        return shell(const Center(child: CircularProgressIndicator.adaptive()));
      }
      // Puis le droit que le backend calcule pour **cette** page
      // (docs/LEDGER_*.md MOB-137) : c'est lui qui tranche.
      if (!page.permissions.canEdit) return forbidden(teamReadable: true);
    }

    return _TeamPageEditorForm(
      // Une page rechargée sous l'écran ne réécrit pas un formulaire en
      // cours : la clé ne suit que son id.
      key: ValueKey<String>(page?.id ?? 'new-$teamSlug'),
      team: teamValue,
      page: page,
      title: title,
    );
  }
}

class _TeamPageEditorForm extends ConsumerStatefulWidget {
  const _TeamPageEditorForm({
    super.key,
    required this.team,
    required this.page,
    required this.title,
  });

  final TeamDetailDto team;
  final TeamPageDto? page;
  final String title;

  @override
  ConsumerState<_TeamPageEditorForm> createState() =>
      _TeamPageEditorFormState();
}

class _TeamPageEditorFormState extends ConsumerState<_TeamPageEditorForm>
    with EditorMediaActions<_TeamPageEditorForm> {
  late TeamPageForm _form;
  late final String _initialJson;

  late final TextEditingController _title;
  late final TextEditingController _markdown;

  bool _uploading = false;
  bool _saving = false;
  bool _saved = false;

  /// Le changement d'adresse est en cours : réussi, il mène à la nouvelle
  /// adresse et jetterait ce qui serait saisi entre-temps.
  bool _renaming = false;

  /// La feuille d'adresse (ou sa confirmation d'abandon) est ouverte : un
  /// second appui n'en ouvre pas une seconde.
  bool _slugSheetOpen = false;
  bool _showErrors = false;
  String? _error;

  TeamPageDto? get _page => widget.page;
  String get _teamSlug => widget.team.slug;

  /// La saisie est figée : une écriture part, ou l'adresse change.
  bool get _frozen => _saving || _renaming;

  /// Aucun autre geste ne part : en plus, un envoi de fichier est en cours.
  bool get _busy => _frozen || _uploading;

  @override
  void initState() {
    super.initState();
    final TeamPageDto? page = _page;
    final TeamPageForm initial = page == null
        ? TeamPageForm.initial(widget.team)
        : TeamPageForm.fromPage(page);
    _form = initial;
    _initialJson = _json(initial);
    _title = TextEditingController(text: _form.title)
      ..addListener(() => _update(_form.copyWith(title: _title.text)));
    _markdown = TextEditingController(text: _form.media.markdown)
      ..addListener(
        () => _update(
          _form.copyWith(media: _form.media.copyWith(markdown: _markdown.text)),
        ),
      );
  }

  @override
  void dispose() {
    _title.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(TeamPageForm form) =>
      jsonEncode(form.toRequest().toJson());

  bool get _dirty => !_saved && _json(_form) != _initialJson;

  void _update(TeamPageForm next) {
    if (identical(next, _form)) return;
    setState(() => _form = next);
  }

  // ── Médias ─────────────────────────────────────────────────────────────
  //
  // Les gestes sont ceux de [EditorMediaActions] ; l'écran dit où vivent le
  // formulaire et le texte. Les envois partent contre l'équipe.

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

  // ── Adresse (slug) ─────────────────────────────────────────────────────

  Future<void> _editSlug() async {
    final TeamPageDto page = _page!;
    if (_busy || _slugSheetOpen) return;
    _slugSheetOpen = true;
    final String? slug;
    try {
      if (_dirty && !await _confirmDiscard()) return;
      if (!mounted) return;
      slug = await showSlugEditSheet(
        context,
        page.slug,
        fieldKey: keys.teamPageEditor.slugField,
        saveKey: keys.teamPageEditor.slugSave,
      );
    } finally {
      _slugSheetOpen = false;
    }
    if (slug == null || slug == page.slug || !mounted) return;
    // Une feuille a rendu la main : un autre geste a pu partir.
    if (_busy) return;
    setState(() {
      _renaming = true;
      _error = null;
    });
    final TeamPagesClient client = ref.read(teamPagesClientProvider);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      final TeamPageDto updated = await client.changePageSlug(
        teamSlug: _teamSlug,
        pageSlug: page.slug,
        body: SlugChangeRequest(slug: slug),
      );
      // L'ancienne adresse et la nouvelle : les deux contenus sont à relire.
      notifyTeamPagesChanged(
        container,
        _teamSlug,
        pageSlugs: <String>[page.slug, updated.slug],
      );
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // La pile repart de la nouvelle adresse : équipe, hub, pages, éditeur.
      context.go(Paths.teamAdminPageEdit(_teamSlug, updated.slug));
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _renaming = false);
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
    if (_busy) return;
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
    });
    final TeamPagesClient client = ref.read(teamPagesClientProvider);
    // Pris avant l'`await` : l'écran peut être quitté avant la réponse.
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final TeamPageRequest request = _form.toRequest();
    final TeamPageDto? page = _page;
    try {
      final TeamPageDto saved = page == null
          ? await client.createPage(teamSlug: _teamSlug, body: request)
          : await client.updatePage(
              teamSlug: _teamSlug,
              pageSlug: page.slug,
              body: request,
            );
      notifyTeamPagesChanged(
        container,
        _teamSlug,
        pageSlugs: <String>[saved.slug],
      );
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            page == null
                ? 'teams.pages.editor.created'.tr()
                : 'teams.pages.editor.saved'.tr(),
          ),
        ),
      );
      // Retour à la liste des pages, comme au site.
      final GoRouter router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.teamAdminPages(_teamSlug));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final TeamPageDto? page = _page;
    final bool creating = page == null;
    final bool teamPrivate = isPrivateTeam(widget.team);
    // Les valeurs que le backend permet à cette page — celles de l'équipe à
    // la création (docs/LEDGER_*.md MOB-137) : jamais déduites de
    // `team.visibility` ni du rôle.
    final List<Visibility> allowed = allowedVisibilitiesFor(
      widget.team,
      VisibilityKind.teamPage,
      permissions: page?.permissions,
    );

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
        actionBar: PdlActionBar(
          children: <Widget>[
            PdlButton(
              key: keys.teamPageEditor.saveButton,
              label: creating
                  ? 'teams.pages.editor.create'.tr()
                  : 'routes.editor.save'.tr(),
              loading: _saving,
              loadingLabel: 'routes.editor.saving'.tr(),
              enabled: !_uploading && !_renaming,
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
                    key: keys.teamPageEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Titre et adresse ── Pas de coupe à la saisie : un titre
                // trop long se dit sur le champ.
                TextField(
                  key: keys.teamPageEditor.titleField,
                  controller: _title,
                  enabled: !_frozen,
                  textCapitalization: TextCapitalization.sentences,
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'teams.pages.editor.title'.tr(),
                    hintText: 'teams.pages.editor.titlePlaceholder'.tr(),
                    helperText: 'teams.pages.editor.titleHint'.tr(),
                    helperMaxLines: 2,
                    errorText: _showErrors && !_form.titleValid
                        ? 'teams.pages.editor.titleError'.tr(
                            namedArgs: <String, String>{
                              'max': '$kTeamPageTitleMaxLength',
                            },
                          )
                        : null,
                  ),
                ),
                if (page != null)
                  PdlSettingRow(
                    key: keys.teamPageEditor.slugRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.link,
                    title: 'rides.editor.slug'.tr(),
                    subtitle: page.slug,
                    trailing: _renaming
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : null,
                    onTap: _busy ? null : _editSlug,
                  ),
                const SizedBox(height: PdlSpacing.section),

                // ── Texte et médias ── Pas de compteur de caractères
                // (décision D3 du plan).
                EditorSection(
                  title: 'teams.pages.editor.content'.tr(),
                  child: RichMarkdownEditorField(
                    fieldKey: keys.teamPageEditor.markdownField,
                    controller: _markdown,
                    title: 'teams.pages.editor.content'.tr(),
                    hintText: 'teams.pages.editor.contentPlaceholder'.tr(),
                    images: _form.media.assets.images,
                    enabled: !_frozen,
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
                    busy: _busy,
                    onPickLogo: pickLogo,
                    onRemoveLogo: removeLogo,
                    onAddImage: addImageFromSection,
                    onRemoveImage: removeImage,
                    onAddAttachment: addAttachments,
                    onRemoveAttachment: removeAttachment,
                  ),
                ),

                // ── Visibilité ── Une seule valeur permise, celle de la
                // page : le champ ne rend rien.
                VisibilityField(
                  title: 'routes.editor.visibility'.tr(),
                  selectorKey: keys.teamPageEditor.visibility,
                  allowed: allowed,
                  value: _form.visibility,
                  onChanged: (Visibility v) =>
                      _update(_form.copyWith(visibility: v)),
                  teamPrivate: teamPrivate,
                  enabled: !_busy,
                ),
                // En équipe privée, l'aide du champ dit déjà ce que vaut
                // « Public » : celle-ci la contredirait.
                if (!teamPrivate &&
                    allowed.isNotEmpty &&
                    VisibilityField.shows(allowed, _form.visibility))
                  Text(
                    'teams.pages.editor.visibilityHint'.tr(),
                    key: keys.teamPageEditor.visibilityHint,
                    style: t.xs.copyWith(color: c.textDimmed),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
