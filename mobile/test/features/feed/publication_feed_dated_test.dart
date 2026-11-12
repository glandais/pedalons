import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/feed/data/publication_feed_repository.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';

/// Retient le `dated` envoyé par chaque appel de liste ou de comptage.
class _RecordingPublicationsClient implements PublicationsClient {
  final Map<Symbol, bool?> dated = <Symbol, bool?>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    dated[invocation.memberName] = invocation.namedArguments[#dated] as bool?;
    if (invocation.memberName == #countAllPublications ||
        invocation.memberName == #countPublications) {
      return Future<CountResponse>.value(const CountResponse(total: 0));
    }
    return Future<PublicationListResponse>.value(
      const PublicationListResponse(
        publications: <PublicationDto>[],
        total: 0,
        page: 0,
        size: 20,
        upcomingTotal: 0,
      ),
    );
  }
}

PublicationFeedKey _key({String? teamSlug, required bool datedOnly}) => (
  teamSlug: teamSlug,
  type: null,
  search: null,
  minRole: null,
  tags: null,
  when: PublicationWhen.upcomingFirst,
  participating: false,
  datedOnly: datedOnly,
);

void main() {
  // Sans `dated=true`, une liste `UPCOMING_FIRST` sans type range les
  // publications dans « Plus tôt » : l'Agenda ne montre que sorties et voyages.
  test("l'Agenda envoie dated=true, sur la liste et le comptage", () async {
    final _RecordingPublicationsClient client = _RecordingPublicationsClient();
    final PublicationFeedRepository repository = PublicationFeedRepository(
      client,
    );

    await repository.fetchPage(
      _key(teamSlug: 'vcm', datedOnly: true),
      page: 0,
      size: 20,
    );
    await repository.count(_key(teamSlug: 'vcm', datedOnly: true));
    await repository.fetchPage(_key(datedOnly: true), page: 0, size: 20);
    await repository.count(_key(datedOnly: true));

    expect(client.dated[#listPublications], isTrue);
    expect(client.dated[#countPublications], isTrue);
    expect(client.dated[#listAllPublications], isTrue);
    expect(client.dated[#countAllPublications], isTrue);
  });

  test("le fil n'envoie pas dated : ses publications restent", () async {
    final _RecordingPublicationsClient client = _RecordingPublicationsClient();
    final PublicationFeedRepository repository = PublicationFeedRepository(
      client,
    );

    await repository.fetchPage(_key(datedOnly: false), page: 0, size: 20);
    await repository.fetchPage(
      _key(teamSlug: 'vcm', datedOnly: false),
      page: 0,
      size: 20,
    );

    expect(client.dated[#listAllPublications], isNull);
    expect(client.dated[#listPublications], isNull);
  });
}
