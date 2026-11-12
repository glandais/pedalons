import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

/// Identité : photo, nom affiché, adresse e-mail.
///
/// **L'erreur est en ligne, sous le champ concerné**, jamais un bandeau global :
/// un « Une erreur est survenue » en haut de page ne dit pas lequel des dix
/// réglages a échoué.
///
/// L'e-mail est en lecture seule et le dit par un badge : le changer passe par
/// une vérification (`POST /api/auth/email/change-request`) qui n'appartient
/// pas à cet écran.
class ProfileIdentitySection extends ConsumerStatefulWidget {
  const ProfileIdentitySection({super.key});

  @override
  ConsumerState<ProfileIdentitySection> createState() =>
      _ProfileIdentitySectionState();
}

class _ProfileIdentitySectionState
    extends ConsumerState<ProfileIdentitySection> {
  final TextEditingController _name = TextEditingController();

  /// Le nom tel que le serveur le connaît — la référence de « Annuler ».
  String _serverName = '';

  bool _saving = false;
  bool _avatarBusy = false;
  String? _nameError;
  String? _avatarError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _adopt(UserDto user) {
    if (_serverName == user.displayName) return;
    _serverName = user.displayName;
    // Ne pas écraser une saisie en cours : l'utilisateur tape pendant qu'un
    // rafraîchissement arrive, et son texte lui appartient.
    if (!_saving && _name.text.isEmpty || _name.text == _serverName) {
      _name.text = user.displayName;
    }
  }

  Future<void> _save() async {
    final String value = _name.text.trim();
    if (value.isEmpty || value == _serverName || _saving) return;
    setState(() {
      _saving = true;
      _nameError = null;
    });
    try {
      final UserDto user = await ref
          .read(profileRepositoryProvider)
          .updateDisplayName(value);
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) setState(() => _saving = false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = getErrorMessage(error, stackTrace);
      });
    }
  }

  void _cancel() => setState(() {
    _name.text = _serverName;
    _nameError = null;
  });

  Future<void> _pickAvatar() async {
    setState(() => _avatarError = null);
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // 256 px suffisent au serveur, qui redimensionne de toute façon :
        // envoyer 12 Mo pour en stocker 40 Ko fait échouer l'envoi en 3G.
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      setState(() => _avatarBusy = true);
      final UserDto user = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(picked.path);
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) setState(() => _avatarBusy = false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _avatarBusy = false;
        _avatarError = getErrorMessage(error, stackTrace);
      });
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _avatarBusy = true;
      _avatarError = null;
    });
    try {
      final UserDto user = await ref
          .read(profileRepositoryProvider)
          .deleteAvatar();
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) setState(() => _avatarBusy = false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _avatarBusy = false;
        _avatarError = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UserDto? user = ref.watch(
      authProvider.select((AuthState s) => s.user),
    );
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.all(PdlSpacing.section),
        child: PdlSkeletonCard(),
      );
    }
    _adopt(user);

    final bool dirty = _name.text.trim() != _serverName;

    return Padding(
      padding: const EdgeInsets.all(PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: PdlAvatarEditor(
              name: user.displayName,
              imageUrl: user.avatarUrl,
              busy: _avatarBusy,
              onPick: _avatarBusy ? null : _pickAvatar,
              pickSemanticLabel: 'profile.identity.changePhoto'.tr(),
              onRemove: user.avatarUrl == null || _avatarBusy
                  ? null
                  : _removeAvatar,
              removeLabel: 'profile.identity.removePhoto'.tr(),
            ),
          ),
          if (_avatarError != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(tone: PdlBannerTone.danger, message: _avatarError!),
          ],
          const SizedBox(height: PdlSpacing.section),
          Text('profile.identity.displayName'.tr(), style: t.xs),
          const SizedBox(height: 4),
          PdlSearchField(
            key: keys.profile.displayNameField,
            value: _name.text,
            hintText: 'profile.identity.displayName'.tr(),
            errorText: _nameError,
            // Pas de débounce : ce champ ne cherche rien, il se valide. Pas de
            // loupe ni d'action « Rechercher » au clavier pour la même raison —
            // c'est « OK », et il enregistre.
            debounce: Duration.zero,
            prefixIcon: null,
            textInputAction: TextInputAction.done,
            onChanged: (String? value) =>
                setState(() => _name.text = value ?? ''),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          // **Annuler et Enregistrer sont toujours visibles**, désactivés tant
          // que rien n'a changé : un bouton qui apparaît à la première frappe
          // décale le contenu au moment précis où l'on regarde ailleurs.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              PdlButton(
                label: 'common.cancel'.tr(),
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                enabled: dirty && !_saving,
                onPressed: _cancel,
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              PdlButton(
                key: keys.profile.displayNameSave,
                label: 'profile.identity.save'.tr(),
                loadingLabel: 'profile.identity.saving'.tr(),
                size: PdlButtonSize.sm,
                loading: _saving,
                enabled: dirty && _name.text.trim().isNotEmpty,
                onPressed: _save,
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.section),
          Text('profile.identity.email'.tr(), style: t.xs),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: c.text),
                ),
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              PdlBadge(
                label: 'profile.identity.readOnly'.tr(),
                tone: PdlTone.pair(c.softGray, c.neutral),
                icon: PdlIcons.visibilityTeam,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
