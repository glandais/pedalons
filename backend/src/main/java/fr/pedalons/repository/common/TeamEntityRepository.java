package fr.pedalons.repository.common;

import fr.pedalons.domain.common.SearchClause;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.TeamEntityType;
import fr.pedalons.repository.query.AndClause;
import fr.pedalons.repository.query.OrClause;
import fr.pedalons.repository.query.PedalonsQuery;
import fr.pedalons.repository.query.SimpleClause;
import fr.pedalons.service.team.request.MinRole;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.TypedQuery;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public interface TeamEntityRepository<T extends TeamEntity, Q extends TeamEntityQueryInterface>
    extends BaseRepository<T> {

  default boolean existsByTeamAndSlug(Long teamId, String slug) {
    return count("team.id = ?1 and slug = ?2", teamId, slug) > 0;
  }

  Q getQuerySlug(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      String slug,
      boolean includeDeleted,
      boolean platformAdmin);

  Q getQueryId(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      Long id,
      boolean includeDeleted,
      boolean platformAdmin);

  default Optional<T> findByTeamAndSlug(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      String slug,
      boolean includeDeleted,
      boolean platformAdmin) {
    return findOne(getQuerySlug(domainId, teamId, userId, slug, includeDeleted, platformAdmin));
  }

  default Optional<T> findByTeamAndId(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      Long id,
      boolean includeDeleted,
      boolean platformAdmin) {
    return findOne(getQueryId(domainId, teamId, userId, id, includeDeleted, platformAdmin));
  }

  TeamEntityType getEntityType();

  EntityType getAllEntityType();

  /**
   * What a query selects and where it selects it from. The visibility clauses only ever reference
   * the aliases {@code te} (the team entity) and {@code ut} (the current user's membership), so any
   * shape that binds those two aliases gets the exact same authorization rules.
   *
   * @param projection what to select, e.g. {@code te}
   * @param from the from clause without the {@code UserTeam} join, e.g. {@code Route te}
   * @param ordered whether to append the default ordering (an aggregate projection must not)
   */
  record QueryShape(String projection, String from, boolean ordered) {}

  /**
   * Find publications across multiple teams with proper visibility filtering.
   */
  default PedalonsPage<T> find(Q query) {
    if (query.minRole() != null && query.userId() == null) {
      // An anonymous visitor belongs to no team, and the anonymous query shape has no UserTeam
      // join to filter on.
      return new PedalonsPage<>(List.of(), 0);
    }
    PedalonsQuery pedalonsQuery = getPedalonsQuery(query, true);
    return getPage(pedalonsQuery, query);
  }

  /**
   * How many rows {@link #find} would match, without reading any of them.
   *
   * <p>Same query, same visibility clauses, same {@code andSpecific} hook — only the projection
   * changes, so a count can never disagree with the listing it announces. The default listing shape
   * is deliberately not reused: its {@code fetch join} would be illegal under an aggregate, and the
   * team columns it keeps are exactly what a count has no use for.
   */
  default long countMatching(Q query) {
    if (query.minRole() != null && query.userId() == null) {
      // Same short circuit as find(): an anonymous visitor belongs to no team, and the anonymous
      // query shape has no UserTeam join to filter on.
      return 0;
    }
    PedalonsQuery pedalonsQuery =
        getPedalonsQuery(
            query,
            true,
            new QueryShape("count(te.id)", getEntityType().getTypeName() + " te", false));
    // andSpecific may have installed an ordering (a sort filter, an ascending flag); an aggregate
    // projection must not carry one.
    pedalonsQuery.noOrder();
    TypedQuery<Long> typedQuery =
        getEntityManager().createQuery(pedalonsQuery.getStringQuery(), Long.class);
    pedalonsQuery.getParams().forEach(typedQuery::setParameter);
    return typedQuery.getSingleResult();
  }

  default Optional<T> findOne(Q query) {
    PedalonsQuery pedalonsQuery = getPedalonsQuery(query, false);
    return findOne(pedalonsQuery);
  }

  /**
   * Every row matching {@code query}, with no {@code LIMIT} applied. {@code query.page()}/{@code
   * query.size()} are built into {@code query} but never read here — see {@link
   * BaseRepository#findAll(PedalonsQuery)}. If the caller wants a bounded list, use {@link #find}
   * instead, and take {@code .items()} off the returned {@link
   * fr.pedalons.dto.common.PedalonsPage}.
   */
  default List<T> findAll(Q query) {
    PedalonsQuery pedalonsQuery = getPedalonsQuery(query, true);
    return findAll(pedalonsQuery);
  }

  /**
   * The default shape, which fetch-joins the owning team.
   *
   * <p>Every row of every listing renders its team (name, slug, visibility), and the query already
   * filters on {@code te.team.*}, so the join is happening regardless — {@code fetch} just keeps the
   * columns instead of throwing them away and re-selecting the teams afterwards. On a cross-team
   * listing that removes a whole round-trip; on a team-scoped one it costs nothing, because the team
   * was already resolved by {@code TeamService.getTeam} and is in the persistence context.
   *
   * <p><b>This is safe only because {@code team} is a to-one.</b> A fetch join on a <em>collection</em>
   * multiplies the result rows, and Hibernate then cannot apply {@code LIMIT} in SQL — it pages in
   * memory instead (HHH000104), reading the entire table to return 20 rows. Do not extend this shape
   * to {@code te.assets} or any other collection; those are handled by {@code
   * quarkus.hibernate-orm.fetch.batch-size}, which costs one extra query and no row multiplication.
   */
  private PedalonsQuery getPedalonsQuery(Q query, boolean list) {
    return getPedalonsQuery(
        query,
        list,
        new QueryShape("te", getEntityType().getTypeName() + " te left join fetch te.team", true));
  }

  /**
   * The rows a search engine may index: what an anonymous visitor finds in a cross-team listing,
   * narrowed to {@code PUBLIC} teams even on a pinned host — where the listing lets an unlisted
   * team's content through, but every page of that team is {@code noindex} (ledger {@code WEB-4}).
   *
   * <p>Goes through the listing's own query so the sitemap can never announce a page the site would
   * refuse; only the projection changes. Newest first, so a truncated sitemap keeps the fresh ones.
   *
   * @param projection columns over the alias {@code te}, e.g. {@code te.team.slug, te.slug}
   */
  default List<Object[]> findIndexable(Q query, String projection, int limit) {
    if (query.userId() != null) {
      throw new IllegalArgumentException("An indexable listing is anonymous");
    }
    PedalonsQuery pedalonsQuery =
        getPedalonsQuery(
            query, true, new QueryShape(projection, getEntityType().getTypeName() + " te", false));
    pedalonsQuery.and("te.team.visibility = 'PUBLIC'", Map.of()).order("te.updatedAt desc");
    TypedQuery<Object[]> typedQuery =
        getEntityManager().createQuery(pedalonsQuery.getStringQuery(), Object[].class);
    pedalonsQuery.getParams().forEach(typedQuery::setParameter);
    return typedQuery.setMaxResults(limit).getResultList();
  }

  default PedalonsQuery getPedalonsQuery(Q query, boolean list, QueryShape shape) {
    // Build base query
    PedalonsQuery pedalonsQuery;

    // When the request targets a single team (domain alias pin, or an explicit single-team filter),
    // the caller navigated straight to that team's page. A PUBLIC_UNLISTED ("non répertorié") team
    // is reachable by URL and must expose its public content there — the strict PUBLIC-only team
    // filter is only meant to keep unlisted teams out of cross-team/global directory listings.
    Set<Long> queryTeamIds = query.teamIds();
    boolean teamScoped =
        query.pinnedTeamId() != null || (queryTeamIds != null && queryTeamIds.size() == 1);
    AndClause publicEntity = getPublicEntity(list, teamScoped);

    if (query.userId() == null) {
      pedalonsQuery =
          new PedalonsQuery("select " + shape.projection() + " from " + shape.from() + " where");

      // Anonymous user: only public publications from public teams
      pedalonsQuery = pedalonsQuery.and(publicEntity).and("TYPE(te) <> Ad", Map.of());
      // Hidden by reports until a moderator decides.
      pedalonsQuery.and("te.moderationHiddenAt IS NULL", Map.of());
    } else {
      pedalonsQuery =
          new PedalonsQuery(
                  "select "
                      + shape.projection()
                      + " from "
                      + shape.from()
                      + " left join UserTeam ut on "
                      + "ut.team.id = te.team.id and ut.user.id = :userId "
                      + "where")
              .addParam("userId", query.userId());

      // A platform admin's bypass covers what they open — a detail, or the lists of the one team
      // they navigated to, as its moderation tool — never a personal or cross-team view, nor a
      // query restricted to their own memberships: there, their real role decides
      // (docs/LEDGER_*.md API-137).
      boolean bypass = query.platformAdmin() && (!list || (teamScoped && query.minRole() == null));
      if (!bypass) {
        OrClause visibilityFilter = new OrClause();

        // public
        visibilityFilter.add(publicEntity);

        // OR

        // team member and PUBLISHED/CANCELLED
        AndClause teamEntity = new AndClause();
        teamEntity.add(new SimpleClause("ut IS NOT NULL", Map.of()));
        teamEntity.add(new SimpleClause("te.status IN ('PUBLISHED', 'CANCELLED')", Map.of()));
        visibilityFilter.add(teamEntity);

        // OR

        // ad creator
        AndClause adCreator = new AndClause();
        // still member
        adCreator.add(new SimpleClause("ut IS NOT NULL", Map.of()));
        adCreator.add(new SimpleClause("TYPE(te) = Ad", Map.of()));
        // userId already defined
        adCreator.add(new SimpleClause("te.createdBy.id = :userId", Map.of()));
        visibilityFilter.add(adCreator);

        // OR

        // organizer
        AndClause organizer = new AndClause();
        organizer.add(new SimpleClause("ut.role = 'ORGANIZER'", Map.of()));
        // can't see DRAFT TeamPage
        organizer.add(new SimpleClause("TYPE(te) <> TeamPage", Map.of()));
        // can't see DRAFT Ads
        organizer.add(new SimpleClause("TYPE(te) <> Ad", Map.of()));
        visibilityFilter.add(organizer);

        // OR

        // admin
        AndClause draftEntity = new AndClause();
        draftEntity.add(new SimpleClause("ut.role = 'ADMIN'", Map.of()));
        // can't see DRAFT Ads
        draftEntity.add(new SimpleClause("TYPE(te) <> Ad", Map.of()));
        visibilityFilter.add(draftEntity);

        pedalonsQuery.and(visibilityFilter);

        // Hidden by reports until a moderator decides — except from the team's moderators, who
        // have to read it to decide. A bypassing platform admin skips this block altogether.
        pedalonsQuery.and(
            "(te.moderationHiddenAt IS NULL OR ut.role IN ('ORGANIZER', 'ADMIN'))", Map.of());
      } else if (list) {
        // Someone else's draft ad stays out of the team's lists, as it does for a team admin; the
        // detail stays readable by link.
        pedalonsQuery.and(
            "(TYPE(te) <> Ad OR te.status IN ('PUBLISHED', 'CANCELLED')"
                + " OR te.createdBy.id = :userId)",
            Map.of());
      }

      if (list) {
        // Listings only — the detail stays reachable by link. Platform admins included: both are
        // the caller's own choice. Subqueries of the same statement, so a page still costs the
        // same number of queries.
        // What the caller reported disappears from their lists at once.
        pedalonsQuery.and(
            "te.id NOT IN (select r.targetId from ContentReport r where r.reporter.id = :userId)",
            Map.of());
        // Posts and ads of the members the caller blocked. Rides, trips and routes stay: they are
        // the team's organisation, not someone's say.
        pedalonsQuery.and(
            "((TYPE(te) <> Post AND TYPE(te) <> Ad) OR te.createdBy.id NOT IN"
                + " (select b.blocked.id from UserBlock b where b.blocker.id = :userId))",
            Map.of());
      }

      MinRole minRole = query.minRole();
      if (minRole != null) {
        // The left join leaves ut.role NULL for a non-member, so this alone drops the public-team
        // branch of the visibility filter above: only the user's own teams survive.
        pedalonsQuery.and("ut.role in (:userRoles)", Map.of("userRoles", minRole.acceptedRoles()));
      }
    }

    if (!query.includeDeleted()) {
      // entity not deleted
      pedalonsQuery.and("te.deleted = false", Map.of());
    }
    pedalonsQuery =
        pedalonsQuery
            // filter by domain
            .and("te.team.domain.id = :domainId", Map.of("domainId", query.domainId()))
            // team not deleted
            .and("te.team.deleted = false", Map.of());

    // Pin to a single team when the request arrived on a domain alias. A site scope like domainId
    // above (platform admins included); it ANDs with the teamIds filter below.
    Long pinnedTeamId = query.pinnedTeamId();
    if (pinnedTeamId != null) {
      pedalonsQuery =
          pedalonsQuery.and("te.team.id = :pinnedTeamId", Map.of("pinnedTeamId", pinnedTeamId));
    }

    pedalonsQuery =
        pedalonsQuery
            // not trip or (trip enabled and routes enabled)
            .and(
                "(TYPE(te) <> Trip OR (te.team.enableTrips = true AND te.team.enableRoutes ="
                    + " true))",
                Map.of())
            // not ad or ad enabled
            .and("(TYPE(te) <> Ad OR te.team.enableAds = true)", Map.of())
            // not post or post enabled
            .and("(TYPE(te) <> Post OR te.team.enablePosts = true)", Map.of())
            // not ride or (ride enabled and routes enabled)
            .and(
                "(TYPE(te) <> Ride OR (te.team.enableRides = true AND te.team.enableRoutes ="
                    + " true))",
                Map.of());

    if (shape.ordered()) {
      pedalonsQuery = pedalonsQuery.order("dateTime desc");
    }

    Set<Long> teamIds = query.teamIds();
    if (teamIds != null && !teamIds.isEmpty()) {
      pedalonsQuery = pedalonsQuery.and("te.team.id IN (:teamIds)", Map.of("teamIds", teamIds));
    }
    String slug = query.slug();
    if (slug != null) {
      pedalonsQuery = pedalonsQuery.and("te.slug = :slug", Map.of("slug", slug));
    }
    Long id = query.id();
    if (id != null) {
      pedalonsQuery = pedalonsQuery.and("te.id = :id", Map.of("id", id));
    }
    pedalonsQuery =
        SearchClause.addSearch(pedalonsQuery, Set.of("te.name", "te.markdown"), query.search());

    // Add date range filters
    Instant from = query.from();
    if (from != null) {
      pedalonsQuery = pedalonsQuery.and("te.dateTime >= :from", Map.of("from", from));
    }
    Instant to = query.to();
    if (to != null) {
      pedalonsQuery = pedalonsQuery.and("te.dateTime <= :to", Map.of("to", to));
    }
    pedalonsQuery = andSpecific(pedalonsQuery, query);
    return pedalonsQuery;
  }

  private static AndClause getPublicEntity(boolean list, boolean teamScoped) {
    AndClause publicEntity = new AndClause();
    if (list) {
      // Global/cross-team listings hide unlisted teams entirely; a team-scoped listing (the visitor
      // is already on that specific team's page) still allows the PUBLIC_UNLISTED team through, but
      // keeps the entity-level PUBLIC filter so unlisted entities stay out of the list.
      if (teamScoped) {
        publicEntity.add(new SimpleClause("te.team.visibility <> 'TEAM'", Map.of()));
      } else {
        publicEntity.add(new SimpleClause("te.team.visibility = 'PUBLIC'", Map.of()));
      }
      publicEntity.add(new SimpleClause("te.visibility = 'PUBLIC'", Map.of()));
    } else {
      publicEntity.add(new SimpleClause("te.team.visibility <> 'TEAM'", Map.of()));
      publicEntity.add(new SimpleClause("te.visibility <> 'TEAM'", Map.of()));
    }
    publicEntity.add(new SimpleClause("te.status IN ('PUBLISHED', 'CANCELLED')", Map.of()));
    return publicEntity;
  }

  default PedalonsQuery andSpecific(PedalonsQuery pedalonsQuery, Q query) {
    return pedalonsQuery;
  }
}
