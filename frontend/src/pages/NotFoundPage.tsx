import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { Center, Stack, Title, Text, Anchor } from '@mantine/core'
import { paths } from '@/config/paths'

export function NotFoundPage() {
  const { t } = useTranslation()
  return (
    <Center mih="60vh">
      <Stack align="center" ta="center">
        <Title order={1}>{t('notFound.pageTitle')}</Title>
        <Text size="lg" c="dimmed">
          {t('seo.notFound.description')}
        </Text>
        <Anchor component={PrefetchLink} to={paths.home()} fw={500}>
          {t('errors.notFound.backHome')}
        </Anchor>
      </Stack>
    </Center>
  )
}
