package fr.pedalons.repository.limits;

import fr.pedalons.domain.limits.RouterDailyCall;
import io.hypersistence.tsid.TSID;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.LocalDate;
import java.util.List;

@ApplicationScoped
public class RouterDailyCallRepository implements PanacheRepository<RouterDailyCall> {

  /**
   * Counts one more calculation for {@code userId} on {@code day}, unless the day already holds
   * {@code cap} of them. One statement, so concurrent calls — on any backend — never both take the
   * last one.
   *
   * @return whether the call was admitted
   */
  public boolean admit(Long userId, LocalDate day, int cap) {
    @SuppressWarnings("unchecked")
    List<Object> admitted =
        getEntityManager()
            .createNativeQuery(
                """
                insert into router_daily_calls (id, user_id, day, calls)
                values (:id, :userId, :day, 1)
                on conflict (user_id, day) do update
                  set calls = router_daily_calls.calls + 1
                  where router_daily_calls.calls < :cap
                returning calls
                """)
            .setParameter("id", TSID.Factory.getTsid().toLong())
            .setParameter("userId", userId)
            .setParameter("day", day)
            .setParameter("cap", cap)
            .getResultList();
    return !admitted.isEmpty();
  }

  /** Deletes the counters of the days before {@code before}; idempotent. */
  public long purgeBefore(LocalDate before) {
    return delete("day < ?1", before);
  }
}
