import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { DuplicateRouteModal } from './DuplicateRouteModal'

function show(props: Partial<Parameters<typeof DuplicateRouteModal>[0]> = {}) {
  const onSubmit = vi.fn()
  const onClose = vi.fn()
  render(
    <MantineProvider>
      <DuplicateRouteModal
        sourceName="Tour du lac"
        onSubmit={onSubmit}
        onClose={onClose}
        {...props}
      />
    </MantineProvider>
  )
  return { onSubmit, onClose }
}

const nameField = () => screen.getByRole('textbox', { name: /Nom du parcours/ }) as HTMLInputElement
const submitButton = () => screen.getByRole('button', { name: 'Dupliquer' })

describe('DuplicateRouteModal (WEB-168)', () => {
  afterEach(cleanup)

  it('opens on « Copie de {name} », with Annuler and Dupliquer', async () => {
    show()
    await screen.findByRole('dialog')
    expect(screen.getByText('Dupliquer le parcours')).toBeTruthy()
    expect(nameField().value).toBe('Copie de Tour du lac')
    expect(screen.getByRole('button', { name: 'Annuler' })).toBeTruthy()
    expect(submitButton()).toBeTruthy()
  })

  it('cuts the default to the 200 characters the API takes', async () => {
    show({ sourceName: 'x'.repeat(200) })
    await screen.findByRole('dialog')
    expect(nameField().value).toHaveLength(200)
  })

  it('sends the trimmed name it holds', async () => {
    const { onSubmit } = show()
    await screen.findByRole('dialog')
    fireEvent.change(nameField(), { target: { value: '  Tour du lac, variante  ' } })
    fireEvent.click(submitButton())
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith('Tour du lac, variante'))
  })

  it('requires a name: a blank one cannot be sent', async () => {
    const { onSubmit } = show()
    await screen.findByRole('dialog')
    fireEvent.change(nameField(), { target: { value: '   ' } })
    await waitFor(() => expect((submitButton() as HTMLButtonElement).disabled).toBe(true))
    fireEvent.submit(nameField().closest('form')!)
    expect(onSubmit).not.toHaveBeenCalled()
  })

  it('closes on Annuler', async () => {
    const { onClose, onSubmit } = show()
    await screen.findByRole('dialog')
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }))
    expect(onClose).toHaveBeenCalled()
    expect(onSubmit).not.toHaveBeenCalled()
  })
})

describe('DuplicateRouteModal for a GPX preview (WEB-180)', () => {
  afterEach(cleanup)

  it('is titled « Dupliquer le fichier » and starts on « Copie de {name} »', async () => {
    show({ target: 'preview' })
    await screen.findByRole('dialog')
    expect(screen.getByText('Dupliquer le fichier')).toBeTruthy()
    expect(nameField().value).toBe('Copie de Tour du lac')
  })

  it('cuts the default to the 200 characters the API takes', async () => {
    show({ target: 'preview', sourceName: 'x'.repeat(250) })
    await screen.findByRole('dialog')
    expect(nameField().value).toHaveLength(200)
  })

  it('cannot send a name under 3 characters once trimmed', async () => {
    const { onSubmit } = show({ target: 'preview' })
    await screen.findByRole('dialog')
    fireEvent.change(nameField(), { target: { value: '  ab  ' } })
    await waitFor(() => expect((submitButton() as HTMLButtonElement).disabled).toBe(true))
    fireEvent.submit(nameField().closest('form')!)
    expect(onSubmit).not.toHaveBeenCalled()
  })
})
