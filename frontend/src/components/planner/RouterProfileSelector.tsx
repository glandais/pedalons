import { useTranslation } from 'react-i18next'
import {
  IconBike,
  IconBolt,
  IconRoad,
  IconMountain,
  IconWalk,
  IconMotorbike,
} from '@tabler/icons-react'
import { Group, Text, Stack, UnstyledButton } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import { MapPanel } from '@/components/map/MapPanel'

interface RouterProfileSelectorProps {
  currentProfile: RouterProfile
  onProfileChange: (profile: RouterProfile) => void
  /** `'bar'`: a button of the touch toolbar instead of the map's control column. */
  trigger?: 'map' | 'bar'
}

const PROFILE_ICONS: Record<RouterProfile, React.ComponentType<{ size?: number }>> = {
  [RouterProfile.BIKE]: IconBike,
  [RouterProfile.FASTBIKE]: IconBolt,
  [RouterProfile.GRAVEL]: IconRoad,
  [RouterProfile.MTB]: IconMountain,
  [RouterProfile.RUN_HIKE]: IconWalk,
  [RouterProfile.MOTORCYCLE]: IconMotorbike,
}

const PROFILES: RouterProfile[] = [
  RouterProfile.BIKE,
  RouterProfile.FASTBIKE,
  RouterProfile.GRAVEL,
  RouterProfile.MTB,
  RouterProfile.RUN_HIKE,
  RouterProfile.MOTORCYCLE,
]

export function RouterProfileSelector({
  currentProfile,
  onProfileChange,
  trigger,
}: RouterProfileSelectorProps) {
  const { t } = useTranslation()
  const CurrentIcon = PROFILE_ICONS[currentProfile]

  return (
    <MapPanel
      id="profile"
      label={t('planner.profile.label')}
      title={t('planner.profile.label')}
      icon={<CurrentIcon size={20} />}
      trigger={trigger}
    >
      {(close) => (
        <Stack gap={4}>
          {PROFILES.map((profile) => {
            const Icon = PROFILE_ICONS[profile]
            const isSelected = profile === currentProfile
            return (
              <UnstyledButton
                key={profile}
                onClick={() => {
                  onProfileChange(profile)
                  close()
                }}
                px="sm"
                py="xs"
                style={{
                  borderRadius: 'var(--mantine-radius-sm)',
                  backgroundColor: isSelected ? 'var(--mantine-primary-color-light)' : undefined,
                  transition: 'background-color 150ms',
                }}
              >
                <Group gap="xs">
                  <Icon size={18} />
                  <Text
                    size="sm"
                    c={isSelected ? 'var(--mantine-primary-color-filled)' : undefined}
                    fw={isSelected ? 500 : 400}
                  >
                    {t(
                      `planner.profile.${profile satisfies 'BIKE' | 'FASTBIKE' | 'GRAVEL' | 'MTB' | 'RUN_HIKE' | 'MOTORCYCLE'}`
                    )}
                  </Text>
                </Group>
              </UnstyledButton>
            )
          })}
        </Stack>
      )}
    </MapPanel>
  )
}
