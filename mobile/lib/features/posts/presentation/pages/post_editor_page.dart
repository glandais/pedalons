import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../rides/domain/ride_form.dart' show parseWallTime, wallTimeOf;
import '../../../rides/presentation/widgets/editor/editor_media_actions.dart';
import '../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../rides/presentation/widgets/editor/markdown_editor_field.dart';
import '../../../rides/presentation/widgets/editor/ride_group_editor.dart'
    show EditorClearButton;
import '../../../rides/presentation/widgets/editor/ride_media_section.dart';
import '../../../rides/presentation/widgets/editor/slug_edit_sheet.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../visibility/domain/content_visibility.dart';
import '../../../visibility/presentation/visibility_field.dart';
import '../../data/post_repository.dart';
import '../../domain/post_form.dart';
import '../../providers/post_providers.dart';

/// Créer ([postSlug] nul) ou modifier une publication — le pendant mobile de
/// `CreatePostPage` / `EditPostPage` du site (docs/LEDGER_*.md MOB-156) :
/// titre, texte markdown, photos et pièces jointes, tags, visibilité,
/// signature, statut et dates.
///
/// Ouvert aux organisateurs et administrateurs de l'équipe (et à l'admin de
/// plateforme), module publications actif. Quelqu'un d'autre arrivé ici par
/// un lien lit un refus plutôt qu'un formulaire qui finirait en 403.
class PostEditorPage extends ConsumerWidget {
  const PostEditorPage({super.key, required this.teamSlug, this.postSlug});

  final String teamSlug;
  final String? postSlug;

  bool get _isEdit => postSlug != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _isEdit
        ? 'posts.editor.editTitle'.tr()
        : 'posts.editor.createTitle'.tr();

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
        key: keys.postEditor.loadError,
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
    final Object? teamError = team.error;
    if (teamError != null) {
      return loadError(
        teamError,
        () => ref.invalidate(teamDetailProvider(teamSlug)),
      );
    }
    final bool? canManage = ref.watch(canManagePostsProvider(teamSlug));
    final TeamDetailDto? teamValue = team.value;
    if (teamValue == null || canManage == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }

    Widget forbidden() => shell(
      PdlEmptyState(
        key: keys.postEditor.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'posts.editor.forbiddenTitle'.tr(),
        message: teamValue.enablePosts
            ? 'posts.editor.forbiddenMessage'.tr()
            : 'posts.editor.modulesOffMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );

    // 2. Le refus est tranché **avant** de lire la publication : un simple
    // membre lirait sinon le 403 ou le 404 d'un brouillon au lieu du refus.
    if (!canManage || !teamValue.enablePosts) return forbidden();

    // 3. La publication à modifier.
    final String? slug = postSlug;
    PostDto? post;
    if (slug != null) {
      final PostKey key = (teamSlug: teamSlug, postSlug: slug);
      final AsyncValue<PostDto> detail = ref.watch(postDetailProvider(key));
      final Object? postError = detail.error;
      if (postError != null) {
        return loadError(
          postError,
          () => ref.invalidate(postDetailProvider(key)),
        );
      }
      post = detail.value;
      if (post == null) {
        return shell(const Center(child: CircularProgressIndicator.adaptive()));
      }
      // Puis le droit que le backend calcule pour **cette** publication
      // (docs/LEDGER_*.md MOB-137) : c'est lui qui tranche.
      if (!post.permissions.canEdit) return forbidden();
    }

    return _PostEditorForm(
      // Une publication rechargée sous l'écran ne réécrit pas un formulaire
      // en cours : la clé ne suit que son id.
      key: ValueKey<String>(post?.id ?? 'new-$teamSlug'),
      team: teamValue,
      post: post,
      title: title,
    );
  }
}

class _PostEditorForm extends ConsumerStatefulWidget {
  const _PostEditorForm({
    super.key,
    required this.team,
    required this.post,
    required this.title,
  });

  final TeamDetailDto team;
  final PostDto? post;
  final String title;

  @override
  ConsumerState<_PostEditorForm> createState() => _PostEditorFormState();
}

class _PostEditorFormState extends ConsumerState<_PostEditorForm>
    with EditorMediaActions<_PostEditorForm> {
  late PostForm _form;
  late final String _initialJson;

  late final TextEditingController _name;
  late final TextEditingController _markdown;

  bool _uploading = false;
  bool _saving = false;
  bool _saved = false;
  bool _showErrors = false;
  String? _error;

  PostDto? get _post => widget.post;
  String get _teamSlug => widget.team.slug;

  /// Le fuseau des dates du formulaire : celui que l'API a donné à la
  /// publication, celui de l'équipe à la création (ledger `API-60`).
  String get _zone => _post?.timezone ?? widget.team.timezone;

  @override
  void initState() {
    super.initState();
    final PostDto? post = _post;
    final PostForm initial = post == null
        ? PostForm.initial(widget.team)
        : PostForm.fromPost(post);
    _form = initial;
    _initialJson = _json(initial);
    _name = TextEditingController(text: _form.name)
      ..addListener(() => _update(_form.copyWith(name: _name.text)));
    _markdown = TextEditingController(text: _form.media.markdown)
      ..addListener(
        () => _update(
          _form.copyWith(media: _form.media.copyWith(markdown: _markdown.text)),
        ),
      );
  }

  @override
  void dispose() {
    _name.dispose();
    _markdown.dispose();
    super.dispose();
  }

  static String _json(PostForm form) => jsonEncode(form.toRequest().toJson());

  bool get _dirty => !_saved && _json(_form) != _initialJson;

  void _update(PostForm next) {
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

  // ── Dates ──────────────────────────────────────────────────────────────

  DateTime get _nowWall =>
      AppFormatters.toZoneTime(DateTime.now().toUtc(), _zone);

  DateTime get _wall => parseWallTime(_form.dateTime) ?? _nowWall;

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  Future<void> _editDate() async {
    final DateTime wall = _wall;
    final DateTime? day = await _pickDate(wall);
    if (day == null) return;
    _update(
      _form.copyWith(
        dateTime: wallTimeOf(
          DateTime(day.year, day.month, day.day, wall.hour, wall.minute),
        ),
      ),
    );
  }

  Future<void> _editTime() async {
    final DateTime wall = _wall;
    final TimeOfDay? time = await _pickTime(TimeOfDay.fromDateTime(wall));
    if (time == null) return;
    _update(
      _form.copyWith(
        dateTime: wallTimeOf(
          DateTime(wall.year, wall.month, wall.day, time.hour, time.minute),
        ),
      ),
    );
  }

  Future<void> _editPublishAt() async {
    final DateTime start =
        parseWallTime(_form.publishAt) ??
        _nowWall.add(const Duration(hours: 1));
    final DateTime? day = await _pickDate(start);
    if (day == null || !mounted) return;
    final TimeOfDay? time = await _pickTime(TimeOfDay.fromDateTime(start));
    if (time == null) return;
    _update(
      _form.copyWith(
        publishAt: () => wallTimeOf(
          DateTime(day.year, day.month, day.day, time.hour, time.minute),
        ),
      ),
    );
  }

  // ── Tags ───────────────────────────────────────────────────────────────

  Future<void> _editTags(List<TagWithUsageDto> vocabulary) async {
    final List<String>? picked = await showTagPickerSheet(
      context,
      vocabulary: vocabulary,
      selected: _form.tagIds,
      title: 'posts.editor.tagsPickerTitle'.tr(),
      hint: 'routes.editor.tagsPickerHint'.tr(),
      maxSelected: kPostMaxTags,
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
    final PostDto post = _post!;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    final String? slug = await showSlugEditSheet(
      context,
      post.slug,
      fieldKey: keys.postEditor.slugField,
      saveKey: keys.postEditor.slugSave,
    );
    if (slug == null || slug == post.slug || !mounted) return;
    try {
      final PostDto updated = await ref
          .read(postRepositoryProvider)
          .changeSlug(_teamSlug, post.slug, slug);
      if (!mounted) return;
      notifyPostChanged(
        ref,
        teamSlug: _teamSlug,
        postKey: (teamSlug: _teamSlug, postSlug: post.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('rides.editor.slugSaved'.tr())));
      // L'ancienne adresse ne mène plus nulle part : la pile repart de la
      // nouvelle, écran de la publication dessous.
      context.go(Paths.postEdit(_teamSlug, updated.slug));
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
    if (_saving || _uploading) return;
    FocusScope.of(context).unfocus();
    if (!_form.isValid(_zone)) {
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
    final PostRepository posts = ref.read(postRepositoryProvider);
    final PostRequest request = _form.toRequest();
    final PostDto? post = _post;
    try {
      final PostDto saved = post == null
          ? await posts.createPost(_teamSlug, request)
          : await posts.updatePost(_teamSlug, post.slug, request);
      if (!mounted) return;
      notifyPostChanged(
        ref,
        teamSlug: _teamSlug,
        postKey: (teamSlug: _teamSlug, postSlug: saved.slug),
      );
      _saved = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            post == null
                ? 'posts.editor.created'.tr()
                : 'posts.editor.saved'.tr(),
          ),
        ),
      );
      final GoRouter router = GoRouter.of(context);
      if (post == null) {
        // La création laisse place à l'écran de la publication créée.
        router.pushReplacement(Paths.post(_teamSlug, saved.slug));
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(Paths.post(_teamSlug, saved.slug));
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
    final PostDto? post = _post;
    final bool creating = post == null;
    final bool busy = _saving || _uploading;
    final String zone = _zone;
    final DateTime wall = _wall;
    final bool publishAtValid = _form.publishAtValid(zone);

    final List<TagWithUsageDto> vocabulary =
        ref
            .watch(
              teamTagsProvider((teamSlug: _teamSlug, type: TagTarget.post)),
            )
            .value ??
        const <TagWithUsageDto>[];

    // Brouillon ou publié, comme au site ; un statut déjà autre (annulé) reste
    // proposé pour que l'enregistrement ne le change pas à l'insu de l'auteur.
    final List<Status> statuses = <Status>[
      Status.draft,
      Status.published,
      if (_form.status != Status.draft && _form.status != Status.published)
        _form.status,
    ];

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
              key: keys.postEditor.saveButton,
              label: creating
                  ? 'posts.editor.create'.tr()
                  : 'routes.editor.save'.tr(),
              loading: _saving,
              loadingLabel: 'routes.editor.saving'.tr(),
              enabled: !_uploading,
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
                    key: keys.postEditor.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.section),
                ],

                // ── Titre et adresse ──
                TextField(
                  key: keys.postEditor.nameField,
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(kPostNameMaxLength),
                  ],
                  style: t.bodyStrong,
                  decoration: InputDecoration(
                    labelText: 'posts.editor.name'.tr(),
                    hintText: 'posts.editor.namePlaceholder'.tr(),
                    errorText: _showErrors && !_form.nameValid
                        ? 'posts.editor.nameError'.tr()
                        : null,
                  ),
                ),
                if (post != null)
                  PdlSettingRow(
                    key: keys.postEditor.slugRow,
                    padding: EdgeInsets.zero,
                    icon: PdlIcons.link,
                    title: 'rides.editor.slug'.tr(),
                    subtitle: post.slug,
                    onTap: busy ? null : _editSlug,
                  ),
                const SizedBox(height: PdlSpacing.section),

                // ── Texte et médias ── Le cœur d'une publication : avant
                // les réglages.
                EditorSection(
                  title: 'posts.editor.body'.tr(),
                  child: MarkdownEditorField(
                    fieldKey: keys.postEditor.markdownField,
                    controller: _markdown,
                    hintText: 'posts.editor.markdownPlaceholder'.tr(),
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
                    busy: busy,
                    onPickLogo: pickLogo,
                    onRemoveLogo: removeLogo,
                    onAddImage: addImageFromSection,
                    onRemoveImage: removeImage,
                    onAddAttachment: addAttachments,
                    onRemoveAttachment: removeAttachment,
                  ),
                ),

                // ── Tags ── Rien à proposer sans vocabulaire, sauf à garder
                // des tags déjà posés.
                if (vocabulary.isNotEmpty || _form.tagIds.isNotEmpty)
                  EditorSection(
                    title: 'routes.editor.tags'.tr(),
                    child: PdlSettingRow(
                      key: keys.postEditor.tagsRow,
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

                // ── Visibilité et signature ── Les valeurs que le backend
                // permet à cette publication (docs/LEDGER_*.md MOB-137).
                VisibilityField(
                  title: 'routes.editor.visibility'.tr(),
                  selectorKey: keys.postEditor.visibility,
                  allowed: allowedVisibilitiesFor(
                    widget.team,
                    VisibilityKind.post,
                    permissions: post?.permissions,
                  ),
                  value: _form.visibility,
                  onChanged: (Visibility v) =>
                      _update(_form.copyWith(visibility: v)),
                  teamPrivate: isPrivateTeam(widget.team),
                  enabled: !busy,
                ),
                EditorSection(
                  title: 'posts.editor.signature'.tr(),
                  child: PdlSettingRow(
                    padding: EdgeInsets.zero,
                    title: 'posts.editor.signedAsTeam'.tr(
                      namedArgs: <String, String>{'team': widget.team.name},
                    ),
                    subtitle: 'posts.editor.signedAsTeamHint'.tr(),
                    trailing: PdlSwitch(
                      key: keys.postEditor.signedAsTeam,
                      value: _form.signedAsTeam,
                      semanticLabel: 'posts.editor.signedAsTeam'.tr(
                        namedArgs: <String, String>{'team': widget.team.name},
                      ),
                      onChanged: busy
                          ? null
                          : (bool v) =>
                                _update(_form.copyWith(signedAsTeam: v)),
                    ),
                  ),
                ),

                // ── Statut et dates ── Publiée : la date qu'elle affiche.
                // Brouillon : une publication programmée, facultative.
                EditorSection(
                  title: 'rides.editor.status'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PdlSegmented<Status>(
                        key: keys.postEditor.status,
                        value: _form.status,
                        onChanged: (Status s) =>
                            _update(_form.copyWith(status: s)),
                        segments: <PdlSegment<Status>>[
                          for (final Status s in statuses)
                            PdlSegment<Status>(
                              key: keys.postEditor.statusOption(s.json!),
                              value: s,
                              label: 'status.${s.json!.toLowerCase()}'.tr(),
                            ),
                        ],
                      ),
                      const SizedBox(height: PdlSpacing.chipGap),
                      if (_form.status == Status.draft) ...<Widget>[
                        PdlSettingRow(
                          key: keys.postEditor.publishAtRow,
                          padding: EdgeInsets.zero,
                          icon: PdlIcons.reminder,
                          title: 'rides.editor.publishAt'.tr(),
                          subtitle: _form.publishAt == null
                              ? 'rides.editor.publishAtNone'.tr()
                              : AppFormatters.formatLongDateTime(
                                  parseWallTime(_form.publishAt)!,
                                ),
                          trailing: _form.publishAt == null
                              ? null
                              : EditorClearButton(
                                  onTap: () => _update(
                                    _form.copyWith(publishAt: () => null),
                                  ),
                                ),
                          onTap: busy ? null : _editPublishAt,
                        ),
                        Text(
                          publishAtValid
                              ? 'rides.editor.publishAtHint'.tr()
                              : 'rides.editor.publishAtPast'.tr(),
                          style: t.xs.copyWith(
                            color: publishAtValid ? c.textDimmed : c.danger,
                          ),
                        ),
                      ] else ...<Widget>[
                        PdlSettingRow(
                          key: keys.postEditor.dateRow,
                          padding: EdgeInsets.zero,
                          icon: PdlIcons.date,
                          title: 'posts.editor.date'.tr(),
                          subtitle: AppFormatters.formatLongDate(wall),
                          onTap: busy ? null : _editDate,
                        ),
                        PdlSettingRow(
                          key: keys.postEditor.timeRow,
                          padding: EdgeInsets.zero,
                          icon: PdlIcons.time,
                          title: 'rides.editor.time'.tr(),
                          subtitle: AppFormatters.formatTime(wall),
                          onTap: busy ? null : _editTime,
                        ),
                        ZoneMentionLine(
                          instant: AppFormatters.zoneWallClockToUtc(wall, zone),
                          zone: zone,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
