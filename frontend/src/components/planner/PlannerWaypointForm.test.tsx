import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { PlannerWaypointForm } from './PlannerWaypointForm'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (k: string, o?: Record<string, unknown>) =>
      o && 'length' in o ? `${k} ${o.length}/${o.max}` : k,
  }),
}))
vi.mock('@/hooks/useUnits', () => ({
  useUnits: () => ({
    distance: (m: number) => `${m / 1000} km`,
    elevation: (m: number) => `${m} m`,
  }),
}))

function renderForm(props: Partial<React.ComponentProps<typeof PlannerWaypointForm>> = {}) {
  const onSubmit = vi.fn()
  const onClose = vi.fn()
  const view = render(
    <MantineProvider>
      <PlannerWaypointForm
        opened
        mode="create"
        distance={1500}
        onSubmit={onSubmit}
        onClose={onClose}
        {...props}
      />
    </MantineProvider>
  )
  return { onSubmit, onClose, ...view }
}

const nameInput = () => screen.getByLabelText('planner.waypoint.form.name') as HTMLInputElement

describe('PlannerWaypointForm', () => {
  afterEach(cleanup)

  it('pre-selects REGROUP for a new point and counts the characters', async () => {
    renderForm()
    await screen.findByRole('dialog')
    expect(
      screen
        .getByRole('radio', { name: 'routes.waypoints.type.REGROUP' })
        .getAttribute('aria-checked')
    ).toBe('true')
    expect(screen.getAllByRole('radio')).toHaveLength(12)
    fireEvent.change(nameInput(), { target: { value: 'Pont' } })
    expect(screen.getByText(/planner.waypoint.form.counter 4\/40/)).toBeTruthy()
  })

  it('bounds the name at 40, and saves the type, name and description trimmed', async () => {
    const { onSubmit } = renderForm()
    await screen.findByRole('dialog')
    expect(nameInput().maxLength).toBe(40)
    fireEvent.click(screen.getByRole('radio', { name: 'routes.waypoints.type.WATER' }))
    fireEvent.change(nameInput(), { target: { value: '  Fontaine  ' } })
    fireEvent.change(screen.getByLabelText('planner.waypoint.form.description'), {
      target: { value: ' Eau potable ' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'planner.waypoint.form.add' }))
    expect(onSubmit).toHaveBeenCalledWith({
      type: 'WATER',
      name: 'Fontaine',
      description: 'Eau potable',
    })
  })

  it('does not cut by force a longer name that came with an import', async () => {
    const longName = 'x'.repeat(120)
    renderForm({
      mode: 'edit',
      initial: { type: 'CAFE', name: longName, description: '' },
      onDelete: vi.fn(),
    })
    await screen.findByRole('dialog')
    expect(nameInput().value).toBe(longName)
    expect(nameInput().maxLength).toBe(120)
  })

  it('Enter saves, and the submit does not reach a parent form (the route editor would save the route)', async () => {
    const outer = vi.fn((event: React.FormEvent) => event.preventDefault())
    const onSubmit = vi.fn()
    render(
      <MantineProvider>
        <form onSubmit={outer}>
          <PlannerWaypointForm
            opened
            mode="create"
            distance={10}
            onSubmit={onSubmit}
            onClose={() => {}}
          />
        </form>
      </MantineProvider>
    )
    await screen.findByRole('dialog')
    fireEvent.change(nameInput(), { target: { value: 'Pont' } })
    // Enter in a text field submits its form
    fireEvent.submit(nameInput().closest('form')!)
    expect(onSubmit).toHaveBeenCalledTimes(1)
    expect(outer).not.toHaveBeenCalled()
  })

  it('offers « delete » when editing only', async () => {
    const onDelete = vi.fn()
    const { unmount } = renderForm({
      mode: 'edit',
      initial: { type: 'CAFE', name: 'Café', description: '' },
      onDelete,
    })
    await screen.findByRole('dialog')
    fireEvent.click(screen.getByRole('button', { name: 'planner.waypoint.form.delete' }))
    expect(onDelete).toHaveBeenCalledTimes(1)
    unmount()

    renderForm()
    await screen.findByRole('dialog')
    expect(screen.queryByRole('button', { name: 'planner.waypoint.form.delete' })).toBeNull()
  })

  it('says where the point is, and offers to put it back on the route only when it is off it', async () => {
    const onSnap = vi.fn()
    const { unmount } = renderForm({
      mode: 'edit',
      initial: { type: 'CAFE', name: 'Café', description: '' },
      distance: null,
      onSnap,
    })
    await screen.findByRole('dialog')
    expect(screen.getByText('planner.waypoint.offTrack.hint')).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'planner.waypoint.snap' }))
    expect(onSnap).toHaveBeenCalledTimes(1)
    unmount()

    renderForm({
      mode: 'edit',
      initial: { type: 'CAFE', name: 'Café', description: '' },
      distance: 2500,
      onSnap,
    })
    await screen.findByRole('dialog')
    expect(screen.getByText('routes.waypoints.fromStart')).toBeTruthy()
    expect(screen.queryByRole('button', { name: 'planner.waypoint.snap' })).toBeNull()
  })

  it('does not save while a calculation runs', async () => {
    const { onSubmit } = renderForm({ busy: true })
    await screen.findByRole('dialog')
    const add = screen.getByRole('button', { name: 'planner.waypoint.form.add' })
    expect((add as HTMLButtonElement).disabled).toBe(true)
    fireEvent.submit(nameInput().closest('form')!)
    await waitFor(() => expect(onSubmit).not.toHaveBeenCalled())
  })

  it('closes on cancel without saving', async () => {
    const { onSubmit, onClose } = renderForm()
    await screen.findByRole('dialog')
    fireEvent.click(screen.getByRole('button', { name: 'actions.cancelAction' }))
    expect(onClose).toHaveBeenCalledTimes(1)
    expect(onSubmit).not.toHaveBeenCalled()
  })
})
