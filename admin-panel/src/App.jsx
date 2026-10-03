import { useMemo, useState, useEffect } from 'react'
import ExpertPanel from './ExpertPanel'
import './App.css'

const emptyAdminSignup = {
  name: '',
  email: '',
  password: '',
  phone: '',
}

const loginForm = {
  email: '',
  password: '',
}

const initialNewExpertForm = {
  name: '',
  email: '',
  password: '',
  phone: '',
  designation: 'উপজেলা কৃষি কর্মকর্তা',
  specialization: 'ফসল ও মাটি বিশেষজ্ঞ',
  district: 'Khulna',
  dutyHours: 'সকাল ৯:০০ - বিকাল ৫:০০',
}

function validateEmail(value) {
  const clean = String(value || '').trim()
  return /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]*[a-zA-Z][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$/.test(clean)
}

function validatePassword(value) {
  return value.length >= 8 && /[A-Z]/.test(value) && /[a-z]/.test(value) && /[0-9]/.test(value)
}

function validatePhone(value) {
  const digits = String(value || '').replace(/[^0-9]/g, '')
  return digits.length >= 11
}

function App() {
  const [authMode, setAuthMode] = useState('expert_signin')
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [successMessage, setSuccessMessage] = useState('')
  const [session, setSession] = useState(null)
  const [formValues, setFormValues] = useState(emptyAdminSignup)
  const [loginValues, setLoginValues] = useState(loginForm)
  const [activeSection, setActiveSection] = useState('overview')

  // Password visibility states
  const [showLoginPassword, setShowLoginPassword] = useState(false)
  const [showSignupPassword, setShowSignupPassword] = useState(false)
  const [showExpertModalPassword, setShowExpertModalPassword] = useState(false)

  // Real backend states
  const [users, setUsers] = useState([])
  const [farms, setFarms] = useState([])
  const [crops, setCrops] = useState([])
  const [activities, setActivities] = useState([])
  const [allIssues, setAllIssues] = useState([])
  const [issueFilter, setIssueFilter] = useState('all') // 'all' | 'Pending_Expert' | 'Expert_Resolved' | 'AI_Resolved'
  const [selectedExpertFilter, setSelectedExpertFilter] = useState('all')
  const [loadingData, setLoadingData] = useState(false)

  // Expert Modal states
  const [showCreateExpertModal, setShowCreateExpertModal] = useState(false)
  const [editingExpert, setEditingExpert] = useState(null)
  const [expertForm, setExpertForm] = useState(initialNewExpertForm)
  const [creatingExpert, setCreatingExpert] = useState(false)
  const [modalError, setModalError] = useState('')

  useEffect(() => {
    const savedUser = localStorage.getItem('portalSessionUser')
    const savedToken = localStorage.getItem('adminToken')
    if (savedUser && savedToken) {
      try {
        setSession(JSON.parse(savedUser))
      } catch (e) {
        localStorage.removeItem('portalSessionUser')
      }
    }
  }, [])

  const userSummary = useMemo(() => {
    if (!session) return null
    return `${session.name} · ${session.role.toUpperCase()}`
  }, [session])

  const fetchAllData = async () => {
    try {
      setLoadingData(true)
      const [usersRes, farmsRes, cropsRes, activitiesRes, issuesRes] = await Promise.all([
        fetch('http://localhost:5000/api/admin/users'),
        fetch('http://localhost:5000/api/admin/farms'),
        fetch('http://localhost:5000/api/admin/crops'),
        fetch('http://localhost:5000/api/admin/activities'),
        fetch('http://localhost:5000/api/admin/issues/all'),
      ])

      if (usersRes.ok) setUsers(await usersRes.json())
      if (farmsRes.ok) setFarms(await farmsRes.json())
      if (cropsRes.ok) setCrops(await cropsRes.json())
      if (activitiesRes.ok) setActivities(await activitiesRes.json())
      if (issuesRes.ok) setAllIssues(await issuesRes.json())
    } catch (err) {
      console.error('Error fetching admin data:', err)
    } finally {
      setLoadingData(false)
    }
  }

  useEffect(() => {
    if (session && session.role === 'admin') {
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
        setUsers((current) => current.filter((u) => u._id !== id))
        setSuccessMessage(`Account "${name}" removed.`)
      } else {
        alert('Failed to delete account.')
      }
    } catch (err) {
      alert(err.message)
    }
  }

  const handleToggleTopFarmer = async (farmer) => {
    const nextStatus = !farmer.isTopFarmer
    try {
      const res = await fetch(`http://localhost:5000/api/admin/users/${farmer._id}/role`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          role: 'farmer',
          isTopFarmer: nextStatus,
          badgeTitle: nextStatus ? 'Top Farmer 🌟' : 'Active Farmer',
        }),
      })
      const data = await res.json()
      if (res.ok) {
        setUsers((curr) => curr.map((u) => (u._id === farmer._id ? data.user : u)))
        setSuccessMessage(`${farmer.name} is now ${nextStatus ? 'a Top Farmer 🌟' : 'an Active Farmer'}.`)
      }
    } catch (err) {
      alert('Failed to update badge.')
    }
  }

  const handleSaveExpertAccount = async (e) => {
    e.preventDefault()
    setModalError('')

    const cleanName = expertForm.name.trim()
    const cleanEmail = expertForm.email.toLowerCase().trim()
    const cleanPhone = expertForm.phone.trim()
    const cleanPass = expertForm.password.trim()

    if (!validatePhone(cleanPhone)) {
      setModalError('Please enter a valid 11-digit phone number.')
      return
    }

    if (!editingExpert) {
      if (!cleanName) {
        setModalError('Full name is required.')
        return
      }
      if (!validateEmail(cleanEmail)) {
        setModalError('Invalid email format! Please enter a valid email (e.g. expert@gmail.com).')
        return
      }
      if (cleanPass.length < 6) {
        setModalError('Password must be at least 6 characters long.')
        return
      }
    }

    setCreatingExpert(true)
    try {
      if (editingExpert) {
        const res = await fetch(`http://localhost:5000/api/admin/users/${editingExpert._id}/role`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            role: 'expert',
            designation: expertForm.designation.trim(),
            specialization: expertForm.specialization.trim(),
            district: expertForm.district.trim(),
            hotlineNumber: cleanPhone,
            whatsappNumber: cleanPhone,
            dutyHours: expertForm.dutyHours.trim(),
          }),
        })
        const data = await res.json()
        if (!res.ok) throw new Error(data.error || 'Failed to update expert')

        setUsers((curr) => curr.map((u) => (u._id === editingExpert._id ? data.user : u)))
        setSuccessMessage(`Expert "${editingExpert.name}" updated successfully.`)
      } else {
        const res = await fetch('http://localhost:5000/api/auth/signup', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: cleanName,
            email: cleanEmail,
            password: cleanPass,
            phone: cleanPhone,
            role: 'expert',
            district: expertForm.district.trim(),
            designation: expertForm.designation.trim(),
            specialization: expertForm.specialization.trim(),
            hotlineNumber: cleanPhone,
            whatsappNumber: cleanPhone,
            dutyHours: expertForm.dutyHours.trim(),
          }),
        })
        const data = await res.json()
        if (!res.ok) throw new Error(data.error || 'Failed to create expert account')

        const createdExpert = { ...data.user, _id: data.user._id || data.user.id }
        setUsers((curr) => [createdExpert, ...curr])
        setSuccessMessage(`Expert account created for ${createdExpert.name}.`)
      }

      setShowCreateExpertModal(false)
      setEditingExpert(null)
      setExpertForm(initialNewExpertForm)
      setModalError('')
    } catch (err) {
      setModalError(err.message)
    } finally {
      setCreatingExpert(false)
    }
  }

  const handleSignIn = async (event) => {
    event.preventDefault()
    setIsLoading(true)
    setErrorMessage('')
    setSuccessMessage('')

    try {
      if (!validateEmail(loginValues.email.trim())) {
        throw new Error('Please enter a valid email address (e.g. user@gmail.com).')
      }
      if (!loginValues.password) {
        throw new Error('Password is required.')
      }

      const response = await fetch('http://localhost:5000/api/auth/signin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: loginValues.email.toLowerCase().trim(),
          password: loginValues.password.trim(),
        }),
      })

      const data = await response.json()
      if (!response.ok) {
        throw new Error(data.error || 'Invalid email or password.')
      }

      if (authMode === 'expert_signin' && data.user.role !== 'expert') {
        throw new Error(`This account belongs to ${data.user.role.toUpperCase()}. Please use Admin Login.`)
      }
      if (authMode === 'admin_signin' && data.user.role !== 'admin') {
        throw new Error(`This account belongs to ${data.user.role.toUpperCase()}. Please use Expert Login.`)
      }

      localStorage.setItem('adminToken', data.token)
      localStorage.setItem('portalSessionUser', JSON.stringify(data.user))
      setSession(data.user)
      setLoginValues(loginForm)
    } catch (error) {
      setErrorMessage(error.message)
    } finally {
      setIsLoading(false)
    }
  }

  const handleAdminSignUp = async (event) => {
    event.preventDefault()
    setIsLoading(true)
    setErrorMessage('')
    setSuccessMessage('')

    try {
      if (!formValues.name.trim()) throw new Error('Full name is required.')
      if (!validateEmail(formValues.email.trim())) throw new Error('Please enter a valid email address (e.g. admin@gmail.com).')
      if (!validatePassword(formValues.password)) throw new Error('Password must be 8+ chars with uppercase, lowercase, and a number.')
      if (!validatePhone(formValues.phone.trim())) throw new Error('Please enter a valid 11-digit phone number.')

      const response = await fetch('http://localhost:5000/api/auth/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: formValues.name.trim(),
          email: formValues.email.toLowerCase().trim(),
          password: formValues.password.trim(),
          phone: formValues.phone.trim(),
          role: 'admin',
        }),
      })

      const data = await response.json()
      if (!response.ok) {
        throw new Error(data.error || 'An error occurred during signup.')
      }

      setSuccessMessage('Admin account created! Please sign in.')
      setLoginValues({ email: formValues.email.trim(), password: formValues.password })
      setFormValues(emptyAdminSignup)
      setAuthMode('admin_signin')
    } catch (error) {
      setErrorMessage(error.message)
    } finally {
      setIsLoading(false)
    }
  }

  const handleSignOut = () => {
    localStorage.removeItem('adminToken')
    localStorage.removeItem('portalSessionUser')
    setSession(null)
    setUsers([])
    setFarms([])
    setCrops([])
    setActivities([])
    setAllIssues([])
    setErrorMessage('')
    setSuccessMessage('You have been signed out.')
  }

  // 1. EXPERT WORKSPACE
  if (session && session.role === 'expert') {
    return (
      <ExpertPanel
        sessionUser={session}
        onSessionUpdate={(updatedUser) => {
          setSession(updatedUser)
          localStorage.setItem('portalSessionUser', JSON.stringify(updatedUser))
        }}
        onSignOut={handleSignOut}
      />
    )
  }

  // 2. ADMIN CONTROL PANEL
  if (session && session.role === 'admin') {
    const farmerUsers = users.filter((u) => u.role === 'farmer')
    const expertUsers = users.filter((u) => u.role === 'expert')
    const adminUsers = users.filter((u) => u.role === 'admin')

    const pendingExpertIssues = allIssues.filter((i) => i.status === 'Pending_Expert')
    const solvedByExpertIssues = allIssues.filter((i) => i.status === 'Expert_Resolved')
    const aiResolvedIssues = allIssues.filter((i) => i.status === 'AI_Resolved')

    // নির্দিষ্ট একটি ইস্যু কোনো নির্দিষ্ট বিশেষজ্ঞের আওতায় পড়ে কি না তা চেক করার হেল্পার
    const doesIssueBelongToExpert = (issue, exp) => {
      if (!exp) return false
      const assignedId = issue.assignedExpert?._id || issue.assignedExpert
      const resolvedId = issue.resolvedBy?._id || issue.resolvedBy

      if (assignedId && assignedId === exp._id) return true
      if (resolvedId && resolvedId === exp._id) return true
      if ((issue.expertReply || '').includes(exp.name)) return true

      // যদি রিপোর্টে নির্দিষ্ট কারো আইডি না থাকে (পুরনো রিপোর্ট), তবে জেলা মিলিয়ে দেখা হবে
      if (!assignedId && !resolvedId && issue.status === 'Pending_Expert') {
        const expDist = (exp.district || '').trim().toLowerCase()
        const issueDist = (issue.userId?.district || issue.cropId?.farmId?.location || '').trim().toLowerCase()
        if (expDist && issueDist && issueDist.includes(expDist)) return true
      }
      return false
    }

    // প্রতিটি বিশেষজ্ঞের নিজস্ব Pending সংখ্যা (আলাদাভাবে)
    const getExpertPendingCount = (exp) => {
      return pendingExpertIssues.filter((i) => doesIssueBelongToExpert(i, exp)).length
    }

    // প্রতিটি বিশেষজ্ঞের নিজস্ব Solved সংখ্যা (আলাদাভাবে)
    const getExpertSolvedCount = (exp) => {
      const matchedSolved = solvedByExpertIssues.filter((i) => doesIssueBelongToExpert(i, exp)).length
      return Math.max(exp.resolvedIssuesCount || 0, matchedSolved)
    }

    // Consultations ট্যাবের জন্য স্ট্যাটাস এবং নির্বাচিত বিশেষজ্ঞ অনুযায়ী ফিল্টার
    const selectedExpertObj = expertUsers.find((e) => e._id === selectedExpertFilter)
    const filteredIssues = allIssues.filter((i) => {
      const matchesStatus = issueFilter === 'all' ? true : i.status === issueFilter
      if (!matchesStatus) return false
      if (selectedExpertFilter === 'all') return true
      return doesIssueBelongToExpert(i, selectedExpertObj)
    })

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
            <button type="button" className={`nav-item ${activeSection === 'experts' ? 'active' : ''}`} onClick={() => setActiveSection('experts')}>Experts ({expertUsers.length})</button>
            <button
              type="button"
              className={`nav-item ${activeSection === 'consultations' ? 'active' : ''}`}
              onClick={() => {
                setSelectedExpertFilter('all')
                setActiveSection('consultations')
              }}
            >
              Consultations ({pendingExpertIssues.length} Pending)
            </button>
            <button type="button" className={`nav-item ${activeSection === 'farmers' ? 'active' : ''}`} onClick={() => setActiveSection('farmers')}>Farmers ({farmerUsers.length})</button>
            <button type="button" className={`nav-item ${activeSection === 'admins' ? 'active' : ''}`} onClick={() => setActiveSection('admins')}>Admins ({adminUsers.length})</button>
            <button type="button" className={`nav-item ${activeSection === 'farms' ? 'active' : ''}`} onClick={() => setActiveSection('farms')}>Farms ({farms.length})</button>
            <button type="button" className={`nav-item ${activeSection === 'crops' ? 'active' : ''}`} onClick={() => setActiveSection('crops')}>Crops ({crops.length})</button>
            <button type="button" className={`nav-item ${activeSection === 'activities' ? 'active' : ''}`} onClick={() => setActiveSection('activities')}>Activities</button>
          </nav>

          <div className="profile-card">
            <strong>{session.name}</strong>
            <span>System Admin</span>
            <button type="button" onClick={handleSignOut}>Sign out</button>
          </div>
        </aside>

        <main className="dashboard-main">
          <header className="topbar">
            <div>
              <p className="eyebrow">{activeSection === 'overview' ? 'Welcome' : activeSection.toUpperCase()}</p>
              <h2>{activeSection === 'overview' ? userSummary : activeSection.charAt(0).toUpperCase() + activeSection.slice(1)}</h2>
            </div>
            <div style={{ display: 'flex', gap: '10px' }}>
              {activeSection === 'experts' && (
                <button
                  type="button"
                  className="primary-button"
                  onClick={() => {
                    setEditingExpert(null)
                    setExpertForm(initialNewExpertForm)
                    setModalError('')
                    setShowCreateExpertModal(true)
                  }}
                >
                  + Add Expert
                </button>
              )}
              <button type="button" className="primary-button" onClick={fetchAllData}>
                ↻ Refresh
              </button>
            </div>
          </header>

          {successMessage && <div className="status success" style={{ marginBottom: '16px' }}>{successMessage}</div>}

          {/* 1. OVERVIEW */}
          {activeSection === 'overview' && (
            <>
              <section className="stats-grid" style={{ marginBottom: '20px' }}>
                <article className="stat-card">
                  <label>Total Farmers</label>
                  <strong>{farmerUsers.length}</strong>
                  <span>Registered farmers</span>
                </article>
                <article className="stat-card">
                  <label>Agricultural Experts</label>
                  <strong>{expertUsers.length}</strong>
                  <span>Officers on duty</span>
                </article>
                <article className="stat-card" style={{ borderLeft: '4px solid #f59e0b' }}>
                  <label>Pending for Experts</label>
                  <strong style={{ color: '#d97706' }}>{pendingExpertIssues.length}</strong>
                  <span>Awaiting expert reply</span>
                </article>
                <article className="stat-card" style={{ borderLeft: '4px solid #10b981' }}>
                  <label>Solved by Experts</label>
                  <strong style={{ color: '#059669' }}>{solvedByExpertIssues.length}</strong>
                  <span>Prescriptions delivered</span>
                </article>
              </section>

              <section className="stats-grid">
                <article className="stat-card">
                  <label>Total Farms</label>
                  <strong>{farms.length}</strong>
                  <span>Cultivated plots</span>
                </article>
                <article className="stat-card">
                  <label>Total Crops</label>
                  <strong>{crops.length}</strong>
                  <span>Live & harvested</span>
                </article>
                <article className="stat-card">
                  <label>Primary Advice Given</label>
                  <strong>{aiResolvedIssues.length}</strong>
                  <span>Instant crop doctor</span>
                </article>
                <article className="stat-card">
                  <label>Scheduled Activities</label>
                  <strong>{activities.length}</strong>
                  <span>Total farming tasks</span>
                </article>
              </section>
            </>
          )}

          {/* 2. EXPERTS (প্রতিটি বিশেষজ্ঞের আলাদা Pending ও Solved সংখ্যা দেখাবে) */}
          {activeSection === 'experts' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Name & Email</th>
                      <th>Designation</th>
                      <th>Station & Hours</th>
                      <th>Hotline</th>
                      <th>Pending Load</th>
                      <th>Solved Cases</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {loadingData ? (
                      <tr><td colSpan="8" style={{ textAlign: 'center', padding: '24px' }}>Loading experts...</td></tr>
                    ) : expertUsers.length > 0 ? (
                      expertUsers.map((exp) => {
                        const pendingCnt = getExpertPendingCount(exp)
                        const solvedCnt = getExpertSolvedCount(exp)
                        return (
                          <tr key={exp._id}>
                            <td>
                              <strong>{exp.name}</strong>
                              <div style={{ fontSize: '12px', color: '#6b7280' }}>{exp.email}</div>
                            </td>
                            <td>
                              <div style={{ fontWeight: '600', color: '#18392d' }}>{exp.designation || 'উপজেলা কৃষি কর্মকর্তা'}</div>
                              <div style={{ fontSize: '12px', color: '#6b7280' }}>{exp.specialization || 'ফসল বিশেষজ্ঞ'}</div>
                            </td>
                            <td>
                              <div>📍 {exp.district || 'Khulna'}</div>
                              <div style={{ fontSize: '12px', color: '#6b7280' }}>{exp.dutyHours || 'সকাল ৯:০০ - বিকাল ৫:০০'}</div>
                            </td>
                            <td>{exp.hotlineNumber || exp.phone || 'N/A'}</td>
                            <td>
                              <span
                                onClick={() => {
                                  setSelectedExpertFilter(exp._id)
                                  setIssueFilter('Pending_Expert')
                                  setActiveSection('consultations')
                                }}
                                title="Click to view this expert's pending reports"
                                style={{ background: pendingCnt > 0 ? '#fef3c7' : '#f1f5f9', color: pendingCnt > 0 ? '#b45309' : '#64748b', padding: '5px 11px', borderRadius: '99px', fontSize: '12px', fontWeight: '700', cursor: 'pointer', display: 'inline-block' }}
                              >
                                ⏳ {pendingCnt} Pending
                              </span>
                            </td>
                            <td>
                              <span
                                onClick={() => {
                                  setSelectedExpertFilter(exp._id)
                                  setIssueFilter('Expert_Resolved')
                                  setActiveSection('consultations')
                                }}
                                title="Click to view this expert's solved reports"
                                style={{ background: '#dcfce7', color: '#15803d', padding: '5px 11px', borderRadius: '99px', fontSize: '12px', fontWeight: '700', cursor: 'pointer', display: 'inline-block' }}
                              >
                                ✓ {solvedCnt} Solved
                              </span>
                            </td>
                            <td>
                              <span className="badge" style={{ background: exp.isAvailable !== false ? '#dcfce7' : '#f3f4f6', color: exp.isAvailable !== false ? '#166534' : '#6b7280' }}>
                                {exp.isAvailable !== false ? 'Online' : 'Offline'}
                              </span>
                            </td>
                            <td>
                              <button
                                type="button"
                                style={{ background: '#e0f2fe', color: '#0369a1', border: 'none', padding: '6px 10px', borderRadius: '6px', cursor: 'pointer', fontWeight: '600', marginRight: '6px' }}
                                onClick={() => {
                                  setEditingExpert(exp)
                                  setExpertForm({
                                    name: exp.name,
                                    email: exp.email,
                                    password: '',
                                    phone: exp.hotlineNumber || exp.phone || '',
                                    designation: exp.designation || 'উপজেলা কৃষি কর্মকর্তা',
                                    specialization: exp.specialization || 'ফসল ও মাটি বিশেষজ্ঞ',
                                    district: exp.district || 'Khulna',
                                    dutyHours: exp.dutyHours || 'সকাল ৯:০০ - বিকাল ৫:০০',
                                  })
                                  setModalError('')
                                  setShowCreateExpertModal(true)
                                }}
                              >
                                Edit
                              </button>
                              <button
                                type="button"
                                style={{ background: '#fee2e2', color: '#b91c1c', border: 'none', padding: '6px 10px', borderRadius: '6px', cursor: 'pointer', fontWeight: '600' }}
                                onClick={() => handleDeleteUser(exp._id, exp.name)}
                              >
                                Delete
                              </button>
                            </td>
                          </tr>
                        )
                      })
                    ) : (
                      <tr>
                        <td colSpan="8" style={{ textAlign: 'center', padding: '28px', color: '#9ca3af' }}>
                          No experts added yet. Click "+ Add Expert" above to create an account.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 3. 🩺 CONSULTATIONS MONITOR (নির্দিষ্ট বিশেষজ্ঞ অনুযায়ী ফিল্টার ও অ্যাসাইনড কলামসহ) */}
          {activeSection === 'consultations' && (
            <section className="content-section">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', padding: '16px 20px', borderBottom: '1px solid #e5e7eb', flexWrap: 'wrap' }}>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    onClick={() => setIssueFilter('all')}
                    style={filterChipStyle(issueFilter === 'all')}
                  >
                    All Reports ({allIssues.length})
                  </button>
                  <button
                    type="button"
                    onClick={() => setIssueFilter('Pending_Expert')}
                    style={filterChipStyle(issueFilter === 'Pending_Expert', '#d97706')}
                  >
                    ⏳ Pending for Expert ({pendingExpertIssues.length})
                  </button>
                  <button
                    type="button"
                    onClick={() => setIssueFilter('Expert_Resolved')}
                    style={filterChipStyle(issueFilter === 'Expert_Resolved', '#15803d')}
                  >
                    ✅ Solved by Expert ({solvedByExpertIssues.length})
                  </button>
                  <button
                    type="button"
                    onClick={() => setIssueFilter('AI_Resolved')}
                    style={filterChipStyle(issueFilter === 'AI_Resolved', '#0369a1')}
                  >
                    📋 Primary Advice ({aiResolvedIssues.length})
                  </button>
                </div>

                {/* 👨‍🌾 Expert Filter Dropdown */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span style={{ fontSize: '12.5px', fontWeight: '600', color: '#475569' }}>Expert:</span>
                  <select
                    value={selectedExpertFilter}
                    onChange={(e) => setSelectedExpertFilter(e.target.value)}
                    style={{ padding: '7px 12px', borderRadius: '8px', border: '1px solid #cbd5e1', fontSize: '13px', fontWeight: '600', color: '#0f172a', background: '#f8fafc', cursor: 'pointer' }}
                  >
                    <option value="all">All Experts ({expertUsers.length})</option>
                    {expertUsers.map((ex) => (
                      <option key={ex._id} value={ex._id}>
                        {ex.name} ({ex.district || 'Khulna'}) — {getExpertPendingCount(ex)} Pending / {getExpertSolvedCount(ex)} Solved
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Farmer & Location</th>
                      <th>Crop Details</th>
                      <th>Reported Problem</th>
                      <th>Assigned Expert</th>
                      <th>Expert Prescription / Solution</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredIssues.length > 0 ? (
                      filteredIssues.map((issue) => {
                        // কোন বিশেষজ্ঞকে অ্যাসাইন করা হয়েছে বা কে সমাধান দিয়েছেন তা বের করা
                        let assignedExp = issue.assignedExpert || issue.resolvedBy
                        if (!assignedExp && issue.status === 'Pending_Expert') {
                          const issueDist = (issue.userId?.district || issue.cropId?.farmId?.location || '').trim().toLowerCase()
                          if (issueDist) {
                            assignedExp = expertUsers.find((e) => (e.district || '').trim().toLowerCase().includes(issueDist))
                          }
                        }

                        return (
                          <tr key={issue._id}>
                            <td>
                              <strong>{issue.userId?.name || 'Farmer'}</strong>
                              <div style={{ fontSize: '12px', color: '#6b7280' }}>{issue.userId?.phone || ''}</div>
                              <div style={{ fontSize: '11.5px', color: '#047857' }}>{issue.userId?.district || issue.cropId?.farmId?.location || ''}</div>
                            </td>
                            <td>
                              <strong>{issue.cropId?.cropType || 'Crop'}</strong>
                              <div style={{ fontSize: '12px', color: '#6b7280' }}>
                                {issue.cropId?.allocatedArea > 0 ? `${issue.cropId.allocatedArea} ${issue.cropId.areaUnit}` : issue.cropId?.currentStage}
                              </div>
                            </td>
                            <td style={{ maxWidth: '240px' }}>
                              <div style={{ fontWeight: '600', color: '#1e293b', fontSize: '13.5px' }}>{issue.issueText}</div>
                              <div style={{ fontSize: '11px', color: '#94a3b8', marginTop: '4px' }}>
                                {issue.createdAt ? new Date(issue.createdAt).toLocaleDateString() : ''}
                              </div>
                            </td>
                            <td>
                              {assignedExp ? (
                                <div>
                                  <strong style={{ color: '#0f172a', fontSize: '13px' }}>👨‍🌾 {assignedExp.name}</strong>
                                  <div style={{ fontSize: '11.5px', color: '#047857' }}>📍 {assignedExp.district || 'Khulna'}</div>
                                </div>
                              ) : (
                                <span style={{ fontSize: '12px', color: '#94a3b8' }}>Unassigned / Any Expert</span>
                              )}
                            </td>
                            <td style={{ maxWidth: '320px' }}>
                              {issue.expertReply ? (
                                <div style={{ background: '#f0fdf4', padding: '8px 10px', borderRadius: '8px', border: '1px solid #bbf7d0', fontSize: '12.5px', whiteSpace: 'pre-line', color: '#14532d' }}>
                                  {issue.expertReply}
                                </div>
                              ) : (
                                <div style={{ fontSize: '12px', color: issue.status === 'Pending_Expert' ? '#b45309' : '#64748b', fontWeight: issue.status === 'Pending_Expert' ? '600' : '400' }}>
                                  {issue.status === 'Pending_Expert'
                                    ? `⏳ Waiting for ${assignedExp?.name || 'Expert'}'s reply...`
                                    : (issue.aiAdvice ? `${issue.aiAdvice.slice(0, 100)}...` : 'N/A')}
                                </div>
                              )}
                            </td>
                            <td>
                              {issue.status === 'Pending_Expert' && (
                                <span className="badge" style={{ background: '#fef3c7', color: '#b45309' }}>Pending Expert</span>
                              )}
                              {issue.status === 'Expert_Resolved' && (
                                <span className="badge" style={{ background: '#dcfce7', color: '#15803d' }}>Expert Solved</span>
                              )}
                              {issue.status === 'AI_Resolved' && (
                                <span className="badge" style={{ background: '#e0f2fe', color: '#0369a1' }}>Primary Resolved</span>
                              )}
                            </td>
                          </tr>
                        )
                      })
                    ) : (
                      <tr>
                        <td colSpan="6" style={{ textAlign: 'center', padding: '28px', color: '#9ca3af' }}>
                          No consultation records found for this filter.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 4. FARMERS */}
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
                      <th>Badge</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {farmerUsers.map((farmer) => (
                      <tr key={farmer._id}>
                        <td><strong>{farmer.name}</strong></td>
                        <td>{farmer.email}</td>
                        <td>{farmer.phone || 'N/A'}</td>
                        <td>{farmer.village ? `${farmer.village}, ${farmer.district}` : (farmer.district || 'N/A')}</td>
                        <td>
                          <span className="badge" style={{ background: farmer.isTopFarmer ? '#fef3c7' : '#dcfce7', color: farmer.isTopFarmer ? '#b45309' : '#166534' }}>
                            {farmer.isTopFarmer ? 'Top Farmer 🌟' : 'Active Farmer'}
                          </span>
                        </td>
                        <td>
                          <button
                            type="button"
                            style={{ background: '#fef9c3', color: '#854d0e', border: '1px solid #fde047', padding: '6px 10px', borderRadius: '6px', cursor: 'pointer', fontWeight: '600', marginRight: '6px' }}
                            onClick={() => handleToggleTopFarmer(farmer)}
                          >
                            {farmer.isTopFarmer ? 'Remove Badge' : '🌟 Award Top Badge'}
                          </button>
                          <button
                            type="button"
                            style={{ background: '#fee2e2', color: '#b91c1c', border: 'none', padding: '6px 10px', borderRadius: '6px', cursor: 'pointer', fontWeight: '600' }}
                            onClick={() => handleDeleteUser(farmer._id, farmer.name)}
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 5. ADMINS */}
          {activeSection === 'admins' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Admin Name</th>
                      <th>Email</th>
                      <th>Phone</th>
                      <th>Role</th>
                    </tr>
                  </thead>
                  <tbody>
                    {adminUsers.map((adminItem) => (
                      <tr key={adminItem._id}>
                        <td><strong>{adminItem.name}</strong></td>
                        <td>{adminItem.email}</td>
                        <td>{adminItem.phone || 'N/A'}</td>
                        <td><span className="badge active" style={{ background: '#e0e7ff', color: '#4338ca' }}>Admin</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 6. FARMS */}
          {activeSection === 'farms' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Farm Name</th>
                      <th>Farmer</th>
                      <th>Land Size</th>
                      <th>Location</th>
                      <th>Soil & pH</th>
                    </tr>
                  </thead>
                  <tbody>
                    {farms.map((farm) => (
                      <tr key={farm._id}>
                        <td><strong>{farm.name}</strong></td>
                        <td>{farm.userId?.name || 'Unknown'}</td>
                        <td>{farm.landSize} {farm.unit || 'Acres'}</td>
                        <td>{farm.location || 'N/A'}</td>
                        <td>{farm.soilType} (pH: {farm.ph ?? 'N/A'})</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 7. CROPS */}
          {activeSection === 'crops' && (
            <section className="content-section">
              <div className="table-container">
                <table className="content-table">
                  <thead>
                    <tr>
                      <th>Crop & Category</th>
                      <th>Farmer & Farm</th>
                      <th>Area</th>
                      <th>Seed Info</th>
                      <th>Stage</th>
                      <th>Expense</th>
                    </tr>
                  </thead>
                  <tbody>
                    {crops.map((crop) => (
                      <tr key={crop._id}>
                        <td>
                          <strong>{crop.cropType}</strong> {crop.variety ? `(${crop.variety})` : ''}
                          <div style={{ fontSize: '11.5px', color: '#047857' }}>{crop.cropCategory || 'শাকসবজি'}</div>
                        </td>
                        <td>{crop.userId?.name || 'N/A'} ({crop.farmId?.name || ''})</td>
                        <td>{crop.allocatedArea > 0 ? `${crop.allocatedArea} ${crop.areaUnit}` : 'N/A'}</td>
                        <td>{crop.seedQuantity > 0 ? `${crop.seedQuantity} ${crop.seedUnit}` : (crop.seedSource || 'N/A')}</td>
                        <td><span className="badge pending">{crop.currentStage}</span></td>
                        <td><strong>৳{crop.totalExpense || 0}</strong></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* 8. ACTIVITIES */}
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
                    {activities.map((task) => (
                      <tr key={task._id}>
                        <td><strong>{task.title}</strong></td>
                        <td>{task.activityType}</td>
                        <td>{task.userId?.name || 'N/A'}</td>
                        <td>{task.cropId?.cropType || 'General'}</td>
                        <td>{task.scheduledDate ? new Date(task.scheduledDate).toLocaleDateString() : 'N/A'}</td>
                        <td><span className={`badge ${task.status === 'Completed' ? 'completed' : 'pending'}`}>{task.status}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* CLEAN & MINIMAL EXPERT MODAL */}
          {showCreateExpertModal && (
            <div style={modalOverlayStyle}>
              <form onSubmit={handleSaveExpertAccount} style={modalCardStyle} noValidate>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px', borderBottom: '1px solid #e2e8f0', paddingBottom: '12px' }}>
                  <h3 style={{ margin: 0, fontSize: '18px', color: '#0f172a' }}>
                    {editingExpert ? 'Edit Expert Profile' : 'New Expert Account'}
                  </h3>
                  <button
                    type="button"
                    onClick={() => {
                      setShowCreateExpertModal(false)
                      setModalError('')
                    }}
                    style={{ background: 'transparent', border: 'none', fontSize: '18px', color: '#64748b', cursor: 'pointer' }}
                  >
                    ✕
                  </button>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                  {!editingExpert && (
                    <>
                      <div>
                        <label style={modalLabelStyle}>Full Name *</label>
                        <input
                          type="text"
                          placeholder="Dr. Rafiqul Islam"
                          value={expertForm.name}
                          onChange={(e) => setExpertForm({ ...expertForm, name: e.target.value })}
                          style={modalInputStyle}
                          required
                        />
                      </div>
                      <div>
                        <label style={modalLabelStyle}>Phone / Hotline *</label>
                        <input
                          type="text"
                          placeholder="017XXXXXXXX"
                          value={expertForm.phone}
                          onChange={(e) => setExpertForm({ ...expertForm, phone: e.target.value })}
                          style={modalInputStyle}
                          required
                        />
                      </div>
                      <div>
                        <label style={modalLabelStyle}>Login Email *</label>
                        <input
                          type="email"
                          placeholder="expert@gmail.com"
                          value={expertForm.email}
                          onChange={(e) => setExpertForm({ ...expertForm, email: e.target.value })}
                          style={modalInputStyle}
                          required
                        />
                      </div>
                      <div>
                        <label style={modalLabelStyle}>Password *</label>
                        <div style={{ position: 'relative' }}>
                          <input
                            type={showExpertModalPassword ? 'text' : 'password'}
                            placeholder="Min 6 characters"
                            value={expertForm.password}
                            onChange={(e) => setExpertForm({ ...expertForm, password: e.target.value })}
                            style={{ ...modalInputStyle, paddingRight: '55px' }}
                            required
                          />
                          <button
                            type="button"
                            onClick={() => setShowExpertModalPassword(!showExpertModalPassword)}
                            style={inlineEyeBtnStyle}
                          >
                            {showExpertModalPassword ? 'Hide' : 'Show'}
                          </button>
                        </div>
                      </div>
                    </>
                  )}

                  {editingExpert && (
                    <div style={{ gridColumn: '1 / -1' }}>
                      <label style={modalLabelStyle}>Phone / Hotline & WhatsApp</label>
                      <input
                        type="text"
                        value={expertForm.phone}
                        onChange={(e) => setExpertForm({ ...expertForm, phone: e.target.value })}
                        style={modalInputStyle}
                      />
                    </div>
                  )}

                  <div>
                    <label style={modalLabelStyle}>Designation</label>
                    <input
                      type="text"
                      value={expertForm.designation}
                      onChange={(e) => setExpertForm({ ...expertForm, designation: e.target.value })}
                      style={modalInputStyle}
                    />
                  </div>
                  <div>
                    <label style={modalLabelStyle}>Specialization</label>
                    <input
                      type="text"
                      value={expertForm.specialization}
                      onChange={(e) => setExpertForm({ ...expertForm, specialization: e.target.value })}
                      style={modalInputStyle}
                    />
                  </div>
                  <div>
                    <label style={modalLabelStyle}>District / Area</label>
                    <input
                      type="text"
                      value={expertForm.district}
                      onChange={(e) => setExpertForm({ ...expertForm, district: e.target.value })}
                      style={modalInputStyle}
                    />
                  </div>
                  <div>
                    <label style={modalLabelStyle}>Duty Hours</label>
                    <input
                      type="text"
                      value={expertForm.dutyHours}
                      onChange={(e) => setExpertForm({ ...expertForm, dutyHours: e.target.value })}
                      style={modalInputStyle}
                    />
                  </div>
                </div>

                {modalError && (
                  <div className="status error" style={{ marginTop: '16px' }}>
                    {modalError}
                  </div>
                )}

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '22px', paddingTop: '14px', borderTop: '1px solid #e2e8f0' }}>
                  <button
                    type="button"
                    onClick={() => {
                      setShowCreateExpertModal(false)
                      setModalError('')
                    }}
                    style={{ padding: '9px 16px', borderRadius: '8px', border: '1px solid #cbd5e1', background: '#fff', color: '#334155', cursor: 'pointer', fontWeight: '600' }}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creatingExpert}
                    style={{ padding: '9px 20px', borderRadius: '8px', border: 'none', background: '#15803d', color: '#fff', cursor: 'pointer', fontWeight: '600' }}
                  >
                    {creatingExpert ? 'Saving...' : (editingExpert ? 'Save Changes' : 'Create Account')}
                  </button>
                </div>
              </form>
            </div>
          )}
        </main>
      </div>
    )
  }

  // 3. CLEAN LOGIN SCREEN
  return (
    <div className="auth-page">
      <div className="auth-panel">
        <div className="auth-header">
          <div className="brand-mark">SF</div>
          <div>
            <p className="eyebrow">Smart Farmer Web Portal</p>
            <h1>
              {authMode === 'expert_signin'
                ? 'Expert Sign In'
                : authMode === 'admin_signin'
                ? 'Admin Sign In'
                : 'Create Admin'}
            </h1>
          </div>
        </div>

        <div className="auth-toggle" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '4px' }}>
          <button
            type="button"
            className={authMode === 'expert_signin' ? 'active' : ''}
            onClick={() => { setAuthMode('expert_signin'); setErrorMessage(''); setSuccessMessage('') }}
          >
            Expert Login
          </button>
          <button
            type="button"
            className={authMode === 'admin_signin' ? 'active' : ''}
            onClick={() => { setAuthMode('admin_signin'); setErrorMessage(''); setSuccessMessage('') }}
          >
            Admin Login
          </button>
          <button
            type="button"
            className={authMode === 'admin_signup' ? 'active' : ''}
            onClick={() => { setAuthMode('admin_signup'); setErrorMessage(''); setSuccessMessage('') }}
          >
            Admin Sign up
          </button>
        </div>

        {authMode !== 'admin_signup' ? (
          <form onSubmit={handleSignIn} className="auth-form" noValidate>
            <label>
              Email
              <input
                type="email"
                value={loginValues.email}
                onChange={(e) => setLoginValues((c) => ({ ...c, email: e.target.value }))}
                placeholder="you@example.com"
                disabled={isLoading}
              />
            </label>

            <label>
              Password
              <div style={{ position: 'relative' }}>
                <input
                  type={showLoginPassword ? 'text' : 'password'}
                  value={loginValues.password}
                  onChange={(e) => setLoginValues((c) => ({ ...c, password: e.target.value }))}
                  placeholder="Enter password"
                  disabled={isLoading}
                  style={{ width: '100%', paddingRight: '68px', boxSizing: 'border-box' }}
                />
                <button
                  type="button"
                  onClick={() => setShowLoginPassword(!showLoginPassword)}
                  style={inlineEyeBtnStyle}
                >
                  {showLoginPassword ? 'Hide' : 'Show'}
                </button>
              </div>
            </label>

            {errorMessage && <div className="status error">{errorMessage}</div>}
            {successMessage && <div className="status success">{successMessage}</div>}

            <button type="submit" className="primary-button" disabled={isLoading}>
              {isLoading ? 'Signing in...' : 'Sign in'}
            </button>
          </form>
        ) : (
          <form onSubmit={handleAdminSignUp} className="auth-form" noValidate>
            <label>
              Full name
              <input
                type="text"
                value={formValues.name}
                onChange={(e) => setFormValues((c) => ({ ...c, name: e.target.value }))}
                placeholder="Your full name"
                disabled={isLoading}
              />
            </label>
            <label>
              Email
              <input
                type="email"
                value={formValues.email}
                onChange={(e) => setFormValues((c) => ({ ...c, email: e.target.value }))}
                placeholder="admin@example.com"
                disabled={isLoading}
              />
            </label>
            <label>
              Password
              <div style={{ position: 'relative' }}>
                <input
                  type={showSignupPassword ? 'text' : 'password'}
                  value={formValues.password}
                  onChange={(e) => setFormValues((c) => ({ ...c, password: e.target.value }))}
                  placeholder="Create a strong password"
                  disabled={isLoading}
                  style={{ width: '100%', paddingRight: '68px', boxSizing: 'border-box' }}
                />
                <button
                  type="button"
                  onClick={() => setShowSignupPassword(!showSignupPassword)}
                  style={inlineEyeBtnStyle}
                >
                  {showSignupPassword ? 'Hide' : 'Show'}
                </button>
              </div>
            </label>
            <label>
              Phone
              <input
                type="tel"
                value={formValues.phone}
                onChange={(e) => setFormValues((c) => ({ ...c, phone: e.target.value }))}
                placeholder="017XXXXXXXX"
                disabled={isLoading}
              />
            </label>

            {errorMessage && <div className="status error">{errorMessage}</div>}
            {successMessage && <div className="status success">{successMessage}</div>}

            <button type="submit" className="primary-button" disabled={isLoading}>
              {isLoading ? 'Creating account...' : 'Create account'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

const filterChipStyle = (isActive, activeColor = '#12362b') => ({
  background: isActive ? activeColor : '#f1f5f9',
  color: isActive ? '#ffffff' : '#334155',
  border: 'none',
  padding: '8px 14px',
  borderRadius: '8px',
  fontSize: '13px',
  fontWeight: '600',
  cursor: 'pointer',
})

const modalOverlayStyle = {
  position: 'fixed',
  inset: 0,
  background: 'rgba(15, 23, 42, 0.45)',
  backdropFilter: 'blur(3px)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  zIndex: 9999,
  padding: '16px',
}

const modalCardStyle = {
  background: '#ffffff',
  borderRadius: '14px',
  padding: '24px',
  width: '100%',
  maxWidth: '500px',
  boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.12)',
}

const modalLabelStyle = {
  fontSize: '12.5px',
  fontWeight: '600',
  color: '#334155',
  display: 'block',
  marginBottom: '5px',
}

const modalInputStyle = {
  width: '100%',
  padding: '9px 12px',
  borderRadius: '8px',
  border: '1px solid #cbd5e1',
  backgroundColor: '#f8fafc',
  color: '#0f172a',
  fontSize: '13.5px',
  boxSizing: 'border-box',
  outline: 'none',
}

const inlineEyeBtnStyle = {
  position: 'absolute',
  right: '8px',
  top: '50%',
  transform: 'translateY(-50%)',
  background: '#e2e8f0',
  color: '#1e293b',
  border: 'none',
  borderRadius: '5px',
  padding: '3px 8px',
  fontSize: '11px',
  fontWeight: '700',
  cursor: 'pointer',
}

export default App