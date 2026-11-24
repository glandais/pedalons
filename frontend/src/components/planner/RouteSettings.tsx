import { useEffect, useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  IconAdjustmentsHorizontal,
  IconBike,
  IconGrain,
  IconHelp,
  IconMotorbike,
  IconMountain,
  IconRefresh,
  IconRoad,
  IconWalk,
  IconX,
} from '@tabler/icons-react'
import {
  ActionIcon,
  Anchor,
  Box,
  Button,
  Drawer,
  Group,
  Paper,
  Radio,
  SegmentedControl,
  SimpleGrid,
  Stack,
  Text,
  UnstyledButton,
} from '@mantine/core'
import { RouterEngine, RouterProfile } from '@/api/dto'
import { useMapPanel } from '@/components/map/mapPanelState'
import { MapToolbarButton } from '@/components/map/MapToolbarButton'
import { useFullscreenElement } from '@/components/map/useFullscreenElement'
import { useMediaMatch } from '@/hooks/useResponsive'
import { useUnits } from '@/hooks/useUnits'
import {
  defaultHillsStep,
  defaultTrafficStep,
  HILLS_STEP_VALUES,
  HILLS_STEPS,
  hillsStepOf,
  isTunable,
  TRAFFIC_STEP_VALUES,
  TRAFFIC_STEPS,
  trafficStepOf,
  type HillsStep,
  type TrafficStep,
} from '@/lib/routerTuning'
import {
  isSettingsAdjusted,
  ROUTE_SETTINGS_PANEL_ID,
  type RouteSettingsModel,
} from './routeSettingsModel'

const PROFILE_ICONS: Record<RouterProfile, React.ComponentType<{ size?: number }>> = {
  [RouterProfile.BIKE]: IconBike,
  [RouterProfile.FASTBIKE]: IconRoad,
  [RouterProfile.GRAVEL]: IconGrain,
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

/** Above the elevation profile overlaid on compact maps: the same layer as MapPanel's bottom sheet. */
const SHEET_Z_INDEX = 1001

/** Width of the panel docked on the right of the map, on a mouse. */
export const ROUTE_SETTINGS_DOCK_WIDTH_PX = 340

interface RouteSettingsButtonProps {
  settings: RouteSettingsModel
  /**
   * `'toolbar'`: a button of the toolbar at the bottom of the map, on a mouse (`PlannerToolbar`);
   * `'bar'`: a button of the touch bottom bar (`PlannerBottomBar`).
   */
  trigger: 'toolbar' | 'bar'
}

/**
 * The « Réglages du tracé » button, with the practice in words, and on a finger the bottom sheet it
 * opens. On a mouse the panel is `RouteSettingsDock`, docked on the map's right edge.
 *
 * The sheet is a copy of `MapPanel`'s and not a `MapPanel`: the dock lives outside the toolbar, and
 * `MapPanel` is shared (basemap, help) and anchors a popover to its button. Both read the same
 * open-panel state, so opening the basemap panel still closes this one.
 */
export function RouteSettingsButton({ settings, trigger }: RouteSettingsButtonProps) {
  const { t } = useTranslation()
  const { opened, toggle, close } = useMapPanel(ROUTE_SETTINGS_PANEL_ID)
  const isCoarse = useMediaMatch('(pointer: coarse)')
  // In browser fullscreen a portal into <body> is never on screen: render into the map instead
  // (the key remounts Mantine's Portal, which reads its target only when it mounts).
  const fullscreenElement = useFullscreenElement()
  const portalKey = fullscreenElement ? 'fullscreen' : 'page'

  const profileLabel = t(`planner.profile.${settings.profile}`)
  const custom = isSettingsAdjusted(settings)
  const name = t(custom ? 'planner.settings.buttonAdjusted' : 'planner.settings.button', {
    profile: profileLabel,
  })

  return (
    <>
      {trigger === 'toolbar' ? (
        <MapToolbarButton
          className="map-toolbar-button--text"
          data-route-settings-trigger=""
          label={name}
          active={opened}
          onClick={toggle}
          icon={
            <>
              <IconAdjustmentsHorizontal size={18} />
              <span>{profileLabel}</span>
              {custom && (
                <span className="map-toolbar-button__adjusted">
                  {t('planner.settings.adjusted')}
                </span>
              )}
            </>
          }
        />
      ) : (
        <UnstyledButton
          miw={44}
          mih={44}
          px={4}
          aria-label={name}
          aria-pressed={opened}
          onClick={toggle}
          style={{
            borderRadius: 'var(--mantine-radius-sm)',
            background: opened ? 'var(--mantine-color-default-hover)' : undefined,
          }}
        >
          <Stack gap={0} align="center">
            <IconAdjustmentsHorizontal size={22} />
            <Text fz={10} lh={1.2} truncate maw={68}>
              {profileLabel}
              {custom ? ` ${t('planner.settings.adjusted')}` : ''}
            </Text>
          </Stack>
        </UnstyledButton>
      )}
      {(trigger === 'bar' || isCoarse) && (
        <Drawer
          key={portalKey}
          opened={opened}
          onClose={close}
          position="bottom"
          size="auto"
          zIndex={SHEET_Z_INDEX}
          portalProps={{ target: fullscreenElement }}
          title={t('planner.settings.title')}
          closeButtonProps={{ 'aria-label': t('actions.close') }}
        >
          <RouteSettingsContent settings={settings} />
        </Drawer>
      )}
    </>
  )
}

interface RouteSettingsDockProps {
  settings: RouteSettingsModel
  /** Gap to the map's top, right and bottom edges (px). */
  inset: number
}

/**
 * The panel on a mouse: docked on the map's right edge, full height, 340 px wide (WEB-202). It does
 * not close on an outside click — drawing stays possible with it open — nor on a choice; it closes
 * with its X, its button or Escape. The map's controls and the toolbar make room for it
 * (`.planner-map--dock`, index.css).
 */
export function RouteSettingsDock({ settings, inset }: RouteSettingsDockProps) {
  const { t } = useTranslation()
  const { opened, close } = useMapPanel(ROUTE_SETTINGS_PANEL_ID)
  const titleId = useId()

  // In the capture phase, as MapPanel does: a tooltip stops Escape's propagation while it shows.
  useEffect(() => {
    if (!opened) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKeyDown, true)
    return () => window.removeEventListener('keydown', onKeyDown, true)
  }, [opened, close])

  // The X unmounts the button that has the focus: hand it back to the toolbar's button, as Escape
  // and the button itself leave it (a keyboard user keeps their place).
  const closeFromX = () => {
    close()
    document.querySelector<HTMLElement>('[data-route-settings-trigger]')?.focus()
  }

  if (!opened) return null

  return (
    <Box
      component="section"
      aria-labelledby={titleId}
      pos="absolute"
      top={inset}
      right={inset}
      bottom={inset}
      w={ROUTE_SETTINGS_DOCK_WIDTH_PX}
      style={{
        zIndex: 3,
        pointerEvents: 'auto',
        display: 'flex',
        flexDirection: 'column',
        background: 'var(--mantine-color-body)',
        border: '1px solid var(--mantine-color-default-border)',
        borderRadius: 'var(--mantine-radius-md)',
        boxShadow: 'var(--mantine-shadow-lg)',
      }}
    >
      <Group justify="space-between" wrap="nowrap" px="md" pt="sm" pb={4}>
        <Text component="h2" id={titleId} fw={600} size="sm" m={0}>
          {t('planner.settings.title')}
        </Text>
        <ActionIcon
          variant="subtle"
          color="gray"
          size="lg"
          onClick={closeFromX}
          aria-label={t('actions.close')}
        >
          <IconX size={18} />
        </ActionIcon>
      </Group>
      <Box p="md" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
        <RouteSettingsBody settings={settings} />
      </Box>
      <Box px="md" pb="md">
        <RouteSettingsFooter settings={settings} />
      </Box>
    </Box>
  )
}

/** The panel's content: the body, then the footer. The bottom sheet's; the dock pins the footer. */
export function RouteSettingsContent({ settings }: { settings: RouteSettingsModel }) {
  return (
    <Stack gap="md">
      <RouteSettingsBody settings={settings} />
      <RouteSettingsFooter settings={settings} />
    </Stack>
  )
}

/** Practice, calculation, traffic and hills: what scrolls. */
export function RouteSettingsBody({ settings }: { settings: RouteSettingsModel }) {
  const { t } = useTranslation()
  const isCoarse = useMediaMatch('(pointer: coarse)')
  const { profile, onProfileChange, tuning, onTuningChange, engineChoice } = settings
  const engineLabelId = useId()
  const trafficLabelId = useId()
  const hillsLabelId = useId()
  const [engineHelpOpen, setEngineHelpOpen] = useState(false)

  const tunable = isTunable(profile)
  const showEngine = tunable && engineChoice !== undefined
  const hillsShown = tunable && (!engineChoice || engineChoice.value === RouterEngine.STADIA)
  const trafficStep = trafficStepOf(profile, tuning)
  const hillsStep = hillsStepOf(profile, tuning)
  const trafficCustom = tunable && trafficStep !== defaultTrafficStep(profile)
  const hillsCustom = hillsShown && hillsStep !== defaultHillsStep(profile)
  const segmentStyles = { label: { minHeight: isCoarse ? 44 : 36 } }

  const adjusted = (flag: boolean, defaultStep: string) =>
    flag ? (
      <Text size="xs" c="orange">
        {t('planner.tuning.adjusted', { step: defaultStep })}
      </Text>
    ) : null

  return (
    <Stack gap="md">
      <Radio.Group
        value={profile}
        onChange={(value) => onProfileChange(value as RouterProfile)}
        label={t('planner.profile.label')}
      >
        <SimpleGrid cols={3} spacing={8} mt={6}>
          {PROFILES.map((p) => {
            const Icon = PROFILE_ICONS[p]
            const checked = p === profile
            return (
              <Radio.Card
                key={p}
                value={p}
                radius="md"
                mih={72}
                p={6}
                // The choice must read at a glance: tinted ground, primary border (doubled by an inset
                // ring, so the card does not move) and text, not just a bolder label
                bg={checked ? 'var(--mantine-primary-color-light)' : undefined}
                c={checked ? 'var(--mantine-primary-color-light-color)' : undefined}
                style={
                  checked
                    ? {
                        borderColor: 'var(--mantine-primary-color-filled)',
                        boxShadow: 'inset 0 0 0 1px var(--mantine-primary-color-filled)',
                      }
                    : undefined
                }
              >
                <Stack align="center" justify="center" gap={6} h="100%">
                  <Icon size={24} />
                  <Text size="sm" ta="center" lh={1.2} fw={checked ? 600 : 400} c="inherit">
                    {t(`planner.profile.${p}`)}
                  </Text>
                </Stack>
              </Radio.Card>
            )
          })}
        </SimpleGrid>
      </Radio.Group>

      {showEngine && engineChoice && (
        <Stack gap={6}>
          <Group justify="space-between" wrap="nowrap">
            <Text id={engineLabelId} size="sm" fw={500}>
              {t('planner.engine.label')}
            </Text>
            <ActionIcon
              variant="subtle"
              color="gray"
              size={isCoarse ? 44 : 28}
              onClick={() => setEngineHelpOpen((open) => !open)}
              aria-label={t('planner.engine.helpLabel')}
              aria-expanded={engineHelpOpen}
            >
              <IconHelp size={18} />
            </ActionIcon>
          </Group>
          <SegmentedControl
            fullWidth
            size="sm"
            styles={segmentStyles}
            aria-labelledby={engineLabelId}
            value={engineChoice.value}
            onChange={(value) => engineChoice.onChange(value as RouterEngine)}
            data={[
              {
                value: RouterEngine.PEDALONS,
                label: engineChoice.team ? t('planner.engine.team') : t('planner.engine.shared'),
              },
              { value: RouterEngine.STADIA, label: t('planner.engine.standard') },
            ]}
          />
          <Text size="xs" c="dimmed">
            {engineChoice.value === RouterEngine.PEDALONS
              ? t(engineChoice.team ? 'planner.engine.help.team' : 'planner.engine.help.shared')
              : t('planner.engine.help.standard')}
          </Text>
          {engineHelpOpen && (
            <Paper withBorder p="xs" radius="md">
              <Text size="xs">
                {t(engineChoice.team ? 'planner.engine.more.team' : 'planner.engine.more.shared')}
              </Text>
            </Paper>
          )}
        </Stack>
      )}

      {!showEngine && (
        <Box>
          <Text size="xs" c="dimmed">
            {t(tunable ? 'planner.engine.standardOnly' : 'planner.engine.standardOnlyNoTuning')}
          </Text>
        </Box>
      )}

      {tunable && (
        <Stack gap={6}>
          <Group justify="space-between" wrap="nowrap">
            <Text id={trafficLabelId} size="sm" fw={500}>
              {t('planner.tuning.traffic.label')}
            </Text>
            {adjusted(trafficCustom, t(`planner.tuning.traffic.${defaultTrafficStep(profile)}`))}
          </Group>
          <SegmentedControl
            fullWidth
            size="sm"
            styles={segmentStyles}
            aria-labelledby={trafficLabelId}
            value={trafficStep}
            onChange={(value) =>
              onTuningChange('useRoads', TRAFFIC_STEP_VALUES[value as TrafficStep].useRoads)
            }
            data={TRAFFIC_STEPS.map((step) => ({
              value: step,
              label: t(`planner.tuning.traffic.${step}`),
            }))}
          />
          <Text size="xs" c="dimmed">
            {t(`planner.tuning.traffic.help.${trafficStep}`)}
          </Text>
        </Stack>
      )}

      {hillsShown && (
        <Stack gap={6}>
          <Group justify="space-between" wrap="nowrap">
            <Text id={hillsLabelId} size="sm" fw={500}>
              {t('planner.tuning.hills.label')}
            </Text>
            {adjusted(hillsCustom, t(`planner.tuning.hills.${defaultHillsStep(profile)}`))}
          </Group>
          <SegmentedControl
            fullWidth
            size="sm"
            styles={segmentStyles}
            aria-labelledby={hillsLabelId}
            value={hillsStep}
            onChange={(value) => onTuningChange('useHills', HILLS_STEP_VALUES[value as HillsStep])}
            data={HILLS_STEPS.map((step) => ({
              value: step,
              label: t(`planner.tuning.hills.${step}`),
            }))}
          />
        </Stack>
      )}

      {tunable && engineChoice?.value === RouterEngine.PEDALONS && (
        <Group justify="space-between" wrap="nowrap" gap="xs">
          <Text size="xs" c="dimmed">
            {t('planner.tuning.hillsIgnored')}
          </Text>
          <Anchor
            component="button"
            type="button"
            size="xs"
            onClick={() => engineChoice.onChange(RouterEngine.STADIA)}
          >
            {t('planner.tuning.useStandard')}
          </Anchor>
        </Group>
      )}
    </Stack>
  )
}

/** The recalculation, and the way back to the practice's values: pinned under the body in the dock. */
export function RouteSettingsFooter({ settings }: { settings: RouteSettingsModel }) {
  const { t } = useTranslation()
  const isCoarse = useMediaMatch('(pointer: coarse)')
  const { distance } = useUnits()
  const {
    profile,
    onTuningReset,
    engineChoice,
    pointCount,
    isLoading,
    recalcScope,
    recalculated,
    onRecalculate,
  } = settings
  const custom = isSettingsAdjusted(settings)
  const calculation =
    engineChoice?.value === RouterEngine.PEDALONS
      ? t(
          engineChoice.team
            ? 'planner.recalc.calculation.team'
            : 'planner.recalc.calculation.shared'
        )
      : t('planner.recalc.calculation.standard')

  return (
    <Stack gap="xs" pt="sm" style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}>
      {pointCount < 2 ? (
        <Text size="xs" c="dimmed">
          {t('planner.recalc.note')}
        </Text>
      ) : recalculated ? (
        <Text size="sm" c="teal" role="status">
          {t('planner.recalc.done', { profile: t(`planner.profile.${profile}`), calculation })}
        </Text>
      ) : recalcScope.legs > 0 ? (
        <>
          <Text size="xs" c="dimmed">
            {t('planner.recalc.note')}
          </Text>
          <Text size="xs" c="dimmed">
            {t('planner.recalc.noteKept')}
          </Text>
          <Button
            fullWidth
            variant="light"
            leftSection={<IconRefresh size={18} />}
            disabled={isLoading}
            onClick={onRecalculate}
            size={isCoarse ? 'md' : 'sm'}
          >
            {t('planner.recalc.button', { distance: distance(recalcScope.distance) })}
          </Button>
          {recalcScope.keeps && (
            <Text size="xs" c="dimmed">
              {t('planner.recalc.keeps')}
            </Text>
          )}
        </>
      ) : (
        <Text size="xs" c="dimmed">
          {t('planner.recalc.nothing')}
        </Text>
      )}
      {custom && (
        <Anchor component="button" type="button" size="xs" onClick={onTuningReset} ta="left">
          {t('planner.tuning.reset')}
        </Anchor>
      )}
    </Stack>
  )
}
