import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, fireEvent, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
  Trans: ({ i18nKey }: { i18nKey: string }) => i18nKey,
}))

const auth = vi.hoisted(() => ({
  isAuthenticated: false,
  setAccessToken: vi.fn(),
  setUser: vi.fn(),
  login: vi.fn(),
  register: vi.fn(),
}))

vi.mock('@/hooks/useAuth', () => ({ useAuth: () => ({ isAuthenticated: auth.isAuthenticated }) }))
vi.mock('@/hooks/useAppName', () => ({ useAppName: () => 'Pédalons' }))
vi.mock('@/store/authStore', () => ({
  useAuthStore: () => ({ setAccessToken: auth.setAccessToken, setUser: auth.setUser }),
}))
vi.mock('@/api/endpoints/authentication/authentication', () => ({
  loginWithPassword: (...args: unknown[]) => auth.login(...args),
  register: (...args: unknown[]) => auth.register(...args),
  requestOtp: vi.fn(),
  verifyOtp: vi.fn(),
}))
vi.mock('@simplewebauthn/browser', () => ({
  browserSupportsWebAuthn: () => false,
  startAuthentication: vi.fn(),
}))
vi.mock('@mantine/notifications', () => ({ notifications: { show: vi.fn() } }))

import { LoginForm, type LoginFormProps } from './LoginForm'
import { LoginPage } from '@/pages/auth/LoginPage'

function Where() {
  const location = useLocation()
  return <output data-testid="where">{location.pathname + location.search}</output>
}

function renderAt(ui: React.ReactNode, path = '/connexion') {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[path]}>
          <Routes>
            <Route
              path="*"
              element={
                <>
                  {ui}
                  <Where />
                </>
              }
            />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const form = (props: Partial<LoginFormProps> = {}) => (
  <LoginForm title="Connexion" subtitle="Sous-titre" titleOrder={2} {...props} />
)

async function signIn() {
  fireEvent.change(screen.getByRole('textbox', { name: 'auth.form.email' }), {
    target: { value: 'camille@example.fr' },
  })
  fireEvent.change(screen.getByLabelText('auth.form.password'), { target: { value: 'secret' } })
  fireEvent.click(screen.getByRole('button', { name: 'auth.login.button' }))
  await waitFor(() => expect(auth.login).toHaveBeenCalled())
}

describe('LoginForm', () => {
  beforeEach(() => {
    auth.isAuthenticated = false
    auth.setAccessToken.mockReset()
    auth.setUser.mockReset()
    auth.login.mockReset().mockResolvedValue({ accessToken: 'jwt', user: { id: 'u1' } })
    auth.register.mockReset().mockResolvedValue(undefined)
  })
  afterEach(cleanup)

  it('the login page keeps its own heading, a level-one « welcome »', () => {
    renderAt(<LoginPage />)
    expect(screen.getByRole('heading', { level: 1, name: 'welcome' })).toBeTruthy()
  })

  it('takes the heading it is given', () => {
    renderAt(form())
    expect(screen.getByRole('heading', { level: 2, name: 'Connexion' })).toBeTruthy()
    expect(screen.getByText('Sous-titre')).toBeTruthy()
  })

  it('redirect: once signed in, goes home', async () => {
    renderAt(form({ afterSignIn: 'redirect' }), '/connexion')
    await signIn()
    await waitFor(() => expect(screen.getByTestId('where').textContent).toBe('/'))
    expect(auth.login).toHaveBeenCalledWith(
      { email: 'camille@example.fr', password: 'secret' },
      { skipErrorToast: true }
    )
    expect(auth.setAccessToken).toHaveBeenCalledWith('jwt')
    expect(auth.setUser).toHaveBeenCalledWith({ id: 'u1' })
  })

  it('redirect: an already signed-in visitor leaves for `?next=`', async () => {
    const assign = vi.fn()
    const original = window.location
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...original, assign },
    })
    try {
      auth.isAuthenticated = true
      renderAt(form({ afterSignIn: 'redirect' }), '/connexion?next=%2Fprofil')
      await waitFor(() => expect(assign).toHaveBeenCalledWith('/profil'))
    } finally {
      Object.defineProperty(window, 'location', { configurable: true, value: original })
    }
  })

  it('stay (the home hero): signs in without leaving the page, its query string kept', async () => {
    renderAt(form({ afterSignIn: 'stay' }), '/?q=col')
    await signIn()
    await waitFor(() => expect(auth.setUser).toHaveBeenCalledWith({ id: 'u1' }))
    expect(screen.getByTestId('where').textContent).toBe('/?q=col')
  })

  it('stay: ignores `?next=` and a signed-in session alike', () => {
    auth.isAuthenticated = true
    renderAt(form({ afterSignIn: 'stay' }), '/?next=%2Fprofil')
    expect(screen.getByTestId('where').textContent).toBe('/?next=%2Fprofil')
  })

  it('keeps the page level on the register and code steps', () => {
    renderAt(form({ titleOrder: 1 }))
    fireEvent.click(screen.getByRole('button', { name: 'auth.login.methods.register' }))
    expect(screen.getByRole('heading', { level: 1, name: 'auth.register.title' })).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'auth.login.title' }))
    fireEvent.click(screen.getByRole('button', { name: 'auth.login.methods.otp' }))
    expect(screen.getByRole('heading', { level: 1, name: 'auth.otp.title' })).toBeTruthy()
  })

  it('opens the register step, and the e-mailed code step', () => {
    renderAt(form())
    fireEvent.click(screen.getByRole('button', { name: 'auth.login.methods.register' }))
    expect(screen.getByRole('heading', { name: 'auth.register.title' })).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'auth.login.title' }))
    fireEvent.click(screen.getByRole('button', { name: 'auth.login.methods.otp' }))
    expect(screen.queryByRole('button', { name: 'auth.login.button' })).toBeNull()
  })

  it('a controlled step: the page opens the register step, and hears the way back', () => {
    const onModeChange = vi.fn()
    renderAt(form({ mode: 'register', onModeChange }))
    expect(screen.getByRole('heading', { name: 'auth.register.title' })).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'auth.login.title' }))
    expect(onModeChange).toHaveBeenCalledWith('login')
  })
})
