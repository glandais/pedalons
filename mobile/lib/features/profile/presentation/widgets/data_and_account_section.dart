import 'dart:developer' as developer;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/profile_repository.dart';
import 'confirm_sheet.dart';

/// Le dernier export RGPD, ou `null` s'il n'y en a jamais eu.
final latestExportProvider = FutureProvider<UserExportDto?>((ref) async {
  return ref.watch(profileRepositoryProvider).latestExport();
});

/// Mes données : l'export RGPD.
///
/// Trois états, et ils ne se ressemblent pas : jamais demandé, en préparation,
/// prêt jusqu'à une date. Le troisième porte sa **date d'expiration** — un
/// lien de téléchargement qui a expiré sans prévenir est un ticket de support.
class DataExportCard extends ConsumerStatefulWidget {
  const DataExportCard({super.key});

  @override
  ConsumerState<DataExportCard> createState() => _DataExportCardState();
}

class _DataExportCardState extends ConsumerState<DataExportCard> {
  bool _busy = false;
  String? _error;

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).requestExport();
      ref.invalidate(latestExportProvider);
      if (mounted) setState(() => _busy = false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final UserExportDto? export = ref.watch(latestExportProvider).value;
    // `status` est une chaîne au DTO ; l'enum généré est la liste fermée du
    // contrat. Un export prêt est `READY` — l'ancienne comparaison à
    // `COMPLETED`, statut inexistant, le laissait « en préparation » pour
    // toujours (`docs/LEDGER_*.md MOB-32`).
    final UserExportStatus? status = export == null
        ? null
        : UserExportStatus.fromJson(export.status.toUpperCase());
    // Un export arrivé à son terme — prêt ou expiré — appelle un « nouvel »
    // export ; celui en cours ou échoué, une simple demande.
    final bool ready =
        status == UserExportStatus.ready || status == UserExportStatus.expired;
    final DateTime? expires = export?.expiresAt == null
        ? null
        : AppFormatters.tryParseDisplayTime(export!.expiresAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(PdlIcons.gpx, size: 24, color: context.pdl.textDimmed),
                  const SizedBox(width: PdlSpacing.cardTight),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('profile.data.export'.tr(), style: t.bodyStrong),
                        Text(
                          key: keys.profile.dataExportStatus,
                          switch (status) {
                            null => 'profile.data.never'.tr(),
                            UserExportStatus.ready when expires != null =>
                              'profile.data.readyUntil'.tr(
                                namedArgs: <String, String>{
                                  'date': AppFormatters.formatLongDate(expires),
                                },
                              ),
                            UserExportStatus.ready => 'profile.data.ready'.tr(),
                            UserExportStatus.expired =>
                              'profile.data.expired'.tr(),
                            UserExportStatus.failed =>
                              'profile.data.failed'.tr(),
                            UserExportStatus.pending ||
                            UserExportStatus.processing ||
                            UserExportStatus.$unknown =>
                              'profile.data.preparing'.tr(),
                          },
                          style: t.xs,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PdlSpacing.chipGap),
              // **Pas de bouton de téléchargement.** `GET
              // /api/export/download?token=` attend « le jeton reçu dans
              // l'e-mail de notification », et `UserExportDto` ne porte ni ce
              // jeton ni d'URL : l'archive se récupère depuis le message, et
              // dessiner un bouton ici mènerait à un 404.
              Text('profile.data.byEmail'.tr(), style: t.xs),
              const SizedBox(height: PdlSpacing.cardTight),
              PdlButton(
                key: keys.profile.dataExportButton,
                label: ready
                    ? 'profile.data.newExport'.tr()
                    : 'profile.data.request'.tr(),
                variant: PdlButtonVariant.outline,
                fullWidth: true,
                loading: _busy,
                loadingLabel: 'profile.data.requesting'.tr(),
                onPressed: _request,
              ),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlBanner(tone: PdlBannerTone.danger, message: _error!),
        ],
      ],
    );
  }
}

/// « Déconnecter tous les appareils », dans « Connexion et sécurité ».
///
/// **`logout-all` était écrit et câblé nulle part** : le dépôt l'expose depuis
/// le début, aucun écran ne l'appelait. C'est la seule façon de reprendre la
/// main quand une session traîne sur un appareil qu'on n'a plus.
class LogoutAllCard extends ConsumerStatefulWidget {
  const LogoutAllCard({super.key});

  @override
  ConsumerState<LogoutAllCard> createState() => _LogoutAllCardState();
}

class _LogoutAllCardState extends ConsumerState<LogoutAllCard> {
  bool _busy = false;
  String? _error;

  Future<void> _logoutAll() async {
    final bool confirmed = await confirmDestructive(
      context,
      title: 'profile.account.logoutAllTitle'.tr(),
      message: 'profile.account.logoutAllMessage'.tr(),
      confirmLabel: 'profile.account.logoutAll'.tr(),
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Un refus du serveur lève et laisse la session ouverte : on l'affiche en
    // bandeau plutôt que d'annoncer une déconnexion qui n'a pas eu lieu.
    try {
      await ref.read(authProvider.notifier).logoutAll();
      if (mounted) context.go(Paths.login());
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('profile.sessions.hint'.tr(), style: t.sub),
              const SizedBox(height: PdlSpacing.cardTight),
              PdlButton(
                key: keys.profile.logoutAllButton,
                label: 'profile.account.logoutAll'.tr(),
                variant: PdlButtonVariant.outline,
                fullWidth: true,
                loading: _busy,
                loadingLabel: 'common.loading'.tr(),
                onPressed: _logoutAll,
              ),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlBanner(tone: PdlBannerTone.danger, message: _error!),
        ],
      ],
    );
  }
}

/// La zone de danger de « Mon compte » : supprimer le compte.
class DeleteAccountSection extends ConsumerStatefulWidget {
  const DeleteAccountSection({super.key});

  @override
  ConsumerState<DeleteAccountSection> createState() =>
      _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<DeleteAccountSection> {
  bool _busy = false;
  String? _error;

  /// Les équipes qui refusent la suppression, nommées sous le bouton.
  List<String>? _blockingTeams;

  /// Les équipes venues de biketeam dont on est le seul administrateur :
  /// elles refusent la suppression même sans autre membre, puisque biketeam
  /// redirige vers elles ses anciennes adresses. Nommées à part, avec leur
  /// adresse : ce qu'il faut faire n'est pas la même chose.
  List<String>? _migratedTeams;

  static List<String> _names(List<TeamPublicationDto> teams) =>
      teams.map((TeamPublicationDto team) => team.name).toList();

  /// La suppression commence par demander ce qu'elle ferait aux équipes.
  ///
  /// Refusée, elle le dit **avant** la feuille de confirmation, en nommant les
  /// équipes : une confirmation qui ne peut qu'échouer ne se propose pas.
  /// Acceptée, la feuille nomme les équipes dont on est le seul membre, qui
  /// partent avec le compte. Si la question échoue, la confirmation générique
  /// reste : le serveur refuse de toute façon une suppression bloquée.
  Future<void> _deleteAccount() async {
    setState(() {
      _busy = true;
      _error = null;
      _blockingTeams = null;
      _migratedTeams = null;
    });
    AccountDeletionImpactDto? impact;
    try {
      impact = await ref.read(profileRepositoryProvider).deletionImpact();
    } catch (error, stackTrace) {
      developer.log(
        'Deletion impact unavailable',
        name: 'pedalons.profile',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (impact != null && impact.blocked) {
      final List<String> blocking = _names(impact.blockingTeams);
      final List<String> migrated = impact.migratedTeams
          .map((TeamPublicationDto team) => '${team.name} (${team.slug})')
          .toList();
      setState(() {
        _blockingTeams = blocking.isEmpty ? null : blocking;
        _migratedTeams = migrated.isEmpty ? null : migrated;
      });
      return;
    }

    final List<String> deletedTeams = _names(
      impact?.deletedTeams ?? const <TeamPublicationDto>[],
    );
    final String warning = 'profile.account.deleteMessage'.tr();
    final String message = deletedTeams.isEmpty
        ? warning
        : '${'profile.account.teamsDeleted'.plural(deletedTeams.length, namedArgs: <String, String>{'teams': deletedTeams.join(', ')})}\n\n$warning';

    final bool confirmed = await confirmDestructive(
      context,
      title: 'profile.account.deleteTitle'.tr(),
      message: message,
      confirmLabel: 'profile.account.delete'.tr(),
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go(Paths.login());
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        0,
        PdlSpacing.section,
        PdlSpacing.section,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Divider(height: 1, color: c.borderSubtle),
          const SizedBox(height: 14),
          Text(
            'profile.account.dangerZone'.tr(),
            style: t.sectionTitle.copyWith(fontSize: 16, color: c.dangerOnSoft),
          ),
          const SizedBox(height: 6),
          Text('profile.account.dangerHint'.tr(), style: t.sub),
          const SizedBox(height: PdlSpacing.cardTight),
          // Contour rouge, **jamais un aplat** : un aplat rouge pleine largeur
          // se touche par réflexe, et celui-ci ne se défait pas.
          PdlButton(
            key: keys.profile.deleteAccountButton,
            label: 'profile.account.delete'.tr(),
            variant: PdlButtonVariant.danger,
            fullWidth: true,
            enabled: !_busy,
            onPressed: _deleteAccount,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(tone: PdlBannerTone.danger, message: _error!),
          ],
          if (_migratedTeams case final List<String> migrated) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(
              tone: PdlBannerTone.danger,
              title: 'profile.account.blockedTitle'.tr(),
              message: 'profile.account.blockedMigrated'.plural(
                migrated.length,
                namedArgs: <String, String>{'teams': migrated.join(', ')},
              ),
            ),
          ],
          if (_blockingTeams case final List<String> blocking) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(
              key: keys.profile.deletionBlockedBanner,
              tone: PdlBannerTone.danger,
              title: 'profile.account.blockedTitle'.tr(),
              message: 'profile.account.blocked'.plural(
                blocking.length,
                namedArgs: <String, String>{'teams': blocking.join(', ')},
              ),
            ),
          ],
        ],
      ),
    );
  }
}
