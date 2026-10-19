import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  IconBike,
  IconBolt,
  IconRoad,
  IconMountain,
  IconWalk,
  IconMotorbike,
} from '@tabler/icons-react'
import { Anchor, Group, Indicator, Slider, Text, Stack, UnstyledButton } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import { MapPanel } from '@/components/map/MapPanel'
import { useMediaMatch } from '@/hooks/useResponsive'
import {
  displayedValue,
  isCustomTuning,
  isTunable,
  type RouterTuning,
  type TuningKey,
} from '@/lib/routerTuning'

interface RouterProfileSelectorProps {
  currentProfile: RouterProfile
  onProfileChange: (profile: RouterProfile) => void
  /** The knobs set for the current profile; absent ones are the profile's values. */
  tuning?: RouterTuning
  onTuningChange?: (key: TuningKey, value: number) => void
  onTuningReset?: () => void
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
  tuning = {},
  onTuningChange,
  onTuningReset,
  trigger,
}: RouterProfileSelectorProps) {
  const { t } = useTranslation()
  const showTuning = isTunable(currentProfile) && onTuningChange !== undefined
  const custom = showTuning && isCustomTuning(tuning)
  const CurrentIcon = PROFILE_ICONS[currentProfile]

  return (
    <MapPanel
      id="profile"
      label={
        custom
          ? `${t('planner.profile.label')} (${t('planner.tuning.custom')})`
          : t('planner.profile.label')
      }
      title={t('planner.profile.label')}
      width={260}
      icon={
        // Dot: a setting differs from the profile's, which the button alone would not tell
        <Indicator disabled={!custom} size={8} offset={-1} color="orange" label="">
          <CurrentIcon size={20} />
        </Indicator>
      }
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
          {showTuning && (
            <TuningSliders
              profile={currentProfile}
              tuning={tuning}
              onChange={onTuningChange}
              onReset={onTuningReset}
              custom={custom}
            />
          )}
        </Stack>
      )}
    </MapPanel>
  )
}

interface TuningSlidersProps {
  profile: RouterProfile
  tuning: RouterTuning
  onChange: (key: TuningKey, value: number) => void
  onReset?: () => void
  custom: boolean
}

const STEPS = [0, 0.25, 0.5, 0.75, 1]

function TuningSliders({ profile, tuning, onChange, onReset, custom }: TuningSlidersProps) {
  const { t } = useTranslation()
  const hills = [
    t('planner.tuning.hills.0'),
    t('planner.tuning.hills.1'),
    t('planner.tuning.hills.2'),
    t('planner.tuning.hills.3'),
    t('planner.tuning.hills.4'),
  ]
  const roads = [
    t('planner.tuning.roads.0'),
    t('planner.tuning.roads.1'),
    t('planner.tuning.roads.2'),
    t('planner.tuning.roads.3'),
    t('planner.tuning.roads.4'),
  ]
  return (
    <Stack
      gap="sm"
      mt="xs"
      pt="sm"
      style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}
    >
      <TuningSlider
        name={t('planner.tuning.hills.label')}
        words={hills}
        value={displayedValue(profile, tuning, 'useHills')}
        onCommit={(v) => onChange('useHills', v)}
      />
      <TuningSlider
        name={t('planner.tuning.roads.label')}
        words={roads}
        value={displayedValue(profile, tuning, 'useRoads')}
        onCommit={(v) => onChange('useRoads', v)}
      />
      <Text size="xs" c="dimmed">
        {t('planner.tuning.help')}
      </Text>
      {custom && onReset && (
        <Anchor component="button" type="button" size="xs" onClick={onReset} ta="left">
          {t('planner.tuning.reset')}
        </Anchor>
      )}
    </Stack>
  )
}

interface TuningSliderProps {
  name: string
  /** One word per step, from 0 to 1. */
  words: string[]
  value: number
  onCommit: (value: number) => void
}

function TuningSlider({ name, words, value, onCommit }: TuningSliderProps) {
  const isCoarse = useMediaMatch('(pointer: coarse)')
  // While the thumb moves only this state changes; the setting is committed when it is released
  const [draft, setDraft] = useState<number | null>(null)
  const shown = draft ?? value
  const word = words[Math.round(shown * 4)]
  return (
    <div>
      <Group justify="space-between" mb={4}>
        <Text size="sm" fw={500}>
          {name}
        </Text>
        <Text size="xs" c="dimmed">
          {word}
        </Text>
      </Group>
      <Slider
        min={0}
        max={1}
        step={0.25}
        size={isCoarse ? 'lg' : 'sm'}
        value={shown}
        onChange={setDraft}
        onChangeEnd={(v) => {
          setDraft(null)
          onCommit(v)
        }}
        label={(v) => words[Math.round(v * 4)]}
        marks={STEPS.map((v) => ({
          value: v,
          label: v === 0 ? words[0] : v === 1 ? words[4] : undefined,
        }))}
        thumbLabel={name}
        thumbValueText={(v) => words[Math.round(v * 4)]}
        mb="md"
      />
    </div>
  )
}
