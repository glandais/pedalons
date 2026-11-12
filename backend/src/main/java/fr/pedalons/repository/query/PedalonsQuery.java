package fr.pedalons.repository.query;

import java.util.HashMap;
import java.util.Map;
import org.jspecify.annotations.Nullable;

public class PedalonsQuery {

  private final String baseQuery;
  private final AndClause clause = new AndClause();
  private final Map<String, @Nullable Object> params = new HashMap<>();
  private @Nullable String order = null;
  private final Map<String, @Nullable Object> orderParams = new HashMap<>();
  private @Nullable String groupBy = null;

  public PedalonsQuery() {
    this("");
  }

  public PedalonsQuery(String baseQuery) {
    this.baseQuery = baseQuery;
  }

  public PedalonsQuery and(String clause, Map<String, @Nullable Object> params) {
    this.and(new SimpleClause(clause, params));
    return this;
  }

  public PedalonsQuery and(Clause clause) {
    this.clause.add(clause);
    return this;
  }

  public PedalonsQuery addParam(String key, @Nullable Object value) {
    params.put(key, value);
    return this;
  }

  public PedalonsQuery order(String order) {
    this.order = order;
    this.orderParams.clear();
    return this;
  }

  /**
   * An ordering that reads bound parameters — an expression of the request's instant, say. They
   * belong to the ordering: {@link #noOrder} and the next {@link #order} drop them with it, so an
   * aggregate projection is never handed a parameter its statement no longer names.
   */
  public PedalonsQuery order(String order, Map<String, @Nullable Object> params) {
    this.order = order;
    this.orderParams.clear();
    this.orderParams.putAll(params);
    return this;
  }

  /**
   * Drops any ordering already installed. An aggregate projection must not carry an {@code ORDER BY}
   * on a column it does not select, and a repository hook (a sort filter, an ascending flag) has no
   * way to know it is being asked for a count rather than for a page.
   */
  public PedalonsQuery noOrder() {
    this.order = null;
    this.orderParams.clear();
    return this;
  }

  /**
   * Groups the result, for a projection that aggregates per key rather than counting the whole
   * match — one row per team, say, instead of one query per team.
   *
   * <p>Only meaningful with a {@code QueryShape} whose projection selects the same key; the
   * visibility clauses are untouched either way, which is the point of going through here rather
   * than writing the aggregate by hand.
   */
  public PedalonsQuery groupBy(String groupBy) {
    this.groupBy = groupBy;
    return this;
  }

  public String getStringQuery() {
    return String.join(
        " ",
        baseQuery,
        clause.clause(),
        groupBy != null ? " group by " + groupBy : "",
        order != null ? " order by " + order : "");
  }

  public Map<String, @Nullable Object> getParams() {
    Map<String, @Nullable Object> allParams = new HashMap<>(params);
    allParams.putAll(this.clause.params());
    allParams.putAll(orderParams);
    return allParams;
  }
}
