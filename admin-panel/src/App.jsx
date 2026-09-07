import { useMemo, useState, useEffect } from 'react'
import './App.css'

const emptyForm = {
  name: '',
  email: '',
  password: '',
  phone: '',
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

function validatePhone(value) {
  return value && String(value).trim().length > 0
}

function App() {
  const [authMode, setAuthMode] = useState('signin')
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [successMessage, setSuccessMessage] = useState('')
  const [session, setSession] = useState(null)
  const [formValues, setFormValues] = useState(emptyForm)
  const [loginValues, setLoginValues] = useState(loginForm)
  const [activeSection, setActiveSection] = useState('overview')
  
  // Real backend states
  const [farmers, setFarmers] = useState([])
  const [farms, setFarms] = useState([])
  const [crops, setCrops] = useState([])
  const [activities, setActivities] = useState([])
  const [loadingData, setLoadingData] = useState(false)

  const userSummary = useMemo(() => {
    if (!session) return null
    return `${session.name} · ${session.role}`
  }, [session])

  // Fetch all real admin data from backend APIs
  const fetchAllData = async () => {
    try {
      setLoadingData(true)
      const [usersRes, farmsRes, cropsRes, activitiesRes] = await Promise.all([
        fetch('http://localhost:5000/api/admin/users'),
        fetch('http://localhost:5000/api/admin/farms'),
        fetch('http://localhost:5000/api/admin/crops'),
        fetch('http://localhost:5000/api/admin/activities')
      ])

      if (usersRes.ok) {
        const usersData = await usersRes.json()
        setFarmers(usersData)
      }

      if (farmsRes.ok) {
        const farmsData = await farmsRes.json()
        setFarms(farmsData)
      }

      if (cropsRes.ok) {
        const cropsData = await cropsRes.json()
        setCrops(cropsData)
      }

      if (activitiesRes.ok) {
        const activitiesData = await activitiesRes.json()
        setActivities(activitiesData)
      }
    } catch (err) {
      console.error('Error fetching admin data:', err)
    } finally {
      setLoadingData(false)
    }
  }

  useEffect(() => {
    if (session) {
      fetchAllData()
    }
  }, [session])

  const handleDeleteUser = async (id, name) => {
    if (!window.confirm(`Are you sure you want to remove ${name}?`)) return
    try {
      const res = await fetch(`http://localhost:5000/api/admin/users/${id}`, {
        method: 'DELETE',
      })
      if (res.ok) {
        setFarmers((current) => current.filter((f) => f._id !== id))
        setSuccessMessage(`User ${name} deleted successfully.`)
      } else {
        alert('Failed to delete user.')
      }
    } catch (err) {
      alert(err.message)
    }
  }

  const handleRoleChange = async (id, name, newRole) => {
    const actionText = newRole === 'admin' ? 'promote to Admin' : 'demote to Farmer'
    if (!window.confirm(`Are you sure you want to ${actionText} for ${name}?`)) return

    try {
      const res = await fetch(`http://localhost:5000/api/admin/users/${id}/role`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: newRole }),
      })

      const data = await res.json()
      if (res.ok) {
        setFarmers((current) =>
          current.map((user) => (user._id === id ? { ...user, role: newRole } : user))
        )
        setSuccessMessage(`${name} has been successfully updated to ${newRole}.`)
      } else {
        alert(data.error || 'Failed to update role')
      }
    } catch (err) {
      alert(err.message)
    }
  }

  const handleSignIn = async (event) => {
    event.preventDefault()
    setIsLoading(true)
    setErrorMessage('')
    setSuccessMessage('')

    try {
      if (!validateEmail(loginValues.email)) {
        throw new Error('Please enter a valid email address.')
      }

      if (!loginValues.password) {
        throw new Error('Password is required.')
      }

      const response = await fetch('http://localhost:5000/api/auth/signin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: loginValues.email, password: loginValues.password }),
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || 'Invalid email or password.')
      }

      if (data.user.role !== 'admin') {
        throw new Error('Access denied! Only registered Admins can access this panel.')
      }

      localStorage.setItem('adminToken', data.token)
      setSession(data.user)
      setSuccessMessage(`Welcome back, ${data.user.name}.`) 
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
      if (!formValues.name.trim()) throw new Error('Full name is required.')
      if (!validateEmail(formValues.email)) throw new Error('Please enter a valid email address.')
      if (!validatePassword(formValues.password)) throw new Error('Password must be 8+ chars with uppercase, lowercase, and a number.')
      if (!validatePhone(formValues.phone)) throw new Error('Phone number is required.')

      const response = await fetch('http://localhost:5000/api/auth/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: formValues.name.trim(),
          email: formValues.email.trim(),
          password: formValues.password,
          phone: formValues.phone.trim(),
          role: 'admin',
        }),
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || 'An error occurred during signup.')
      }

      setSuccessMessage('Admin account created successfully. Please sign in.')
      setFormValues(emptyForm)
      setAuthMode('signin')

    } catch (error) {
      setErrorMessage(error.message)
    } finally {
      setIsLoading(false)
    }
  }

  const handleSignOut = () => {
    localStorage.removeItem('adminToken')
    setSession(null)
    setFarmers([])
    setFarms([])
    setCrops([])
    setActivities([])
    setErrorMessage('')
    setSuccessMessage('You have been signed out.')
  }

  if (session) {
    const farmerUsers = farmers.filter((u) => u.role === 'farmer')
    const adminUsers = farmers.filter((u) => u.role === 'admin')

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
            <button type="button" className={`nav-item ${activeSection === 'overview' ? 'active' : ''}`} onClick={() => setActiveSection('overview')}>Overview</button>
            <button type="button" className={`nav-item ${activeSection === 'farmers' ? 'active' : ''}`} onClick={() => setActiveSection('farmers')}>Farmers</button>
            <button type="button" className={`nav-item ${activeSection === 'admins' ? 'active' : ''}`} onClick={() => setActiveSection('admins')}>Admins</button>
            <button type="button" className={`nav-item ${activeSection === 'farms' ? 'active' : ''}`} onClick={() => setActiveSection('farms')}>Farms</button>
            <button type="button" className={`nav-item ${activeSection === 'crops' ? 'active' : ''}`} onClick={() => setActiveSection('crops')}>Crops</button>
            <button type="button" className={`nav-item ${activeSection === 'activities' ? 'active' : ''}`} onClick={() => setActiveSection('activities')}>Activities</button>
            <button type="button" className={`nav-item ${activeSection === 'reports' ? 'active' : ''}`} onClick={() => setActiveSection('reports')}>Reports</button>
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
              <p className="eyebrow">{activeSection === 'overview' ? 'Welcome' : activeSection.charAt(0).toUpperCase() + activeSection.slice(1)}</p>
              <h2>{activeSection === 'overview' ? userSummary : activeSection.charAt(0).toUpperCase() + activeSection.slice(1)}</h2>
            </div>
            <button type="button" className="primary-button" onClick={fetchAllData}>
              ↻ Refresh Data
            </button>
          </header>

          {/* 1. OVERVIEW SECTION */}
          {activeSection === 'overview' && (
            <section className="stats-grid">
              <article className="stat-card">
                <label>Total Registered Users</label>
                <strong>{farmers.length}</strong>
                <span>Active records</span>
              </article>
              <article className="stat-card">
                <label>Active Farmers</label>
                <strong>{farmerUsers.length}</strong>
                <span>Direct producers</span>
              </article>
              <article className="stat-card">
                <label>Total Farms Registered</label>
                <strong>{farms.length}</strong>
                <span>Fields recorded</span>
              </article>
              <article className="stat-card">
                <label>Total Crops Tracked</label>
                <strong>{crops.length}</strong>
                <span>Live fields</span>
              </article>
            </section>
          )}

          {/* 2. FARMERS SECTION */}
          {activeSection === 'farmers' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Farmer Name</th>
                      <th>Email</th>
                      <th>Phone</th>
                      <th>Location</th>
                      <th>Role</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {loadingData ? (
                      <tr>
                        <td colSpan="6" style={{ textAlign: 'center', padding: '20px' }}>Loading farmers...</td>
                      </tr>
                    ) : farmerUsers.length > 0 ? (
                      farmerUsers.map((farmer) => (
                        <tr key={farmer._id}>
                          <td><strong>{farmer.name}</strong></td>
                          <td>{farmer.email}</td>
                          <td>{farmer.phone || 'N/A'}</td>
                          <td>{farmer.village ? `${farmer.village}, ${farmer.district}` : (farmer.district || 'N/A')}</td>
                          <td><span className="badge active">{farmer.role || 'farmer'}</span></td>
                          <td>
                            <button
                              type="button"
                              style={{
                                background: '#dcfce7',
                                color: '#15803d',
                                border: 'none',
                                padding: '6px 10px',
                                borderRadius: '4px',
                                cursor: 'pointer',
                                fontWeight: '600',
                                marginRight: '8px'
                              }}
                              onClick={() => handleRoleChange(farmer._id, farmer.name, 'admin')}
                            >
                              Make Admin
                            </button>
                            <button
                              type="button"
                              style={{
                                background: '#fee2e2',
                                color: '#b91c1c',
                                border: 'none',
                                padding: '6px 10px',
                                borderRadius: '4px',
                                cursor: 'pointer',
                                fontWeight: '600'
                              }}
                              onClick={() => handleDeleteUser(farmer._id, farmer.name)}
                            >
                              Delete
                            </button>
                          </td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan="6" style={{ textAlign: 'center', padding: '20px', color: '#999' }}>No farmers registered yet.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 3. ADMINS SECTION */}
          {activeSection === 'admins' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Admin Name</th>
                      <th>Email</th>
                      <th>Phone</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {loadingData ? (
                      <tr>
                        <td colSpan="5" style={{ textAlign: 'center', padding: '20px' }}>Loading administrators...</td>
                      </tr>
                    ) : adminUsers.length > 0 ? (
                      adminUsers.map((adminItem) => (
                        <tr key={adminItem._id}>
                          <td><strong>{adminItem.name}</strong></td>
                          <td>{adminItem.email}</td>
                          <td>{adminItem.phone || 'N/A'}</td>
                          <td><span className="badge active" style={{ background: '#e0e7ff', color: '#4338ca' }}>Admin</span></td>
                          <td>
                            {adminItem._id !== session._id ? (
                              <button
                                type="button"
                                style={{
                                  background: '#fef3c7',
                                  color: '#92400e',
                                  border: 'none',
                                  padding: '6px 10px',
                                  borderRadius: '4px',
                                  cursor: 'pointer',
                                  fontWeight: '600',
                                  marginRight: '8px'
                                }}
                                onClick={() => handleRoleChange(adminItem._id, adminItem.name, 'farmer')}
                              >
                                Demote to Farmer
                              </button>
                            ) : (
                              <span style={{ color: '#9ca3af', fontSize: '13px', fontStyle: 'italic', marginRight: '8px' }}>Current User</span>
                            )}

                            {adminItem._id !== session._id && (
                              <button
                                type="button"
                                style={{
                                  background: '#fee2e2',
                                  color: '#b91c1c',
                                  border: 'none',
                                  padding: '6px 10px',
                                  borderRadius: '4px',
                                  cursor: 'pointer',
                                  fontWeight: '600'
                                }}
                                onClick={() => handleDeleteUser(adminItem._id, adminItem.name)}
                              >
                                Delete
                              </button>
                            )}
                          </td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan="5" style={{ textAlign: 'center', padding: '20px', color: '#999' }}>No admins found.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 4. FARMS SECTION (WITH DESCRIPTION & AI CONTEXT) */}
          {activeSection === 'farms' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Farm Name & Description</th>
                      <th>Farmer Name</th>
                      <th>Land Size</th>
                      <th>Location</th>
                      <th>Soil Type</th>
                      <th>Soil pH</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {loadingData ? (
                      <tr>
                        <td colSpan="7" style={{ textAlign: 'center', padding: '20px' }}>Loading farms...</td>
                      </tr>
                    ) : farms.length > 0 ? (
                      farms.map((farm) => (
                        <tr key={farm._id}>
                          <td>
                            <strong>{farm.name}</strong>
                            {farm.description ? (
                              <div style={{
                                fontSize: '12px',
                                color: '#065f46',
                                background: '#ecfdf5',
                                padding: '4px 8px',
                                borderRadius: '6px',
                                marginTop: '6px',
                                maxWidth: '260px',
                                border: '1px solid #d1fae5',
                                lineHeight: '1.4'
                              }}>
                                📝 <em>{farm.description}</em>
                              </div>
                            ) : (
                              <div style={{ fontSize: '11px', color: '#9ca3af', marginTop: '4px', fontStyle: 'italic' }}>
                                No specific notes
                              </div>
                            )}
                          </td>
                          <td>
                            <div>{farm.userId?.name || 'Unknown'}</div>
                            <div style={{ fontSize: '12px', color: '#6b7280' }}>{farm.userId?.phone || farm.userId?.email || ''}</div>
                          </td>
                          <td>{farm.landSize} {farm.unit || 'Acres'}</td>
                          <td>{farm.location || 'N/A'}</td>
                          <td><span className="badge" style={{ background: '#f0fdf4', color: '#166534' }}>{farm.soilType}</span></td>
                          <td>{farm.ph ?? 'N/A'}</td>
                          <td><span className="badge active">{farm.status || 'active'}</span></td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan="7" style={{ textAlign: 'center', padding: '20px', color: '#999' }}>No farms registered yet.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 5. CROPS SECTION */}
          {activeSection === 'crops' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Crop Type & Variety</th>
                      <th>Farmer</th>
                      <th>Farm Name</th>
                      <th>Stage</th>
                      <th>Total Expense</th>
                      <th>Sowing Date</th>
                      <th>Expected Harvest</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {loadingData ? (
                      <tr>
                        <td colSpan="8" style={{ textAlign: 'center', padding: '20px' }}>Loading crops...</td>
                      </tr>
                    ) : crops.length > 0 ? (
                      crops.map((crop) => (
                        <tr key={crop._id}>
                          <td>
                            <strong>{crop.cropType}</strong>
                            {crop.variety && <div style={{ fontSize: '12px', color: '#6b7280' }}>{crop.variety}</div>}
                          </td>
                          <td>
                            <div>{crop.userId?.name || 'N/A'}</div>
                            <div style={{ fontSize: '12px', color: '#6b7280' }}>{crop.userId?.phone || ''}</div>
                          </td>
                          <td>{crop.farmId?.name || 'Main Field'}</td>
                          <td><span className="badge pending">{crop.currentStage}</span></td>
                          <td><strong>৳{crop.totalExpense || 0}</strong></td>
                          <td>{crop.sowingDate ? new Date(crop.sowingDate).toLocaleDateString() : 'N/A'}</td>
                          <td>{crop.expectedHarvestDate ? new Date(crop.expectedHarvestDate).toLocaleDateString() : 'N/A'}</td>
                          <td><span className="badge active">{crop.status}</span></td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan="8" style={{ textAlign: 'center', padding: '20px', color: '#999' }}>No crops planted by farmers yet.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 6. ACTIVITIES SECTION */}
          {activeSection === 'activities' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Activity Title</th>
                      <th>Type</th>
                      <th>Farmer</th>
                      <th>Crop</th>
                      <th>Scheduled Date</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {loadingData ? (
                      <tr>
                        <td colSpan="6" style={{ textAlign: 'center', padding: '20px' }}>Loading activities...</td>
                      </tr>
                    ) : activities.length > 0 ? (
                      activities.map((task) => (
                        <tr key={task._id}>
                          <td>
                            <strong>{task.title}</strong>
                            {task.isUrgent && <span style={{ marginLeft: '6px', color: '#dc2626', fontSize: '11px', fontWeight: 'bold' }}>[URGENT]</span>}
                          </td>
                          <td><span className="badge" style={{ background: '#f3f4f6', color: '#374151' }}>{task.activityType}</span></td>
                          <td>{task.userId?.name || 'N/A'}</td>
                          <td>{task.cropId?.cropType || 'General'}</td>
                          <td>{task.scheduledDate ? new Date(task.scheduledDate).toLocaleDateString() : 'N/A'}</td>
                          <td>
                            <span className={`badge ${task.status === 'Completed' ? 'completed' : 'pending'}`}>
                              {task.status}
                            </span>
                          </td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan="6" style={{ textAlign: 'center', padding: '20px', color: '#999' }}>No scheduled activities yet.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 7. REPORTS SECTION */}
          {activeSection === 'reports' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Problem</th>
                      <th>Crop</th>
                      <th>Farmer</th>
                      <th>Reported Date</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td colSpan="5" style={{ textAlign: 'center', padding: '20px', color: '#999' }}>No pest or disease reports submitted yet.</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          )}

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
              Phone
              <input
                type="tel"
                value={formValues.phone}
                onChange={(event) => setFormValues((current) => ({ ...current, phone: event.target.value }))}
                placeholder="Your phone number"
                disabled={isLoading}
              />
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