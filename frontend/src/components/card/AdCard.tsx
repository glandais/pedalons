import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconCalendar, IconCurrencyEuro } from '@tabler/icons-react'
import { Group, Box, Stack, Text } from '@mantine/core'
import { Card, CardContent, CardTitle, CardDescription, CardImage } from './common'
import { TypeBadge, StateBadge, Stat, StatGroup, CardSkeleton } from './common'
import { cardState } from '@/utils/cardState'
import { EntityLogo } from '../common/EntityLogo'
import { FormattedDateTime } from '../common/FormattedDate'
import { paths } from '@/config/paths'
import { TagList } from '../tag/TagList'
import { AdDto } from '@/api/dto'
import { formatAdPrice } from '@/utils/priceFormat'

interface AdCardProps {
  ad: AdDto
  /** The `⋯` menu (`AdCardActions`). */
  actions?: ReactNode
}

export function AdCard({ ad, actions }: AdCardProps) {
  const { t, i18n } = useTranslation()

  return (
    <Card to={paths.ad(ad.team.slug, ad.slug)} actions={actions}>
      {/* Header image. `thumbnailUrl` is the ad's first picture, computed server-side, and is
          present whatever the list `view` — `media.assets` is trimmed in COMPACT. */}
      <CardImage
        media={ad.media}
        thumbnailUrl={ad.thumbnailUrl}
        alt={ad.name}
        height={120}
        type="AD"
      />

      <CardContent>
        {/* Title row with logo */}
        <Group justify="space-between" mb="md" align="flex-start" wrap="nowrap">
          <Group gap="sm" wrap="nowrap" style={{ flex: 1, minWidth: 0 }}>
            <EntityLogo logo={ad.media.assets.logo} alt={ad.name} size="md" />
            <Box style={{ flex: 1, minWidth: 0 }}>
              <CardTitle>{ad.name}</CardTitle>
              <CardDescription markdown={true} media={ad.media} excerpt={ad.excerpt} />
            </Box>
          </Group>
          <Stack gap={4} align="flex-end" ml="sm" style={{ flexShrink: 0 }}>
            <TypeBadge type={ad.adType}>
              {t(`ads.adType.${ad.adType satisfies 'SALE' | 'RENTAL' | 'WANTED'}`)}
            </TypeBadge>
            {/* The type, then « Brouillon » when it is not published — never « Publié », and no
                visibility: an ad is always « Équipe uniquement », the badge taught nothing
                (docs/LEDGER_*.md WEB-167, R1). */}
            <StateBadge state={cardState({ status: ad.status })} />
          </Stack>
        </Group>

        <StatGroup>
          <Stat icon={<IconCurrencyEuro size={16} />}>
            {formatAdPrice(ad.price, ad.adType, ad.rentalPeriod, i18n.language, t)}
          </Stat>
          <Stat icon={<IconCalendar size={16} />}>
            <FormattedDateTime date={ad.createdAt} />
          </Stat>
          {/* A sector, never a pin: the position is blurred to ~1 km (KIT §9), as the dashboard. */}
          {ad.locationDescription && (
            <Text size="sm" c="dimmed">
              {t('ads.sector', { place: ad.locationDescription })}
            </Text>
          )}
        </StatGroup>

        <TagList tags={ad.tags} max={3} mt="xs" />
      </CardContent>
    </Card>
  )
}

export function AdCardSkeleton() {
  return (
    <CardSkeleton count={1} hasImage imageHeight="120px" hasLogo statCount={3} badgeCount={3} />
  )
}
