package fr.pedalons.service.comment;

import fr.pedalons.domain.comment.Comment;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.repository.comment.CommentRepository;
import fr.pedalons.service.security.AccessChecker;
import fr.pedalons.service.security.Context;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class CommentAccessChecker implements AccessChecker {

  @Inject CommentService commentService;
  @Inject CommentRepository commentRepository;
  @Inject PedalonsQueryContext pedalonsContext;

  @Override
  public EntityType getType() {
    return EntityType.COMMENT;
  }

  @Override
  public boolean hasRights(ActionType action, List<Object> params) {

    Context context = pedalonsContext.getContext(params);
    Team team = context.team();
    User user = context.user();
    TeamRole teamRole = context.teamRole();

    if (team == null || user == null || !canComment(teamRole)) {
      return false;
    }

    return switch (action) {
      case LIST, READ, CREATE -> true;
      case UPDATE, DELETE -> {
        if (params.size() < 4) {
          yield false;
        }
        String slug = pedalonsContext.getParam(params, 1);
        EntityType entityType = pedalonsContext.getParam(params, 2);
        Long commentId = pedalonsContext.getParam(params, 3);
        TeamEntity teamEntity = commentService.getTeamEntity(team, slug, entityType);
        Comment comment = commentRepository.findByTeamIdAndId(team.getId(), commentId).orElse(null);
        if (comment == null) {
          yield false;
        }
        if (!comment.getTeamEntity().getId().equals(teamEntity.getId())) {
          yield false;
        }
        if (teamRole.isOrganizer()) {
          yield true;
        }
        yield comment.getCreatedBy().getId().equals(user.getId());
      }
      case LIST_ALL_TEAMS, JOIN, LEAVE -> false;
    };
  }

  /**
   * Reading and writing the comments of a team's content: a member of the team, whatever the
   * content's visibility. Shared with the permissions block ({@code ContentPermissions},
   * docs/LEDGER_*.md API-176), which also reports it as {@code canSeeParticipants}: the same
   * {@code member || platformAdmin} rule as the member names (API-144). The platform admin's bypass
   * is {@code SecurityVerifier}'s.
   */
  public static boolean canComment(@Nullable TeamRole teamRole) {
    return teamRole != null;
  }
}
