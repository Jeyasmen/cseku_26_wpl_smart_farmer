import { useMemo, useState } from 'react'
import './App.css'

const ADMIN_EMAIL = 'admin@smartfarmer.local'
const ADMIN_PASSWORD = 'AdminPass1'

const initialUsers = [
  { id: 'u-1', name: 'Demo Admin', email: ADMIN_EMAIL, password: ADMIN_PASSWORD, role: 'admin' },
  { id: 'u-2', name: 'Demo Farmer', email: 'farmer@smartfarmer.local', password: 'FarmerPass1', role: 'farmer' },
]

const emptyForm = {
  name: '',
  email: '',
  password: '',
  role: 'farmer',
}

const loginForm = {
  email: '',
  password: '',
}

function validateEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
}

function validatePassword(value) {
  return value.length >= 8 && /[A-Z]/.test(value) && /[a-z]/.test(value) && /[0-9]/.test(value)
}

function App() {
  const [users, setUsers] = useState(initialUsers)
  const [authMode, setAuthMode] = useState('signin')
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [successMessage, setSuccessMessage] = useState('')
  const [session, setSession] = useState(null)
  const [formValues, setFormValues] = useState(emptyForm)
  const [loginValues, setLoginValues] = useState(loginForm)

  const userSummary = useMemo(() => {
    if (!session) {
      return null
    }

    return `${session.name} · ${session.role}`
  }, [session])

  const handleSignIn = async (event) => {
    event.preventDefault()
    setIsLoading(true)
    setErrorMessage('')
    setSuccessMessage('')

    try {
      if (!validateEmail(loginValues.email)) {
        throw new Error('Please enter a valid email address.')
      }

      if (!validatePassword(loginValues.password)) {
        throw new Error('Password must be 8+ chars with uppercase, lowercase, and a number.')
      }

      const match = users.find(
        (user) => user.email.toLowerCase() === loginValues.email.toLowerCase() && user.password === loginValues.password,
      )

      if (!match) {
        throw new Error('Invalid email or password.')
      }

      setSession({ id: match.id, name: match.name, email: match.email, role: match.role })
      setSuccessMessage(`Welcome back, ${match.name}.`) 
      setLoginValues(loginForm)
    } catch (error) {
      setErrorMessage(error.message)
    } finally {
      setIsLoading(false)
    }
  }

  const handleSignUp = async (event) => {
    event.preventDefault()
    setIsLoading(true)
    setErrorMessage('')
    setSuccessMessage('')

    try {
      if (!formValues.name.trim()) {
        throw new Error('Full name is required.')
      }

      if (!validateEmail(formValues.email)) {
        throw new Error('Please enter a valid email address.')
      }

      if (!validatePassword(formValues.password)) {
        throw new Error('Password must be 8+ chars with uppercase, lowercase, and a number.')
      }

      if (users.some((user) => user.email.toLowerCase() === formValues.email.toLowerCase())) {
        throw new Error('An account with that email already exists.')
      }

      const nextUser = {
        id: `u-${Date.now()}`,
        name: formValues.name.trim(),
        email: formValues.email.trim(),
        password: formValues.password,
        role: formValues.role,
      }

      setUsers((current) => [...current, nextUser])
      setSession({ id: nextUser.id, name: nextUser.name, email: nextUser.email, role: nextUser.role })
      setSuccessMessage(`Account created successfully for ${nextUser.name}.`)
      setFormValues(emptyForm)
      setAuthMode('signin')
    } catch (error) {
      setErrorMessage(error.message)
    } finally {
      setIsLoading(false)
    }
  }

  const handleSignOut = () => {
    setSession(null)
    setErrorMessage('')
    setSuccessMessage('You have been signed out.')
  }

  if (session) {
    return (
      <div className="app-shell">
        <aside className="sidebar">
          <div className="brand-block">
            <div className="brand-mark">SF</div>
            <div>
              <h1>Smart Farmer</h1>
              <p>Admin Dashboard</p>
            </div>
          </div>

          <nav className="nav-list" aria-label="Sidebar navigation">
            <button type="button" className="nav-item active">Overview</button>
            <button type="button" className="nav-item">Farmers</button>
            <button type="button" className="nav-item">Crops</button>
            <button type="button" className="nav-item">Activities</button>
            <button type="button" className="nav-item">Reports</button>
          </nav>

          <div className="profile-card">
            <strong>{session.name}</strong>
            <span>{session.role}</span>
            <button type="button" onClick={handleSignOut}>Sign out</button>
          </div>
        </aside>

        <main className="dashboard-main">
          <header className="topbar">
            <div>
              <p className="eyebrow">Welcome</p>
              <h2>{userSummary}</h2>
            </div>
            <button type="button" className="primary-button">Add Crop</button>
          </header>

          <section className="stats-grid">
            <article className="stat-card">
              <label>Active Farmers</label>
              <strong>1,248</strong>
              <span>+4.8% this week</span>
            </article>
            <article className="stat-card">
              <label>Crop Plans</label>
              <strong>392</strong>
              <span>12 due today</span>
            </article>
            <article className="stat-card">
              <label>Alerts</label>
              <strong>18</strong>
              <span>3 urgent</span>
            </article>
          </section>

          {successMessage && <div className="status success">{successMessage}</div>}
        </main>
      </div>
    )
  }

  return (
    <div className="auth-page">
      <div className="auth-panel">
        <div className="auth-header">
          <div className="brand-mark">SF</div>
          <div>
            <p className="eyebrow">Smart Farmer Assistance Platform</p>
            <h1>{authMode === 'signin' ? 'Welcome back' : 'Create account'}</h1>
          </div>
        </div>

        <div className="auth-toggle" aria-label="Authentication mode selector">
          <button
            type="button"
            className={authMode === 'signin' ? 'active' : ''}
            onClick={() => {
              setAuthMode('signin')
              setErrorMessage('')
              setSuccessMessage('')
            }}
          >
            Sign in
          </button>
          <button
            type="button"
            className={authMode === 'signup' ? 'active' : ''}
            onClick={() => {
              setAuthMode('signup')
              setErrorMessage('')
              setSuccessMessage('')
            }}
          >
            Sign up
          </button>
        </div>

        {authMode === 'signin' ? (
          <form onSubmit={handleSignIn} className="auth-form" noValidate>
            <label>
              Email
              <input
                type="email"
                value={loginValues.email}
                onChange={(event) => setLoginValues((current) => ({ ...current, email: event.target.value }))}
                placeholder="you@example.com"
                disabled={isLoading}
              />
            </label>

            <label>
              Password
              <input
                type="password"
                value={loginValues.password}
                onChange={(event) => setLoginValues((current) => ({ ...current, password: event.target.value }))}
                placeholder="Enter password"
                disabled={isLoading}
              />
            </label>

            {errorMessage && <div className="status error" aria-live="polite">{errorMessage}</div>}
            {successMessage && <div className="status success" aria-live="polite">{successMessage}</div>}

            <button type="submit" className="primary-button" disabled={isLoading}>
              {isLoading ? 'Signing in...' : 'Sign in'}
            </button>
          </form>
        ) : (
          <form onSubmit={handleSignUp} className="auth-form" noValidate>
            <label>
              Full name
              <input
                type="text"
                value={formValues.name}
                onChange={(event) => setFormValues((current) => ({ ...current, name: event.target.value }))}
                placeholder="Your full name"
                disabled={isLoading}
              />
            </label>

            <label>
              Email
              <input
                type="email"
                value={formValues.email}
                onChange={(event) => setFormValues((current) => ({ ...current, email: event.target.value }))}
                placeholder="you@example.com"
                disabled={isLoading}
              />
            </label>

            <label>
              Password
              <input
                type="password"
                value={formValues.password}
                onChange={(event) => setFormValues((current) => ({ ...current, password: event.target.value }))}
                placeholder="Create a strong password"
                disabled={isLoading}
              />
            </label>

            <label>
              Role
              <select
                value={formValues.role}
                onChange={(event) => setFormValues((current) => ({ ...current, role: event.target.value }))}
                disabled={isLoading}
              >
                <option value="farmer">Farmer</option>
                <option value="admin">Admin</option>
              </select>
            </label>

            {errorMessage && <div className="status error" aria-live="polite">{errorMessage}</div>}
            {successMessage && <div className="status success" aria-live="polite">{successMessage}</div>}

            <button type="submit" className="primary-button" disabled={isLoading}>
              {isLoading ? 'Creating account...' : 'Create account'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

export default App
