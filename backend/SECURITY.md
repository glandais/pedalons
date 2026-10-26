# Security Architecture - Pedalons Platform

This document describes the security architecture of the Pedalons backend, including authentication, authorization, and data access control mechanisms.

## Table of Contents

1. [Overview](#overview)
2. [Authentication Layer](#authentication-layer)
3. [Authorization Layer](#authorization-layer)
4. [Data Access Control](#data-access-control)
5. [Permission Matrix](#permission-matrix)
6. [Security Patterns](#security-patterns)
7. [Request Filters](#request-filters)
8. [Moderation](#moderation)
9. [Developer Guidelines](#developer-guidelines)

---

## Overview

Pedalons implements a **defense-in-depth** security model with three layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    HTTP Request                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Authentication (Database Auth + JWT)              │
│  - JWT token validation                                      │
│  - @RolesAllowed / @PermitAll annotations                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Authorization (@CheckAccess + AccessChecker)      │
│  - Entity-level permission checks                           │
│  - Role-based access control (MEMBER/ORGANIZER/ADMIN)       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Data Filtering (SQL/JPQL)                         │
│  - Visibility-based query filtering                         │
│  - Soft-delete enforcement                                  │
│  - Feature flag checks                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Authentication Layer

### Database Authentication with JWT

Authentication is handled directly by the backend using database-stored credentials. Supported authentication methods:
- **Password** - Email + password (bcrypt), with an emailed reset link
- **OTP** - Passwordless email-based one-time password login
- **Passkeys/WebAuthn** - Biometric and hardware key authentication

The backend issues and validates JWT tokens on every request.

**Key Components:**
- `SecurityIdentity` - Quarkus security context injected from JWT
- `JsonWebToken` - Contains user claims (email, roles)
- `PedalonsQueryContext` - Resolves JWT to User entity

### REST Endpoint Annotations

| Annotation | Level | Usage |
|------------|-------|-------|
| `@RolesAllowed("user")` | REST | Quarkus JWT check, requires authenticated user |
| `@PermitAll` | REST | No authentication required |
| `@Admin` | REST/Service | Checks `user.platformRole == PLATFORM_ADMIN` |
| `@Logged` | Service | Checks authenticated user exists in `PedalonsQueryContext` |
| `@Public` | Service | No interceptor: the explicit statement that the method needs no login |
| `@TileTokenAuth` | REST | Name binding: only these methods accept a `?t=` tile token (see [Request Filters](#request-filters)) |
| `@BiketeamM2M` | REST | Name binding: biketeam's shared secret, migration endpoints only |

Every service method a resource calls must carry one of `@Admin` / `@CheckAccess` / `@Logged` /
`@Public` — `ArchitectureTest` fails otherwise.

Admin endpoints combine `@RolesAllowed("user")` at class level with `@Admin` at method level:

```java
@Path("/api/admin/domains")
@RolesAllowed("user")  // Ensures authenticated user at Quarkus level
public class AdminDomainResource {

    @POST
    @Admin  // Checks user.platformRole == PLATFORM_ADMIN
    public Response createDomain(...) { }
}
```

**Example (public + user endpoints):**
```java
@Path("/api/teams/{teamSlug}/rides")
public class RideResource {

    @POST
    @RolesAllowed("user")  // Must be authenticated
    public Response createRide(...) { }

    @GET
    @Path("/{rideSlug}")
    @PermitAll  // Public access (authorization checked in service)
    public Response getRide(...) { }
}
```

### User Resolution Flow

```
JWT Token → SecurityIdentity → email claim + domainId → UserService.lookupUserByEmailAndDomain() → User entity
```

The `PedalonsQueryContext` (request-scoped) handles this resolution lazily on first access. Note that email alone is not unique — the same email can exist on different domains, so user lookup always includes the domain.

Two additional resolution paths exist:
- **JWT domainId claim**: For clients (e.g. Garmin devices) that embed `domainId` in their JWT when HTTP headers don't resolve a domain
- **Cookie fallback**: Browser direct requests (file downloads, images) resolved via `refresh_token` cookie

---

## Authorization Layer

### Components

#### 1. @CheckAccess Annotation

Declarative annotation for method-level authorization:

```java
@CheckAccess(entityType = EntityType.RIDE, action = ActionType.CREATE)
public RideDto createRide(RideRequest request) { }
```

**Location:** `fr.pedalons.service.security.annotation.CheckAccess`

#### 2. CheckAccessInterceptor

Jakarta EE interceptor that enforces `@CheckAccess` annotations:

```java
@CheckAccess
@Interceptor
@Priority(Interceptor.Priority.APPLICATION)
public class CheckAccessInterceptor {
    @Inject PedalonsQueryContext context;
    @Inject SecurityVerifier securityVerifier;

    @AroundInvoke
    public Object check(InvocationContext ctx) throws Exception {
        CheckAccess ann = ctx.getMethod().getAnnotation(CheckAccess.class);
        if (ann != null) {
            Object[] parameters = ctx.getParameters();
            securityVerifier.verifyAccess(
                ann.entityType(),
                ann.action(),
                parameters == null ? List.of() : Arrays.asList(parameters)
            );
        }
        return ctx.proceed();
    }
}
```

**Location:** `fr.pedalons.service.security.interceptor.CheckAccessInterceptor`

#### 3. SecurityVerifier

Routes access checks to entity-specific AccessChecker implementations:

```java
@ApplicationScoped
public class SecurityVerifier {
    Map<EntityType, AccessChecker> accessCheckerMap;

    public void verifyAccess(EntityType entityType, ActionType action, List<Object> params) {
        if (!hasAccess(entityType, action, params)) {
            throw new ForbiddenException();
        }
    }

    protected boolean hasAccess(EntityType entityType, ActionType action, List<Object> params) {
        AccessChecker accessChecker = getAccessChecker(entityType);
        return accessChecker.hasRights(action, params);
    }
}
```

**Location:** `fr.pedalons.service.security.SecurityVerifier`

#### 4. PedalonsQueryContext

Request-scoped bean that resolves security context from JWT and builds `Context` objects:

```java
@RequestScoped
public class PedalonsQueryContext {
    // Resolved from JWT email claim (lazily initialized)
    @Nullable User user;

    // Build Context from method parameters (params[0] = teamSlug)
    public Context getContext(List<Object> params) {
        String teamSlug = getParam(params, 0);
        return getContext(teamSlug);
    }

    // Build Context from team slug
    public Context getContext(@Nullable String teamSlug) {
        Team team = teamSlug != null ? teamService.getTeam(teamSlug) : null;
        return getContext(team);
    }

    // Build full Context with user and teamRole
    public Context getContext(@Nullable Team team) {
        User user = getUserNullable();
        TeamRole teamRole = null;
        if (user != null && team != null) {
            teamRole = userTeamRepository
                .findByUserAndTeam(user.getId(), team.getId())
                .map(UserTeam::getRole)
                .orElse(null);
        }
        return new Context(team, user, teamRole);
    }
}
```

**Location:** `fr.pedalons.service.security.PedalonsQueryContext`

#### 5. Context Record

Immutable value object that packages security context:

```java
public record Context(@Nullable Team team, @Nullable User user, @Nullable TeamRole teamRole) {}
```

**Location:** `fr.pedalons.service.security.Context`

Created by `PedalonsQueryContext.getContext()` and used by AccessCheckers to make authorization decisions.

### AccessChecker Interface

Each entity type has a dedicated AccessChecker implementation:

```java
public interface AccessChecker {
    EntityType getType();

    boolean hasRights(ActionType action, List<Object> params);
}
```

**Location:** `fr.pedalons.service.security.AccessChecker`

AccessCheckers resolve their own security context by injecting `PedalonsQueryContext` and calling `getContext(params)`.

### AccessChecker Implementations

| Entity Type | AccessChecker | Location |
|-------------|---------------|----------|
| TEAM | TeamAccessChecker | `service/team/` |
| USER_TEAM | UserTeamAccessChecker | `service/team/` |
| RIDE | RideAccessChecker | `service/ride/` |
| POST | PostAccessChecker | `service/post/` |
| TRIP | TripAccessChecker | `service/trip/` |
| TRIP_STAGE | TripStageAccessChecker | `service/trip/` |
| ROUTE | RouteAccessChecker | `service/route/` |
| AD | AdAccessChecker | `service/ad/` |
| TEAM_PAGE | TeamPageAccessChecker | `service/page/` |
| ASSET | AssetAccessChecker | `service/asset/` |
| COMMENT | CommentAccessChecker | `service/comment/` |
| PLACE | PlaceAccessChecker | `service/place/` |
| RIDE_TEMPLATE | RideTemplateAccessChecker | `service/ridetemplate/` |
| CALENDAR | CalendarAccessChecker | `service/calendar/` |
| PUBLICATION | AllPublicationAccessChecker | `service/common/` |

### Action Types

```java
public enum ActionType {
    LIST,           // List entities (paginated)
    LIST_ALL_TEAMS, // List across all teams
    CREATE,         // Create new entity
    READ,           // Read single entity
    UPDATE,         // Modify entity
    DELETE,         // Soft-delete entity
    JOIN,           // Join participation (rides, trips)
    LEAVE           // Leave participation
}
```

### Team Roles

```java
public enum TeamRole {
    MEMBER,     // Basic team member
    ORGANIZER,  // Can create/edit content
    ADMIN       // Full team management
}
```

Role hierarchy: `ADMIN > ORGANIZER > MEMBER`

```java
// TeamRole methods (generated by Lombok @Getter)
teamRole.isMember()    // true for all roles
teamRole.isOrganizer() // true for ORGANIZER and ADMIN
teamRole.isAdmin()     // true for ADMIN only
```

---

## Data Access Control

### TeamEntityRepository

The `TeamEntityRepository` interface implements SQL-level security filtering for all team entities (Rides, Posts, Trips, Routes, Ads, TeamPages).

**Location:** `fr.pedalons.repository.common.TeamEntityRepository`

### Visibility Model

```java
public enum Visibility {
    TEAM,            // Team members only
    PUBLIC_UNLISTED, // Anyone with the URL, never in a cross-team listing
    PUBLIC           // Anyone can see, listed
}
```

Visibility is enforced at both entity and team level. For public access, neither the team nor the
entity may be `TEAM`; what `PUBLIC_UNLISTED` allows depends on the request
(`TeamEntityRepository.getPublicEntity`):

- **Direct read** (by slug): team and entity may each be `PUBLIC` or `PUBLIC_UNLISTED`.
- **Team-scoped listing** (the visitor is on that team's page): the team may be `PUBLIC_UNLISTED`,
  but the entity must be `PUBLIC` — unlisted entities stay out of lists.
- **Cross-team listing**: both must be `PUBLIC` — unlisted teams stay out of directories.

### Member names (API-144)

The names of a team's members never reach a caller who is not a member of that team (anonymous
visitors, people of no team, members of another team). "May see names" is `member || platformAdmin`,
the comments' rule. A non-member gets the **count only**: no name, avatar or user id. Concretely
`RideDto.topParticipants`, `RideGroupDto.participants` and `leader`, `TripDto.participants` come
back empty or null, `PostDto.createdBy` and `RouteDetailDto.createdBy` are null, and
`GET …/rides/{slug}/participants` and `GET …/trips/{slug}/participants` answer 401 (anonymous) or
403 (logged in, not a member), like comments. Membership is resolved once per page by
`MemberNamesVisibility` (one `findMemberTeamIds` query, none for anonymous or platform admins),
never per row. This supersedes "author-signed posts name the author to every reader" (API-6) and
"participants readable by whoever may read the ride" (API-12). Kept on purpose:
`InvitationPreviewDto.inviterName`.

### SQL Filtering Logic

#### Anonymous Users (not authenticated)

Shown for a cross-team listing; see the visibility rules above for the other cases.

```sql
SELECT te FROM [Entity] te WHERE
    te.team.visibility = 'PUBLIC'
    AND te.visibility = 'PUBLIC'
    AND te.status IN ('PUBLISHED', 'CANCELLED')
    AND TYPE(te) <> Ad  -- Ads require membership
    AND te.team.domain.id = :domainId  -- Multi-tenant isolation
    AND te.deleted = false
    AND te.team.deleted = false
```

#### Authenticated Users
The query uses OR clauses to allow access if ANY condition is met:

1. **Public Content:** Public team + public entity + published status
2. **Team Member:** Active membership + published/cancelled status
3. **Ad Creator:** Own ads (regardless of status)
4. **Organizer:** Team content except DRAFT TeamPages and Ads
5. **Admin:** All team content except DRAFT Ads

### Domain Isolation

All queries enforce multi-tenant isolation by filtering on the current domain:
```sql
AND te.team.domain.id = :domainId
```

### Soft Delete Enforcement

All queries automatically filter deleted entities:
```sql
AND te.deleted = false
AND te.team.deleted = false
```

### Feature Flag Checks

Team features are enforced in queries:
```sql
AND (TYPE(te) <> Trip OR te.team.enableTrips = true)
AND (TYPE(te) <> Ad OR te.team.enableAds = true)
```

---

## Permission Matrix

### Entity Permissions by Role

| Entity | Action | Anonymous | Member | Organizer | Admin |
|--------|--------|-----------|--------|-----------|-------|
| **Team** | LIST | Yes | Yes | Yes | Yes |
| | READ | Public only | Yes | Yes | Yes |
| | CREATE | No | Yes | Yes | Yes |
| | UPDATE | No | No | No | Yes |
| | DELETE | No | No | No | Yes |
| **Ride** | READ | Published+Public | Published | All except DRAFT | All |
| | CREATE | No | No | Yes | Yes |
| | UPDATE | No | No | Yes | Yes |
| | DELETE | No | No | Yes | Yes |
| | JOIN | No | Published only | Published only | Published only |
| **Post** | READ | Published+Public | Published | All except DRAFT | All |
| | CREATE | No | No | Yes | Yes |
| | UPDATE/DELETE | No | No | Yes | Yes |
| **Route** | READ | Published+Public | Published | All except DRAFT | All |
| | LIST_ALL_TEAMS | Yes | Yes | Yes | Yes |
| | CREATE | No | No | Yes | Yes |
| | UPDATE/DELETE | No | No | Yes | Yes |
| **Trip** | READ | Published+Public | Published | All except DRAFT | All |
| | CREATE | No | No | Yes | Yes |
| | JOIN | No | Published only | Published only | Published only |
| **Ad** | READ | No | Yes | Yes | Yes |
| | CREATE | No | Yes | Yes | Yes |
| | UPDATE/DELETE | No | Own only | Own only | Yes |
| **TeamPage** | READ | Published+Public | Published+Public | Published | All |
| | LIST/CREATE | No | No | No | Yes |
| | UPDATE/DELETE | No | No | No | Yes |
| **Asset** | CREATE | No | Yes | Yes | Yes |
| | READ | Depends on parent entity visibility |
| | UPDATE/DELETE | No | No | Yes | Yes |
| **Comment** | LIST/CREATE | No | Yes | Yes | Yes |
| | UPDATE/DELETE | No | Own only | Yes | Yes |
| **Calendar** | LIST_ALL_TEAMS | No | Yes (or token) | Yes (or token) | Yes (or token) |
| | LIST | No | Yes (or token) | Yes (or token) | Yes (or token) |
| | READ/CREATE/UPDATE/DELETE | No | Yes | Yes | Yes |

### Status-Based Access

| Status | Anonymous | Member | Organizer | Admin |
|--------|-----------|--------|-----------|-------|
| DRAFT | No | No | No | Yes (except Ads) |
| PUBLISHED | Yes (if public) | Yes | Yes | Yes |
| CANCELLED | Yes (if public) | Yes | Yes | Yes |

---

## Security Patterns

### Pattern 1: Service Method Authorization

Always use `@CheckAccess` on service methods that modify or read protected data:

```java
@ApplicationScoped
public class RideService {

    @CheckAccess(entityType = EntityType.RIDE, action = ActionType.CREATE)
    public RideDto createRide(RideRequest request) {
        // Implementation
    }

    @CheckAccess(entityType = EntityType.RIDE, action = ActionType.READ)
    public RideDto getDto(String rideSlug) {
        // Implementation
    }

    @CheckAccess(entityType = EntityType.RIDE, action = ActionType.UPDATE)
    public RideDto updateRide(String rideSlug, RideRequest request) {
        // Implementation
    }
}
```

### Pattern 2: Nested Entity Access

For entities attached to parent entities (Assets, Comments), verify parent access:

```java
@Override
public boolean hasRights(ActionType action, List<Object> params) {
    Context context = pedalonsContext.getContext(params);
    Team team = context.team();

    // ... get parent entity
    TeamEntity parent = asset.getTeamEntity();

    // Delegate to parent's AccessChecker
    securityVerifier.verifyAccess(
        parent.getEntityType(),
        ActionType.READ,
        List.of(team.getSlug(), parent.getSlug())
    );
    return true;
}
```

### Pattern 3: Owner-Based Access

For user-created content (Ads, Comments), allow owner modifications:

```java
case UPDATE, DELETE -> {
    User user = context.user();
    TeamRole teamRole = context.teamRole();
    boolean isOwner = user != null && entity.getCreatedBy().getId().equals(user.getId());
    boolean isPrivileged = teamRole != null && teamRole.isOrganizer();
    yield isOwner || isPrivileged;
}
```

### Pattern 4: Status-Gated Actions

For participatory actions, verify entity status:

```java
case JOIN, LEAVE -> {
    String slug = pedalonsContext.getParam(params, 1);
    Ride ride = rideService.findBySlug(team, slug);
    // Only allow joining published rides, must be team member
    yield teamRole != null && ride.getStatus() == Status.PUBLISHED;
}
```

---

## Request Filters

Three JAX-RS filters run before the resource method, in `fr.pedalons.service.security`:

| Filter | Applies to | What it does |
|--------|-----------|--------------|
| `CrossSiteRequestFilter` | Every request carrying the `refresh_token` cookie and no bearer | Rejects cross-site state-changing requests. The cookie is `SameSite=Lax` (the SSR server must read it on a document request from an external link), so this filter is the CSRF choke point for the cookie-authenticated endpoints |
| `TileTokenFilter` | Methods annotated `@TileTokenAuth` | Turns a valid `?t=` tile token (short-lived, see `TileTokenService`) into claims `PedalonsQueryContext` picks up. MapLibre fetches tiles itself and cannot send a header |
| `BiketeamM2MFilter` | Methods annotated `@BiketeamM2M` | Checks `X-Biketeam-Migration-Secret` (constant-time) on `/api/internal/biketeam-migration`; a bare 404 when the feature is disabled |

The two name-bound filters are narrow on purpose: the token or secret authenticates only the methods
carrying the annotation, nothing else.

---

## Moderation

Members report content and other members (`fr.pedalons.service.moderation`). A report is filed in a team,
and only about something the reporter can read there — anything else is a 404. The reporter stops
seeing the target at once; at `ReportService.AUTO_HIDE_REPORTERS` (3) distinct reporters the content
is hidden from every member but the team's moderators until one of them decides
(`ModerationService`). Moderators are the team's organizers and admins, plus platform admins; a
moderator never sees nor decides a report that targets them. Members can also block another user
(`UserBlockService`).

---

## Developer Guidelines

### Adding a New Entity Type

1. **Create AccessChecker implementation:**
```java
@ApplicationScoped
public class MyEntityAccessChecker implements AccessChecker {
    @Inject PedalonsQueryContext pedalonsContext;
    @Inject MyEntityService myEntityService;

    @Override
    public EntityType getType() {
        return EntityType.MY_ENTITY;
    }

    @Override
    public boolean hasRights(ActionType action, List<Object> params) {
        Context context = pedalonsContext.getContext(params);
        Team team = context.team();
        User user = context.user();
        TeamRole teamRole = context.teamRole();

        return switch (action) {
            case CREATE -> teamRole != null && teamRole.isOrganizer();
            case READ -> {
                String slug = pedalonsContext.getParam(params, 1);
                myEntityService.findBySlug(team, slug); // throws 404 if not found
                yield true; // SQL filtering handles visibility
            }
            case UPDATE, DELETE -> teamRole != null && teamRole.isOrganizer();
            case LIST, LIST_ALL_TEAMS, JOIN, LEAVE -> false;
        };
    }
}
```

2. **Add EntityType enum value** in `fr.pedalons.enums.EntityType`

3. **Annotate service methods:**
```java
@CheckAccess(entityType = EntityType.MY_ENTITY, action = ActionType.CREATE)
public MyEntityDto create(String teamSlug, MyEntityRequest request) { }

@CheckAccess(entityType = EntityType.MY_ENTITY, action = ActionType.READ)
public MyEntityDto getDto(String teamSlug, String entitySlug) { }
```

Note: Method parameters are passed to the AccessChecker. The first parameter should be `teamSlug` for team-scoped entities.

4. **If extending TeamEntity,** SQL filtering is automatic via `TeamEntityRepository`

### Security Checklist for New Endpoints

- [ ] REST endpoint has `@RolesAllowed` or `@PermitAll`
- [ ] Service methods have `@CheckAccess` annotations
- [ ] AccessChecker handles all relevant ActionTypes
- [ ] For TeamEntity subclasses, repository extends `TeamEntityRepository`
- [ ] Soft-delete is respected (`deleted = false` filtering)
- [ ] Feature flags are checked if applicable

### Common Mistakes to Avoid

1. **Missing @CheckAccess:** Always annotate service methods, not just REST endpoints
2. **Wrong ActionType:** Use DELETE for deletion, not CREATE
3. **Forgetting status checks:** JOIN/LEAVE should verify PUBLISHED status
4. **Ignoring visibility:** READ access should consider entity visibility, not just existence
5. **Direct repository access:** Use service methods to ensure security checks are applied

### Testing Security

```java
@QuarkusTest
class RideSecurityTest {

    @Test
    void nonMemberCannotCreateRide() {
        // Setup: user not member of team
        given()
            .auth().oauth2(userToken)
            .contentType(ContentType.JSON)
            .body(rideRequest)
        .when()
            .post("/api/teams/{teamSlug}/rides", teamSlug)
        .then()
            .statusCode(403);
    }

    @Test
    void memberCannotUpdateOthersRide() {
        // Only organizers can update rides
    }
}
```

---

## Security Contact

For security vulnerabilities or concerns, contact the development team directly.

---

*Document Version: 1.3*
*Last Updated: September 2026*
*Updated: PUBLIC_UNLISTED visibility, password auth, `@Public` and name-bound annotations, request filters, moderation*
