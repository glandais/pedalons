import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/features/home/providers/next_ride_provider.dart';

import '../../support/content_permissions.dart';
import '../rides/ride_fixtures.dart';

/// « Ma prochaine sortie » garde une sortie **en cours** — se désinscrire et
/// « GPS » y restent jusqu'à la fin (règles R6 et R7, KIT §9,
/// docs/LEDGER_*.md MOB-139) — et passe une sortie terminée.
class _Users implements UsersClient {
  _Users(this.rows);

  final List<PublicationDto> rows;
  String? from;
  int? size;

  @override
  Future<PublicationListResponse> listMyParticipations({
    int? page = 0,
    int? size = 20,
    String? from,
    Status? status,
    String? to,
    ListViewMode? view,
  }) async {
    this.from = from;
    this.size = size;
    return PublicationListResponse(
      publications: rows,
      total: rows.length,
      page: 0,
      size: size ?? 20,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Une ligne de liste partie depuis [ago], qui dure trois heures.
PublicationDtoRide _row(String slug, Duration ago) {
  final RideDto r = fixtureRide(
    dateTime: DateTime.now().toUtc().subtract(ago).toIso8601String(),
    registered: true,
    registeredGroupId: 'g1',
  );
  return PublicationDtoRide(
    permissions: kNoPermissions,
    timezone: r.timezone,
    tags: r.tags,
    team: r.team,
    id: 'r-$slug',
    slug: slug,
    name: slug,
    media: r.media,
    dateTime: r.dateTime,
    endDateTime: r.endDateTime,
    status: r.status,
    visibility: r.visibility,
    participantCount: r.participantCount,
    groupCount: r.groupCount,
    groups: const <RideGroupDto>[],
    groupSummaries: r.groupSummaries,
    topParticipants: const <PublicUserDto>[],
    deleted: false,
    registered: true,
    registeredGroupId: 'g1',
    registeredGroup: r.groups.first,
    full: false,
    finished: r.finished,
  );
}

Future<(NextRide?, _Users)> _read(List<PublicationDto> rows) async {
  final _Users users = _Users(rows);
  final ProviderContainer container = ProviderContainer(
    overrides: [usersClientProvider.overrideWithValue(users)],
  );
  addTearDown(container.dispose);
  return (await container.read(nextRideProvider.future), users);
}

void main() {
  test(
    'une sortie partie depuis une heure reste « Ma prochaine sortie »',
    () async {
      final (NextRide? next, _Users users) = await _read(<PublicationDto>[
        _row('en-cours', const Duration(hours: 1)),
      ]);
      expect(next?.ride.slug, 'en-cours');
      // La requête remonte d'une journée : `from` filtre sur le départ.
      final DateTime from = DateTime.parse(users.from!);
      expect(
        DateTime.now().toUtc().difference(from),
        greaterThanOrEqualTo(const Duration(hours: 23)),
      );
    },
  );

  test('une sortie terminée passe : la suivante la remplace', () async {
    final (NextRide? next, _) = await _read(<PublicationDto>[
      _row('terminee', const Duration(hours: 5)),
      _row('demain', const Duration(hours: -20)),
    ]);
    expect(next?.ride.slug, 'demain');
  });

  test('rien que des sorties terminées : pas de bloc', () async {
    final (NextRide? next, _) = await _read(<PublicationDto>[
      _row('terminee', const Duration(hours: 5)),
    ]);
    expect(next, isNull);
  });
}
