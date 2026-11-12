package fr.pedalons.service.admin;

import fr.pedalons.common.LikePatterns;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.admin.AdminUserDto;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.PlatformRole;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Admin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AdminUserService {

  @Inject UserRepository userRepository;
  @Inject PedalonsQueryContext pedalonsContext;

  @Admin
  public PedalonsPage<AdminUserDto> listUsers(
      @Nullable String domainId,
      @Nullable String search,
      @Nullable Boolean adminOnly,
      int page,
      int size) {
    StringBuilder queryBuilder = new StringBuilder("deleted = false");
    java.util.List<Object> params = new java.util.ArrayList<>();
    int paramIndex = 1;

    if (domainId != null) {
      Long domainIdLong = TsidUtils.toLong(domainId);
      queryBuilder.append(" and domain.id = ?").append(paramIndex++);
      params.add(domainIdLong);
    }

    if (search != null && !search.isBlank()) {
      queryBuilder
          .append(" and (LOWER(email) LIKE LOWER(?")
          .append(paramIndex)
          .append(") ")
          .append(LikePatterns.ESCAPE);
      queryBuilder
          .append(" or LOWER(displayName) LIKE LOWER(?")
          .append(paramIndex)
          .append(") ")
          .append(LikePatterns.ESCAPE)
          .append(")");
      params.add(LikePatterns.contains(search.trim()));
      paramIndex++;
    }

    if (adminOnly != null && adminOnly) {
      queryBuilder.append(" and platformRole = ?").append(paramIndex++);
      params.add(PlatformRole.PLATFORM_ADMIN);
    }

    String query = queryBuilder.toString();
    Object[] paramsArray = params.toArray();

    List<User> users =
        userRepository
            .find(query + " order by createdAt desc, id desc", paramsArray)
            .page(page, size)
            .list();
    long total = userRepository.count(query, paramsArray);

    List<AdminUserDto> items = users.stream().map(AdminUserDto::from).toList();

    return new PedalonsPage<>(items, total);
  }

  @Admin
  public AdminUserDto getUser(String userId) {
    User user = findUser(userId);
    return AdminUserDto.from(user);
  }

  @Admin
  @Transactional
  public AdminUserDto assignPlatformRole(String userId, @Nullable PlatformRole role) {
    User user = findUser(userId);
    // An admin cannot take their own role away: a platform whose last admin demoted themselves
    // would have no one left to manage it. The UI disables the button; this is the rule.
    if (user.getId().equals(pedalonsContext.getUserId())
        && user.getPlatformRole() == PlatformRole.PLATFORM_ADMIN
        && role != PlatformRole.PLATFORM_ADMIN) {
      throw new ForbiddenException();
    }
    user.setPlatformRole(role);
    userRepository.persist(user);
    return AdminUserDto.from(user);
  }

  private User findUser(String userId) {
    Long id = TsidUtils.toLong(userId);
    return userRepository.findActiveByIdOnAnyDomain(id).orElseThrow(NotFoundException::new);
  }
}
