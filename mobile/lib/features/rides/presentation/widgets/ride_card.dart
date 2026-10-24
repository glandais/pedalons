import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/paths.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/authenticated_image.dart';

/// Shared ride list card used on the home page and team detail page.
///
/// Set [showTeamName] to true to prefix the participant count with the team name.
class RideCard extends ConsumerWidget {
  final RideDto ride;
  final bool showTeamName;

  const RideCard({super.key, required this.ride, this.showTeamName = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(accessTokenHolderProvider);
    final theme = Theme.of(context);

    final thumbnailUrl = theme.brightness == Brightness.dark
        ? ride.thumbnailDarkUrl
        : ride.thumbnailLightUrl;

    final participantText = 'rides.participants'.plural(
      ride.participantCount,
      namedArgs: {'count': ride.participantCount.toString()},
    );
    final subtitleText = showTeamName
        ? '${ride.team.name} • $participantText'
        : participantText;

    return AnimatedCard(
      onTap: () => context.push(Paths.ride(ride.team.slug, ride.slug)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Hero(
              tag: 'ride-thumbnail-${ride.slug}',
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.primaryContainer,
                  image: thumbnailUrl != null
                      ? DecorationImage(
                          image: AuthenticatedDecorationImage.fromUrl(
                            thumbnailUrl,
                            token,
                          )!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: thumbnailUrl == null
                    ? Icon(
                        Icons.directions_bike,
                        color: theme.colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppFormatters.formatRideDate(
                          DateTime.parse(ride.dateTime),
                          zone: ride.timezone,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(subtitleText, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
