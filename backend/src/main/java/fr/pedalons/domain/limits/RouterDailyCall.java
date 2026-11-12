package fr.pedalons.domain.limits;

import io.hypersistence.utils.hibernate.id.Tsid;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * The route calculations of one user on one UTC day (docs/LEDGER_*.md BILL-10): the counter of the
 * daily routing cap. Written by an upsert only ({@code RouterDailyCallRepository#admit}); mapped so
 * that the test schema has the table and its unique key.
 */
@Getter
@Entity
@Table(
    name = "router_daily_calls",
    uniqueConstraints =
        @UniqueConstraint(
            name = "uk_router_daily_calls_user_day",
            columnNames = {"user_id", "day"}))
@NoArgsConstructor
public class RouterDailyCall {

  @Id @Tsid private Long id;

  @Column(name = "user_id", nullable = false)
  private Long userId;

  @Column(name = "day", nullable = false)
  private LocalDate day;

  @Column(name = "calls", nullable = false)
  private int calls;
}
