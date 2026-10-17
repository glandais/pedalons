import { useTranslation } from 'react-i18next'
import { IconMap } from '@tabler/icons-react'
import {
  Group,
  Text,
  Stack,
  UnstyledButton,
  Switch,
  Checkbox,
  ColorSwatch,
  Divider,
} from '@mantine/core'
import { groupStyles, isKnownGroup, type MapStyle, type MapStyleId } from './mapStyles'
import { MapPanel } from './MapPanel'

/** A trace the visitor can show or hide on its own: a ride's group, a trip's stage. */
export interface MapTraceOption {
  id: string
  label: string
  /** The trace's colour on the map, repeated beside its name. */
  color: string
  visible: boolean
}

export interface MapStyleSwitcherProps {
  /** The served basemaps, in served order. Empty while the config is in flight. */
  styles: readonly MapStyle[]
  currentStyleId: MapStyleId | undefined
  onStyleChange: (styleId: MapStyleId) => void
  terrain3d?: boolean
  onTerrain3DChange?: (enabled: boolean) => void
  hillshade?: boolean
  onHillshadeChange?: (enabled: boolean) => void
  /** Listed under the basemaps, one checkbox each. Left out when the map shows a single trace. */
  traces?: readonly MapTraceOption[]
  onTraceToggle?: (id: string) => void
}

export function MapStyleSwitcher({
  styles,
  currentStyleId,
  onStyleChange,
  terrain3d = false,
  onTerrain3DChange,
  hillshade = false,
  onHillshadeChange,
  traces,
  onTraceToggle,
}: MapStyleSwitcherProps) {
  const { t } = useTranslation()
  return (
    <MapPanel
      id="style"
      label={t('map.styles.switch')}
      title={t('map.styles.title')}
      icon={<IconMap size={20} />}
      width={traces?.length ? 240 : 200}
    >
      {(close) => (
        <>
          <Stack gap="sm">
            {/* Sections follow the served order — the server classifies its basemaps, the client
          doesn't re-sort. A group this build has no label for is titled with its raw value
          rather than with its untranslated key, or silently merged into the one above. */}
            {groupStyles(styles).map((section) => (
              <Stack key={section.group} gap={4}>
                <Text size="xs" fw={600} c="dimmed" tt="uppercase">
                  {isKnownGroup(section.group)
                    ? t(`map.styles.group.${section.group}`)
                    : section.group}
                </Text>
                {section.styles.map((style) => {
                  const isSelected = style.id === currentStyleId
                  return (
                    <UnstyledButton
                      key={style.id}
                      onClick={() => {
                        onStyleChange(style.id)
                        close()
                      }}
                      px="sm"
                      py="xs"
                      style={{
                        borderRadius: 'var(--mantine-radius-sm)',
                        backgroundColor: isSelected
                          ? 'var(--mantine-primary-color-light)'
                          : undefined,
                        transition: 'background-color 150ms',
                      }}
                    >
                      <Text
                        size="sm"
                        c={isSelected ? 'var(--mantine-primary-color-filled)' : undefined}
                        fw={isSelected ? 500 : 400}
                      >
                        {style.label}
                      </Text>
                    </UnstyledButton>
                  )
                })}
              </Stack>
            ))}
          </Stack>
          {(onTerrain3DChange || onHillshadeChange) && (
            <>
              <Divider my="xs" />
              <Stack gap={6}>
                {onTerrain3DChange && (
                  <Switch
                    size="sm"
                    checked={terrain3d}
                    onChange={(e) => onTerrain3DChange(e.currentTarget.checked)}
                    label={t('map.terrain3d.label')}
                  />
                )}
                {onHillshadeChange && (
                  <Switch
                    size="sm"
                    checked={hillshade}
                    onChange={(e) => onHillshadeChange(e.currentTarget.checked)}
                    label={t('map.hillshade.label')}
                  />
                )}
              </Stack>
            </>
          )}
          {traces && traces.length > 0 && onTraceToggle && (
            <>
              <Divider my="xs" />
              <Stack gap={6}>
                <Text size="xs" fw={600} c="dimmed" tt="uppercase">
                  {t('map.traces.title')}
                </Text>
                {traces.map((trace) => (
                  <Checkbox
                    key={trace.id}
                    size="sm"
                    checked={trace.visible}
                    onChange={() => onTraceToggle(trace.id)}
                    label={
                      <Group gap={6} wrap="nowrap">
                        <ColorSwatch color={trace.color} size={12} withShadow={false} />
                        <Text size="sm" truncate>
                          {trace.label}
                        </Text>
                      </Group>
                    }
                  />
                ))}
              </Stack>
            </>
          )}
        </>
      )}
    </MapPanel>
  )
}
