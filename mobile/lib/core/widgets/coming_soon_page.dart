import 'package:easy_localization/easy_localization.dart';

import '../material.dart';

/// Explicit placeholder for a route that exists in the contract and in the
/// router, but whose screen is delivered by a later batch.
///
/// Deliberately **not** a blank widget: the URL is deep-linkable and reachable
/// from the tab bar, so landing on it must say what the page will be rather
/// than look like a rendering bug.
class ComingSoonPage extends StatelessWidget {
  /// Page title, also used as the app bar title. Translation key.
  final String titleKey;

  /// One sentence describing what will live here. Translation key.
  final String messageKey;

  final IconData icon;

  const ComingSoonPage({
    super.key,
    required this.titleKey,
    required this.messageKey,
    this.icon = Icons.construction_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(titleKey.tr())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                messageKey.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'common.comingSoon'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
