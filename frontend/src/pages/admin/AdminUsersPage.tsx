import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Stack,
  Table,
  Badge,
  Group,
  Text,
  Skeleton,
  Alert,
  ActionIcon,
  Tooltip,
  Paper,
  Center,
  Select,
  Checkbox,
} from '@mantine/core'
import { IconUsers, IconShieldCheck, IconShieldOff } from '@tabler/icons-react'
import { AdminLayout } from '@/components/admin/AdminLayout'
import { SearchInput } from '@/components/common/SearchInput'
import { Pagination } from '@/components/common/Pagination'
import { useQueryClient } from '@tanstack/react-query'
import {
  getListUsersQueryKey,
  useAssignPlatformRole,
} from '@/api/endpoints/admin-users/admin-users'
import { useListDomains } from '@/api/endpoints/admin-domains/admin-domains'
import type { AdminUserDto } from '@/api/dto'
import { useAuth } from '@/hooks/useAuth'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'
import { adminUserFiltersSchema, adminUserFiltersAlias } from '@/hooks/filters/adminFilters'
import { FormattedDate } from '@/components/common/FormattedDate'
import { useAdminUsersData } from './adminUsersData'
import { ADMIN_DOMAIN_FILTER_PARAMS } from './adminTeamsData'

export function AdminUsersPage() {
  const { t } = useTranslation()
  const { user: currentUser } = useAuth()

  const { filters, setFilters } = useUrlFilters({
    schema: adminUserFiltersSchema,
    alias: adminUserFiltersAlias,
  })
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const { data: domainsData } = useListDomains(ADMIN_DOMAIN_FILTER_PARAMS)
  const { data, isLoading, error } = useAdminUsersData(filters)
  const assignRoleMutation = useAssignPlatformRole()
  const queryClient = useQueryClient()

  const handleTogglePlatformAdmin = (userId: string, currentRole: string | null | undefined) => {
    const newRole = currentRole === 'PLATFORM_ADMIN' ? undefined : 'PLATFORM_ADMIN'
    assignRoleMutation.mutate(
      { userId, data: { role: newRole } },
      { onSuccess: () => queryClient.invalidateQueries({ queryKey: getListUsersQueryKey() }) }
    )
  }

  const totalPages = data ? Math.ceil(data.total / filters.size) : 0

  // Tooltip and accessible name alike: the icon alone says nothing to a screen reader.
  const roleActionLabel = (userId: string, role: string | null | undefined) =>
    userId === currentUser?.id && role === 'PLATFORM_ADMIN'
      ? t('admin.users.cannotRemoveOwnAdmin')
      : role === 'PLATFORM_ADMIN'
        ? t('admin.users.removeAdmin')
        : t('admin.users.makeAdmin')

  const domainOptions =
    domainsData?.domains.map((d) => ({
      value: d.id,
      label: d.name,
    })) || []

  return (
    <AdminLayout currentTab="users">
      <Stack mt="lg">
        <Group align="flex-end" wrap="wrap">
          <SearchInput
            id="user-search"
            value={search}
            onChange={setSearch}
            placeholder={t('admin.users.searchPlaceholder')}
            label={t('admin.users.search')}
            style={{ flex: 1, minWidth: 200 }}
          />
          <Select
            label={t('admin.users.domain')}
            placeholder={t('admin.users.allDomains')}
            data={domainOptions}
            value={filters.domainId ?? null}
            onChange={(value) => setFilters({ domainId: value || undefined })}
            clearable
            w={200}
          />
          <Checkbox
            label={t('admin.users.adminOnly')}
            checked={filters.adminOnly}
            onChange={(e) => setFilters({ adminOnly: e.currentTarget.checked })}
          />
        </Group>

        {error && (
          <Alert color="red">
            {error instanceof Error ? error.message : t('errors.api.failedToLoad')}
          </Alert>
        )}

        {isLoading ? (
          <Stack>
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} height={50} />
            ))}
          </Stack>
        ) : data && data.users.length > 0 ? (
          <Stack>
            <Table.ScrollContainer ref={listTopRef} minWidth={800}>
              <Table striped highlightOnHover>
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th>{t('admin.users.email')}</Table.Th>
                    <Table.Th>{t('admin.users.displayName')}</Table.Th>
                    <Table.Th>{t('admin.users.domain')}</Table.Th>
                    <Table.Th ta="center">{t('admin.users.emailVerified')}</Table.Th>
                    <Table.Th ta="center">{t('admin.users.platformRole')}</Table.Th>
                    <Table.Th>{t('admin.users.createdAt')}</Table.Th>
                    <Table.Th ta="center">{t('admin.users.actions')}</Table.Th>
                  </Table.Tr>
                </Table.Thead>
                <Table.Tbody>
                  {data.users.map((user: AdminUserDto) => (
                    <Table.Tr key={user.id}>
                      <Table.Td>
                        <Text size="sm">{user.email}</Text>
                      </Table.Td>
                      <Table.Td>
                        <Text fw={500}>{user.displayName}</Text>
                      </Table.Td>
                      <Table.Td>
                        <Text size="sm" c="dimmed">
                          {user.domainName}
                        </Text>
                      </Table.Td>
                      <Table.Td ta="center">
                        <Badge color={user.emailVerified ? 'green' : 'gray'} size="sm">
                          {user.emailVerified
                            ? t('admin.users.verified')
                            : t('admin.users.unverified')}
                        </Badge>
                      </Table.Td>
                      <Table.Td ta="center">
                        {user.platformRole === 'PLATFORM_ADMIN' && (
                          <Badge color="blue">{t('admin.users.platformAdmin')}</Badge>
                        )}
                      </Table.Td>
                      <Table.Td>
                        <Text size="sm" c="dimmed">
                          <FormattedDate date={user.createdAt} />
                        </Text>
                      </Table.Td>
                      <Table.Td ta="center">
                        <Tooltip label={roleActionLabel(user.id, user.platformRole)}>
                          <ActionIcon
                            aria-label={roleActionLabel(user.id, user.platformRole)}
                            variant="subtle"
                            color={user.platformRole === 'PLATFORM_ADMIN' ? 'red' : 'blue'}
                            onClick={() => handleTogglePlatformAdmin(user.id, user.platformRole)}
                            loading={assignRoleMutation.isPending}
                            disabled={
                              user.id === currentUser?.id && user.platformRole === 'PLATFORM_ADMIN'
                            }
                          >
                            {user.platformRole === 'PLATFORM_ADMIN' ? (
                              <IconShieldOff size={20} />
                            ) : (
                              <IconShieldCheck size={20} />
                            )}
                          </ActionIcon>
                        </Tooltip>
                      </Table.Td>
                    </Table.Tr>
                  ))}
                </Table.Tbody>
              </Table>
            </Table.ScrollContainer>

            <Pagination
              currentPage={filters.page}
              totalPages={totalPages}
              onPageChange={(page) => {
                setFilters({ page })
                scrollToListTop()
              }}
            />
          </Stack>
        ) : (
          <Paper withBorder p="xl" radius="md">
            <Center>
              <Stack align="center" gap="sm">
                <IconUsers size={48} color="var(--mantine-color-dimmed)" />
                <Text fw={500}>{t('admin.users.empty.title')}</Text>
                <Text c="dimmed">{t('admin.users.empty.description')}</Text>
              </Stack>
            </Center>
          </Paper>
        )}
      </Stack>
    </AdminLayout>
  )
}
