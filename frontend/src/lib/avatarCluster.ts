/** Who an avatar cluster shows (`UserAvatarGroup`, docs/LEDGER_*.md WEB-167 R5). */

/** The faces a cluster shows, and how many it stands for, without `excludeId`. */
export function clusterFaces<T extends { id: string }>(
  users: T[],
  total: number | undefined,
  excludeId?: string
): { faces: T[]; total: number } {
  const faces = excludeId ? users.filter((user) => user.id !== excludeId) : users
  return { faces, total: (total ?? users.length) - (users.length - faces.length) }
}

/** Whether a cluster of `max` faces ends on a « +N »: then a « Voir tout » goes beside it. */
export function clusterHidesSomeone(
  users: Array<{ id: string }>,
  total: number | undefined,
  max = 5,
  excludeId?: string
): boolean {
  const cluster = clusterFaces(users, total, excludeId)
  return cluster.total > Math.min(cluster.faces.length, max)
}
