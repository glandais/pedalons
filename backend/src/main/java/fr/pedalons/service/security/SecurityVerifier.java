package fr.pedalons.service.security;

import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.jboss.logging.Logger;

@ApplicationScoped
public class SecurityVerifier {

  private static final Logger LOG = Logger.getLogger(SecurityVerifier.class);

  @Inject Instance<AccessChecker> accessCheckers;

  @Inject PedalonsQueryContext pedalonsContext;

  final Map<EntityType, AccessChecker> accessCheckerMap = new EnumMap<>(EntityType.class);

  @PostConstruct
  void init() {
    accessCheckers.forEach(
        accessChecker -> accessCheckerMap.put(accessChecker.getType(), accessChecker));
  }

  AccessChecker getAccessChecker(EntityType type) {
    AccessChecker accessChecker = accessCheckerMap.get(type);
    if (accessChecker == null) {
      LOG.infov("No AccessChecker for " + type);
      throw new ForbiddenException();
    }
    return accessChecker;
  }

  public void verifyAccess(EntityType entityType, ActionType action, List<Object> params) {
    if (!hasAccess(entityType, action, params)) {
      throw new ForbiddenException();
    }
  }

  /** As {@link #verifyAccess}, answering instead of throwing: for a field shown to some callers. */
  public boolean canAccess(EntityType entityType, ActionType action, List<Object> params) {
    return hasAccess(entityType, action, params);
  }

  protected boolean hasAccess(EntityType entityType, ActionType action, List<Object> params) {
    User userNullable = pedalonsContext.getUserNullable();
    if (userNullable != null && userNullable.isPlatformAdmin()) {
      return true;
    }
    AccessChecker accessChecker = getAccessChecker(entityType);
    return accessChecker.hasRights(action, params);
  }
}
