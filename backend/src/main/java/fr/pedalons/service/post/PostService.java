package fr.pedalons.service.post;

import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.posts.request.PostRequest;
import fr.pedalons.dto.posts.response.PostDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.repository.post.PostRepository;
import fr.pedalons.service.comment.CommentCountLookup;
import fr.pedalons.service.common.TeamEntityService;
import fr.pedalons.service.notification.NotificationPublisher;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.ZoneId;
import java.util.List;

@ApplicationScoped
public class PostService extends TeamEntityService<Post, PostRepository, PostDto> {

  @Inject PostRepository postRepository;

  @Inject CommentCountLookup commentCountLookup;

  @Inject NotificationPublisher notificationPublisher;

  @Inject PostAuthorLookup postAuthorLookup;

  @Inject TagService tagService;

  @Inject TagLookup tagLookup;

  @Override
  protected PostRepository getRepository() {
    return postRepository;
  }

  @Override
  protected PostDto toDto(Post entity) {
    return PostDto.from(
        entity,
        assetService,
        commentCountLookup.forEntity(entity),
        postAuthorLookup.forPost(entity),
        tagLookup.forContents(List.of(entity.getId())),
        detailPermissions(entity));
  }

  @Override
  public Post findBySlug(Team team, String entitySlug) {
    return super.findBySlug(team, entitySlug);
  }

  @CheckAccess(entityType = EntityType.POST, action = ActionType.READ)
  public PostDto getDto(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.getDto(team, entitySlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.POST, action = ActionType.CREATE)
  public PostDto createPost(String teamSlug, PostRequest request) {
    Team team = teamService.getTeam(teamSlug);
    validateVisibility(team, request);

    // Generate slug from name, ensure unique within team
    String slug = slugService.generateSlug(request.name(), team.getId(), postRepository);

    // A post has no place: its wall times are the team's (docs/LEDGER_*.md API-60).
    ZoneId zone = EventTimezoneResolver.teamZone(team);
    Post post =
        new Post(
            pedalonsContext.getUser(),
            team,
            request.dateTime().toInstant(zone),
            request.name(),
            slug,
            request.visibility());
    post.setTimezone(zone.getId());
    post.setStatus(request.status());
    if (request.status() == Status.DRAFT) {
      post.setPublishAt(EventDateTime.toInstant(request.publishAt(), zone));
    } else {
      post.setPublishAt(null);
    }
    post.setSignedAsTeam(
        request.signedAsTeam() != null ? request.signedAsTeam() : team.isPostsAsTeamByDefault());

    postRepository.persistAndFlush(post);

    updateMedia(post, request.media());
    tagService.replaceTags(post, request.tagIds());

    postRepository.persist(post);
    notificationPublisher.publicationStatusChanged(post, null, post.getCreatedBy());

    return written(post);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.POST, action = ActionType.UPDATE)
  public PostDto updatePost(String teamSlug, String postSlug, PostRequest request) {
    Team team = teamService.getTeam(teamSlug);
    Post post = findBySlug(team, postSlug);
    Status previousStatus = post.getStatus();

    validateVisibility(team, request);

    post.setVisibility(request.visibility());

    post.setName(request.name());
    // The zone is the one of this save, frozen with it (docs/LEDGER_*.md API-60).
    ZoneId zone = EventTimezoneResolver.teamZone(team);
    post.setTimezone(zone.getId());
    post.setDateTime(request.dateTime().toInstant(zone));
    post.setStatus(request.status());
    if (request.status() == Status.DRAFT) {
      post.setPublishAt(EventDateTime.toInstant(request.publishAt(), zone));
    } else {
      post.setPublishAt(null);
    }
    if (request.signedAsTeam() != null) {
      post.setSignedAsTeam(request.signedAsTeam());
    }

    updateMedia(post, request.media());
    tagService.replaceTags(post, request.tagIds());

    postRepository.persist(post);
    notificationPublisher.publicationStatusChanged(post, previousStatus, pedalonsContext.getUser());

    return written(post);
  }

  /** Changes the status alone, with the side effects of a status change through the update. */
  @Transactional
  @CheckAccess(entityType = EntityType.POST, action = ActionType.UPDATE)
  public PostDto updateStatus(String teamSlug, String postSlug, Status status) {
    Team team = teamService.getTeam(teamSlug);
    Post post = findBySlug(team, postSlug);
    Status previousStatus = post.getStatus();
    post.setStatus(status);
    if (status != Status.DRAFT) {
      post.setPublishAt(null);
    }
    postRepository.persist(post);
    notificationPublisher.publicationStatusChanged(post, previousStatus, pedalonsContext.getUser());
    return written(post);
  }

  @CheckAccess(entityType = EntityType.POST, action = ActionType.UPDATE)
  @Transactional
  public PostDto updateSlug(String teamSlug, String slug, String newSlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.updateSlug(team, slug, newSlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.POST, action = ActionType.DELETE)
  public void deletePost(String teamSlug, String postSlug) {
    Team team = teamService.getTeam(teamSlug);
    Post post = findBySlug(team, postSlug);

    post.setDeleted(true);
    postRepository.persist(post);
  }

  @CheckAccess(entityType = EntityType.POST, action = ActionType.DELETE)
  @Transactional
  public PostDto undeletePost(String teamSlug, String postSlug) {
    Team team = teamService.getTeam(teamSlug);
    Post post = findBySlugIncludeDeleted(team, postSlug);
    requireNotRemovedByModeration(post);
    post.setDeleted(false);
    postRepository.persist(post);
    return written(post);
  }

  /** What a write answers: the post as its writer sees it, without a comment count as before. */
  private PostDto written(Post post) {
    return PostDto.from(
        post,
        assetService,
        CommentCounts.NONE,
        postAuthorLookup.forPost(post),
        tagLookup.forContents(List.of(post.getId())),
        detailPermissions(post));
  }
}
