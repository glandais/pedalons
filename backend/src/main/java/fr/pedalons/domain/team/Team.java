package fr.pedalons.domain.team;

import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.common.NotNullableDbValue;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Visibility;
import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.hibernate.annotations.Formula;
import org.hibernate.annotations.SQLRestriction;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@Table(
    name = "teams",
    indexes = {@Index(columnList = "slug, deleted"), @Index(columnList = "domain_id, deleted")},
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_teams_domain_slug",
          columnNames = {"domain_id", "slug"})
    })
@NoArgsConstructor
public class Team extends BaseEntity {

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @Column(name = "name", nullable = false, length = 250)
  private String name;

  @Column(name = "slug", nullable = false, length = 250)
  private String slug;

  @Enumerated(EnumType.STRING)
  @Column(name = "visibility", nullable = false, length = 20)
  private Visibility visibility = Visibility.TEAM;

  /**
   * LAZY on purpose: only {@code TeamDetailDto} renders the about page, but a Team is loaded by
   * every publication and route list row for its name and slug. EAGER made all of those pay for a
   * TeamPage — with its markdown and assets — that they never look at.
   */
  @ManyToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
  @JoinColumn(name = "description_id")
  @NotNullableDbValue
  private TeamPage aboutPage;

  /**
   * Id of the logo on the about page, read in the same SELECT as the team itself.
   *
   * <p>Every publication list row carries its team ({@code TeamPublicationDto}) and, since API
   * 5.8.0, the team's logo. Walking {@link #aboutPage} and its assets for that would undo why the
   * about page is LAZY; a lookup map would have to be threaded through a dozen DTO factories. A
   * formula costs no statement and no entity: it rides along whenever a Team is loaded, batched or
   * not (docs/LEDGER_*.md API-2). {@code min} rather than a {@code limit}: a team holds at most one
   * logo, and an aggregate keeps the subquery scalar.
   *
   * <p>Read-only and computed at load: an entity loaded before its logo changed keeps the old value
   * for the rest of that request.
   */
  @Formula(
      "(select min(a.id) from assets a where a.team_entity_id = description_id"
          + " and a.type = 'LOGO')")
  @Setter(AccessLevel.NONE)
  @Nullable
  private Long logoAssetId;

  /**
   * File id of the logo, the cache-buster of its image URL ({@code ?v=}); same row as {@link
   * #logoAssetId}. docs/LEDGER_*.md API-128.
   */
  @Formula(
      "(select a.file_id from assets a where a.id = (select min(l.id) from assets l"
          + " where l.team_entity_id = description_id and l.type = 'LOGO'))")
  @Setter(AccessLevel.NONE)
  @Nullable
  private Long logoFileId;

  /**
   * Visibility of the about page, which is what an image URL of one of its assets encodes (see
   * {@code AssetService.getImageUrl}). Loaded with {@link #logoAssetId}, for the same reason.
   */
  @Formula("(select te.visibility from team_entities te where te.id = description_id)")
  @Setter(AccessLevel.NONE)
  @Nullable
  private String aboutPageVisibility;

  @OneToMany(mappedBy = "team")
  @SQLRestriction("is_about_page = false AND deleted = false")
  @OrderBy("pageOrder ASC")
  private List<TeamPage> additionalPages = new ArrayList<>();

  @OneToMany(mappedBy = "team", cascade = CascadeType.ALL, orphanRemoval = true)
  private Set<UserTeam> members = new HashSet<>();

  @Column(name = "enable_trips", nullable = false)
  private boolean enableTrips = true;

  @Column(name = "enable_ads", nullable = false)
  private boolean enableAds = true;

  @Column(name = "enable_posts", nullable = false)
  private boolean enablePosts = true;

  @Column(name = "enable_rides", nullable = false)
  private boolean enableRides = true;

  @Column(name = "enable_routes", nullable = false)
  private boolean enableRoutes = true;

  /**
   * Whether the member directory is open beyond the team's administrators. Off by default, and the
   * only {@code enable*} flag that is: switching it on discloses the whole roster to every member,
   * so it has to be an explicit act rather than something a migration does on a team's behalf.
   *
   * <p>Organisers see the directory whatever its value — they need a member list to designate a ride
   * group's leader. What the flag withholds from them is {@code role} and {@code joinedAt}.
   */
  @Column(name = "enable_member_directory", nullable = false)
  private boolean enableMemberDirectory = false;

  /**
   * Whether a new post is signed by the team rather than by its author — the value the editor's
   * « Au nom de l'équipe » box starts from; each post then keeps its own {@link
   * fr.pedalons.domain.post.Post#isSignedAsTeam()}. On by default: posts were never signed before,
   * and a team starts showing names by choosing to. docs/LEDGER_*.md API-6.
   */
  @Column(name = "posts_as_team_by_default", nullable = false)
  private boolean postsAsTeamByDefault = true;

  @Column(name = "geometry", columnDefinition = "geometry(Point,4326)")
  @Nullable
  private Point<G2D> geometry;

  @Column(name = "visibility_editable", nullable = false)
  private boolean visibilityEditable = false;

  @Column(name = "joinable", nullable = false)
  private boolean joinable = false;

  @Column(name = "add_member_allowed", nullable = false)
  private boolean addMemberAllowed = false;

  /**
   * Whether the interactive route planner (draw a track on the map) is open to this team. Off by
   * default and platform-admin only: unlike {@code enableRoutes}, it does not hide the routes
   * section — GPX import, replacement and download stay available when it is false.
   */
  @Column(name = "enable_route_planner", nullable = false)
  private boolean enableRoutePlanner = false;

  @Column(name = "deleted", nullable = false)
  private boolean deleted = false;

  /**
   * The team's IANA zone: the one its rides, trips and posts fall back on when no start place or
   * route locates them, and the zone of everything else it publishes (docs/LEDGER_*.md API-60).
   * Validated by {@code ZoneId.of} on the way in. The initializer matters: it runs before the
   * constructor builds the about page, which copies it.
   */
  @Column(name = "timezone", nullable = false, length = 64)
  private String timezone = DEFAULT_TIMEZONE;

  /** Every team that existed before docs/LEDGER_*.md API-60 is French. */
  public static final String DEFAULT_TIMEZONE = "Europe/Paris";

  public Team(Domain domain, User creator, String name, String slug, Visibility visibility) {
    super(creator);
    this.domain = domain;
    this.name = name;
    this.slug = slug;
    this.visibility = visibility;
    this.aboutPage = TeamPage.createAboutPage(creator, this, visibility);
  }
}
