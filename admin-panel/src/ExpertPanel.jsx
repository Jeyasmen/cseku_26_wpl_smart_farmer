import React, { useState, useEffect } from 'react';
import './App.css';

const ExpertPanel = ({ sessionUser, onSessionUpdate, onSignOut }) => {
  // 'pending' | 'resolved' | 'messages' | 'broadcast' | 'profile'
  const [activeTab, setActiveTab] = useState('pending');
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);

  // Selected Case Modal (Opens only when expert clicks a row from the list)
  const [selectedCase, setSelectedCase] = useState(null); // { issue, mode: 'view' | 'prescribe' | 'edit' }
  const [prescriptionForm, setPrescriptionForm] = useState({
    diseaseName: '',
    medicineAdvice: '',
    precaution: '',
  });
  const [submitting, setSubmitting] = useState(false);

  // Messaging states
  const [conversations, setConversations] = useState([]);
  const [selectedPartner, setSelectedPartner] = useState(null);
  const [chatMessages, setChatMessages] = useState([]);
  const [chatInput, setChatInput] = useState('');

  // Broadcast state
  const [alertForm, setAlertForm] = useState({ title: '', alertText: '', targetDistrict: '' });

  // Profile settings state
  const [profileForm, setProfileForm] = useState({
    name: sessionUser?.name || '',
    phone: sessionUser?.phone || '',
    newPassword: '',
    designation: 'উপজেলা কৃষি কর্মকর্তা',
    specialization: 'ফসল ও মাটি বিশেষজ্ঞ',
    district: 'Khulna',
    hotlineNumber: '',
    whatsappNumber: '',
    dutyHours: 'সকাল ৯:০০ - বিকাল ৫:০০',
    isAvailable: true,
  });

  const token = localStorage.getItem('adminToken');

  useEffect(() => {
    fetchDashboard();
    fetchConversations();
  }, []);

  const fetchDashboard = async () => {
    try {
      setLoading(true);
      const res = await fetch('http://localhost:5000/api/expert/dashboard', {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      if (res.ok) {
        setDashboard(data);
        if (data.expert) {
          setProfileForm({
            name: data.expert.name || '',
            phone: data.expert.phone || '',
            newPassword: '',
            designation: data.expert.designation || 'উপজেলা কৃষি কর্মকর্তা',
            specialization: data.expert.specialization || 'ফসল ও মাটি বিশেষজ্ঞ',
            district: data.expert.district || 'Khulna',
            hotlineNumber: data.expert.hotlineNumber || data.expert.phone || '',
            whatsappNumber: data.expert.whatsappNumber || data.expert.phone || '',
            dutyHours: data.expert.dutyHours || 'সকাল ৯:০০ - বিকাল ৫:০০',
            isAvailable: data.expert.isAvailable !== false,
          });
        }
      }
    } catch (error) {
      console.error('Failed to load dashboard:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchConversations = async () => {
    try {
      const res = await fetch('http://localhost:5000/api/messages/conversations', {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) setConversations(await res.json());
    } catch (err) {
      console.error(err);
    }
  };

  const openChatWithFarmer = async (farmer) => {
    setSelectedCase(null);
    setSelectedPartner(farmer);
    setActiveTab('messages');
    try {
      const res = await fetch(`http://localhost:5000/api/messages/${farmer._id}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        setChatMessages(await res.json());
        fetchConversations();
      }
    } catch (err) {
      console.error(err);
    }
  };

  const sendChatMessage = async (e) => {
    e.preventDefault();
    if (!chatInput.trim() || !selectedPartner) return;
    try {
      const res = await fetch(`http://localhost:5000/api/messages/${selectedPartner._id}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ text: chatInput.trim() }),
      });
      if (res.ok) {
        setChatInput('');
        openChatWithFarmer(selectedPartner);
      }
    } catch (err) {
      alert('Failed to send message.');
    }
  };

  // Parse existing prescription into structured fields when viewing/editing
  const parsePrescriptionFields = (replyText = '') => {
    const withoutSig = replyText.split('\n— ')[0].trim();
    const diseaseMatch = withoutSig.match(/🔍 রোগ\/সমস্যা:\s*(.*)/);
    const medMatch = withoutSig.match(/💊 করণীয় ও মাত্রা:\s*([\s\S]*?)(?=\n\n⚠️ সতর্কতা:|$)/);
    const precMatch = withoutSig.match(/⚠️ সতর্কতা:\s*(.*)/);

    if (diseaseMatch || medMatch || precMatch) {
      return {
        diseaseName: diseaseMatch ? diseaseMatch[1].trim() : '',
        medicineAdvice: medMatch ? medMatch[1].trim() : '',
        precaution: precMatch ? precMatch[1].trim() : '',
      };
    }
    return { diseaseName: '', medicineAdvice: withoutSig, precaution: '' };
  };

  const openCaseModal = (issue, mode = 'view') => {
    if (mode === 'edit' || mode === 'view') {
      setPrescriptionForm(parsePrescriptionFields(issue.expertReply || ''));
    } else {
      setPrescriptionForm({ diseaseName: '', medicineAdvice: '', precaution: '' });
    }
    setSelectedCase({ issue, mode });
  };

  const handlePrescriptionSubmit = async (e) => {
    e.preventDefault();
    if (!selectedCase) return;
    if (!prescriptionForm.medicineAdvice.trim()) {
      alert('অনুগ্রহ করে করণীয় ও ওষুধের মাত্রা লিখুন।');
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch(`http://localhost:5000/api/admin/issues/${selectedCase.issue._id}/reply`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          diseaseName: prescriptionForm.diseaseName.trim(),
          medicineAdvice: prescriptionForm.medicineAdvice.trim(),
          precaution: prescriptionForm.precaution.trim(),
        }),
      });

      if (res.ok) {
        setSelectedCase(null);
        setPrescriptionForm({ diseaseName: '', medicineAdvice: '', precaution: '' });
        await fetchDashboard();
      } else {
        alert('Failed to submit prescription.');
      }
    } catch (err) {
      console.error(err);
    } finally {
      setSubmitting(false);
    }
  };

  const handleBroadcastAlert = async (e) => {
    e.preventDefault();
    if (!alertForm.alertText.trim()) return;
    try {
      const res = await fetch('http://localhost:5000/api/expert/broadcast-alert', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(alertForm),
      });
      if (res.ok) {
        alert('Advisory published to community feed.');
        setAlertForm({ title: '', alertText: '', targetDistrict: '' });
      }
    } catch (err) {
      alert('Failed to publish advisory.');
    }
  };

  const handleSaveProfile = async (e) => {
    e.preventDefault();
    try {
      const res = await fetch('http://localhost:5000/api/expert/profile', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(profileForm),
      });
      const data = await res.json();
      if (res.ok) {
        alert('Profile updated successfully.');
        setProfileForm((prev) => ({ ...prev, newPassword: '' }));
        if (onSessionUpdate && data.user) onSessionUpdate(data.user);
        fetchDashboard();
      }
    } catch (err) {
      alert('Failed to update profile.');
    }
  };

  const getCropAge = (sowingDate) => {
    if (!sowingDate) return 'N/A';
    const days = Math.floor((new Date() - new Date(sowingDate)) / (1000 * 60 * 60 * 24));
    return days > 0 ? `${days} Days` : 'New';
  };

  const formatWhatsAppPhone = (phone) => {
    const clean = (phone || '').replace(/[^0-9]/g, '');
    return clean.startsWith('01') && clean.length === 11 ? `88${clean}` : clean;
  };

  const pendingIssues = dashboard?.pendingIssues || [];
  const resolvedIssues = dashboard?.resolvedIssues || [];
  const expertInfo = dashboard?.expert || sessionUser || {};

  return (
    <div className="app-shell">
      {/* SIDEBAR */}
      <aside className="sidebar">
        <div className="brand-block">
          <div className="brand-mark">SF</div>
          <div>
            <h1>Smart Farmer</h1>
            <p>Expert Portal</p>
          </div>
        </div>

        <nav className="nav-list">
          <button
            type="button"
            className={`nav-item ${activeTab === 'pending' ? 'active' : ''}`}
            onClick={() => setActiveTab('pending')}
          >
            Pending Consultations ({pendingIssues.length})
          </button>
          <button
            type="button"
            className={`nav-item ${activeTab === 'resolved' ? 'active' : ''}`}
            onClick={() => setActiveTab('resolved')}
          >
            Resolved Cases ({resolvedIssues.length})
          </button>
          <button
            type="button"
            className={`nav-item ${activeTab === 'messages' ? 'active' : ''}`}
            onClick={() => setActiveTab('messages')}
          >
            Farmer Messages ({dashboard?.unreadMessagesCount || 0})
          </button>
          <button
            type="button"
            className={`nav-item ${activeTab === 'broadcast' ? 'active' : ''}`}
            onClick={() => setActiveTab('broadcast')}
          >
            Advisory Broadcast
          </button>
          <button
            type="button"
            className={`nav-item ${activeTab === 'profile' ? 'active' : ''}`}
            onClick={() => setActiveTab('profile')}
          >
            Profile Settings
          </button>
        </nav>

        <div className="profile-card">
          <strong>{expertInfo.name}</strong>
          <span>{profileForm.designation}</span>
          <button type="button" onClick={onSignOut}>Sign out</button>
        </div>
      </aside>

      {/* MAIN WORKSPACE */}
      <main className="dashboard-main">
        <header className="topbar">
          <div>
            <p className="eyebrow">{profileForm.district} · {profileForm.specialization}</p>
            <h2>{expertInfo.name}</h2>
          </div>
          <button
            type="button"
            className="primary-button"
            onClick={() => { fetchDashboard(); fetchConversations(); }}
          >
            ↻ Refresh
          </button>
        </header>

        {/* SUMMARY CARDS */}
        <section className="stats-grid" style={{ marginBottom: '24px' }}>
          <article
            className="stat-card"
            onClick={() => setActiveTab('pending')}
            style={{ cursor: 'pointer', borderLeft: activeTab === 'pending' ? '4px solid #d97706' : 'none' }}
          >
            <label>Pending Consultations</label>
            <strong>{pendingIssues.length}</strong>
            <span>Awaiting prescription</span>
          </article>

          <article
            className="stat-card"
            onClick={() => setActiveTab('resolved')}
            style={{ cursor: 'pointer', borderLeft: activeTab === 'resolved' ? '4px solid #15803d' : 'none' }}
          >
            <label>Resolved Cases</label>
            <strong>{dashboard?.myResolvedCount ?? resolvedIssues.length}</strong>
            <span>Completed prescriptions</span>
          </article>

          <article
            className="stat-card"
            onClick={() => setActiveTab('messages')}
            style={{ cursor: 'pointer' }}
          >
            <label>Unread Messages</label>
            <strong>{dashboard?.unreadMessagesCount ?? 0}</strong>
            <span>Direct farmer inquiries</span>
          </article>

          <article
            className="stat-card"
            onClick={() => setActiveTab('profile')}
            style={{ cursor: 'pointer' }}
          >
            <label>Duty Status</label>
            <strong style={{ fontSize: '18px', color: profileForm.isAvailable ? '#15803d' : '#64748b' }}>
              {profileForm.isAvailable ? 'Online' : 'Offline'}
            </strong>
            <span>Hotline: {profileForm.hotlineNumber || 'N/A'}</span>
          </article>
        </section>

        {loading ? (
          <div style={{ textAlign: 'center', padding: '40px', color: '#64748b' }}>Loading records...</div>
        ) : (
          <>
            {/* 1. PENDING CONSULTATIONS LIST (Clean Table View) */}
            {activeTab === 'pending' && (
              <section className="content-section">
                <div className="table-container">
                  <table className="content-table">
                    <thead>
                      <tr>
                        <th>Farmer & Location</th>
                        <th>Crop & Area</th>
                        <th>Reported Issue</th>
                        <th>Date</th>
                        <th>Status</th>
                        <th>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {pendingIssues.length > 0 ? (
                        pendingIssues.map((issue) => {
                          const farmer = issue.userId || {};
                          const crop = issue.cropId || {};
                          const farm = crop.farmId || {};
                          return (
                            <tr key={issue._id}>
                              <td>
                                <strong>{farmer.name || 'Farmer'}</strong>
                                <div style={{ fontSize: '12px', color: '#64748b' }}>
                                  {farmer.district || farm.location || 'N/A'} · {farmer.phone || ''}
                                </div>
                              </td>
                              <td>
                                <strong>{crop.cropType || 'Crop'}</strong>
                                <div style={{ fontSize: '12px', color: '#64748b' }}>
                                  {crop.allocatedArea > 0 ? `${crop.allocatedArea} ${crop.areaUnit}` : crop.currentStage}
                                </div>
                              </td>
                              <td style={{ maxWidth: '300px' }}>
                                <div style={{ fontWeight: '500', color: '#0f172a', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                  {issue.issueText}
                                </div>
                                {issue.imageBase64 && (
                                  <span style={{ fontSize: '11px', color: '#0369a1', fontWeight: '600' }}>Photo Attached</span>
                                )}
                              </td>
                              <td>{issue.createdAt ? new Date(issue.createdAt).toLocaleDateString() : 'N/A'}</td>
                              <td>
                                <span className="badge" style={{ background: '#fef3c7', color: '#b45309' }}>Pending</span>
                              </td>
                              <td>
                                <button
                                  type="button"
                                  onClick={() => openCaseModal(issue, 'prescribe')}
                                  style={primaryActionBtnStyle}
                                >
                                  View & Prescribe
                                </button>
                              </td>
                            </tr>
                          );
                        })
                      ) : (
                        <tr>
                          <td colSpan="6" style={{ textAlign: 'center', padding: '32px', color: '#94a3b8' }}>
                            No pending consultations at the moment.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </section>
            )}

            {/* 2. RESOLVED CASES LIST (Clean Table View - Click to View or Edit) */}
            {activeTab === 'resolved' && (
              <section className="content-section">
                <div className="table-container">
                  <table className="content-table">
                    <thead>
                      <tr>
                        <th>Farmer & Location</th>
                        <th>Crop & Stage</th>
                        <th>Reported Issue</th>
                        <th>Resolved Date</th>
                        <th>Status</th>
                        <th>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {resolvedIssues.length > 0 ? (
                        resolvedIssues.map((issue) => {
                          const farmer = issue.userId || {};
                          const crop = issue.cropId || {};
                          const farm = crop.farmId || {};
                          return (
                            <tr key={issue._id}>
                              <td>
                                <strong>{farmer.name || 'Farmer'}</strong>
                                <div style={{ fontSize: '12px', color: '#64748b' }}>
                                  {farmer.district || farm.location || 'N/A'} · {farmer.phone || ''}
                                </div>
                              </td>
                              <td>
                                <strong>{crop.cropType || 'Crop'}</strong>
                                <div style={{ fontSize: '12px', color: '#64748b' }}>{crop.currentStage || 'N/A'}</div>
                              </td>
                              <td style={{ maxWidth: '300px' }}>
                                <div style={{ fontWeight: '500', color: '#0f172a', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                  {issue.issueText}
                                </div>
                              </td>
                              <td>
                                {issue.resolvedAt
                                  ? new Date(issue.resolvedAt).toLocaleDateString()
                                  : (issue.updatedAt ? new Date(issue.updatedAt).toLocaleDateString() : 'N/A')}
                              </td>
                              <td>
                                <span className="badge" style={{ background: '#dcfce7', color: '#15803d' }}>Resolved</span>
                              </td>
                              <td>
                                <button
                                  type="button"
                                  onClick={() => openCaseModal(issue, 'view')}
                                  style={secondaryActionBtnStyle}
                                >
                                  View Details
                                </button>
                                <button
                                  type="button"
                                  onClick={() => openCaseModal(issue, 'edit')}
                                  style={{ ...secondaryActionBtnStyle, background: '#f1f5f9', color: '#334155', marginLeft: '6px' }}
                                >
                                  Edit
                                </button>
                              </td>
                            </tr>
                          );
                        })
                      ) : (
                        <tr>
                          <td colSpan="6" style={{ textAlign: 'center', padding: '32px', color: '#94a3b8' }}>
                            No resolved cases found.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </section>
            )}

            {/* 3. FARMER MESSAGES */}
            {activeTab === 'messages' && (
              <div style={{ display: 'grid', gridTemplateColumns: '280px 1fr', background: '#fff', borderRadius: '14px', border: '1px solid #e2e8f0', minHeight: '500px', overflow: 'hidden' }}>
                <div style={{ borderRight: '1px solid #e2e8f0', background: '#f8fafc' }}>
                  <div style={{ padding: '14px 16px', fontWeight: '700', color: '#0f172a', borderBottom: '1px solid #e2e8f0', fontSize: '14px' }}>
                    Conversations ({conversations.length})
                  </div>
                  {conversations.length === 0 ? (
                    <div style={{ padding: '24px', color: '#94a3b8', fontSize: '13px', textAlign: 'center' }}>No messages yet.</div>
                  ) : (
                    conversations.map((conv) => {
                      const p = conv.partner || {};
                      return (
                        <div
                          key={p._id}
                          onClick={() => openChatWithFarmer(p)}
                          style={{ padding: '12px 16px', cursor: 'pointer', borderBottom: '1px solid #f1f5f9', background: selectedPartner?._id === p._id ? '#e2e8f0' : 'transparent' }}
                        >
                          <strong style={{ color: '#0f172a', fontSize: '13.5px' }}>{p.name}</strong>
                          <div style={{ fontSize: '12px', color: '#64748b', marginTop: '3px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {conv.lastMessage}
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', height: '500px' }}>
                  {selectedPartner ? (
                    <>
                      <div style={{ padding: '14px 20px', borderBottom: '1px solid #e2e8f0', fontSize: '14px' }}>
                        <strong>{selectedPartner.name}</strong> <span style={{ color: '#64748b', marginLeft: '8px' }}>{selectedPartner.phone || ''}</span>
                      </div>
                      <div style={{ flex: 1, padding: '18px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '10px', background: '#f8fafc' }}>
                        {chatMessages.map((m) => {
                          const isMe = m.senderId !== selectedPartner._id;
                          return (
                            <div
                              key={m._id}
                              style={{
                                alignSelf: isMe ? 'flex-end' : 'flex-start',
                                background: isMe ? '#15803d' : '#fff',
                                color: isMe ? '#fff' : '#0f172a',
                                padding: '10px 14px',
                                borderRadius: '12px',
                                maxWidth: '70%',
                                border: isMe ? 'none' : '1px solid #e2e8f0',
                                fontSize: '13.5px',
                              }}
                            >
                              {m.imageBase64 && (
                                <img src={`data:image/jpeg;base64,${m.imageBase64}`} alt="attachment" style={{ maxWidth: '200px', borderRadius: '8px', display: 'block', marginBottom: '6px' }} />
                              )}
                              <div>{m.text}</div>
                            </div>
                          );
                        })}
                      </div>
                      <form onSubmit={sendChatMessage} style={{ padding: '12px 16px', borderTop: '1px solid #e2e8f0', display: 'flex', gap: '10px' }}>
                        <input
                          type="text"
                          placeholder="Write a message..."
                          value={chatInput}
                          onChange={(e) => setChatInput(e.target.value)}
                          style={{ ...lightInputStyle, flex: 1 }}
                        />
                        <button type="submit" style={{ background: '#15803d', color: '#fff', border: 'none', padding: '0 20px', borderRadius: '8px', fontWeight: '600', cursor: 'pointer' }}>
                          Send
                        </button>
                      </form>
                    </>
                  ) : (
                    <div style={{ margin: 'auto', color: '#94a3b8', fontSize: '14px' }}>Select a farmer from the list to view messages.</div>
                  )}
                </div>
              </div>
            )}

            {/* 4. ADVISORY BROADCAST */}
            {activeTab === 'broadcast' && (
              <form onSubmit={handleBroadcastAlert} style={{ background: '#fff', padding: '24px', borderRadius: '14px', border: '1px solid #e2e8f0', maxWidth: '640px' }}>
                <h3 style={{ margin: '0 0 6px 0', color: '#0f172a', fontSize: '17px' }}>Publish Agricultural Advisory</h3>
                <p style={{ margin: '0 0 18px 0', fontSize: '13px', color: '#64748b' }}>
                  Broadcast important weather or disease alerts directly to farmers in the community feed.
                </p>
                <div style={{ marginBottom: '14px' }}>
                  <label style={labelStyle}>Advisory Title *</label>
                  <input
                    type="text"
                    placeholder="e.g. Late Blight Prevention Notice"
                    value={alertForm.title}
                    onChange={(e) => setAlertForm({ ...alertForm, title: e.target.value })}
                    style={lightInputStyle}
                    required
                  />
                </div>
                <div style={{ marginBottom: '16px' }}>
                  <label style={labelStyle}>Instructions / Details *</label>
                  <textarea
                    rows="4"
                    placeholder="Write clear instructions for farmers..."
                    value={alertForm.alertText}
                    onChange={(e) => setAlertForm({ ...alertForm, alertText: e.target.value })}
                    style={lightInputStyle}
                    required
                  />
                </div>
                <button type="submit" style={{ background: '#15803d', color: '#fff', border: 'none', padding: '10px 20px', borderRadius: '8px', fontWeight: '600', cursor: 'pointer' }}>
                  Publish Advisory
                </button>
              </form>
            )}

            {/* 5. PROFILE SETTINGS */}
            {activeTab === 'profile' && (
              <form onSubmit={handleSaveProfile} style={{ background: '#fff', padding: '24px', borderRadius: '14px', border: '1px solid #e2e8f0', maxWidth: '680px' }}>
                <h3 style={{ margin: '0 0 16px 0', color: '#0f172a', fontSize: '17px' }}>Profile & Duty Settings</h3>

                <label style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '18px', cursor: 'pointer', background: '#f8fafc', padding: '12px 14px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                  <input
                    type="checkbox"
                    checked={profileForm.isAvailable}
                    onChange={(e) => setProfileForm({ ...profileForm, isAvailable: e.target.checked })}
                    style={{ width: '16px', height: '16px' }}
                  />
                  <span style={{ fontWeight: '600', color: '#0f172a', fontSize: '13.5px' }}>Available for Farmer Consultations (Online)</span>
                </label>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '18px' }}>
                  <div>
                    <label style={labelStyle}>Full Name</label>
                    <input
                      type="text"
                      value={profileForm.name}
                      onChange={(e) => setProfileForm({ ...profileForm, name: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>New Password (Optional)</label>
                    <input
                      type="password"
                      placeholder="Leave blank to keep current"
                      value={profileForm.newPassword}
                      onChange={(e) => setProfileForm({ ...profileForm, newPassword: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>Designation</label>
                    <input
                      type="text"
                      value={profileForm.designation}
                      onChange={(e) => setProfileForm({ ...profileForm, designation: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>Specialization</label>
                    <input
                      type="text"
                      value={profileForm.specialization}
                      onChange={(e) => setProfileForm({ ...profileForm, specialization: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>Hotline Number</label>
                    <input
                      type="text"
                      value={profileForm.hotlineNumber}
                      onChange={(e) => setProfileForm({ ...profileForm, hotlineNumber: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>WhatsApp Number</label>
                    <input
                      type="text"
                      value={profileForm.whatsappNumber}
                      onChange={(e) => setProfileForm({ ...profileForm, whatsappNumber: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>District / Station</label>
                    <input
                      type="text"
                      value={profileForm.district}
                      onChange={(e) => setProfileForm({ ...profileForm, district: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>Duty Hours</label>
                    <input
                      type="text"
                      value={profileForm.dutyHours}
                      onChange={(e) => setProfileForm({ ...profileForm, dutyHours: e.target.value })}
                      style={lightInputStyle}
                    />
                  </div>
                </div>

                <button type="submit" style={{ background: '#15803d', color: '#fff', border: 'none', padding: '10px 20px', borderRadius: '8px', fontWeight: '600', cursor: 'pointer' }}>
                  Save Changes
                </button>
              </form>
            )}
          </>
        )}

        {/* =========================================================================
            CASE DETAILS & PRESCRIPTION MODAL (Opens when a row is selected)
        ========================================================================= */}
        {selectedCase && (() => {
          const { issue, mode } = selectedCase;
          const farmer = issue.userId || {};
          const crop = issue.cropId || {};
          const farm = crop.farmId || {};
          const wpPhone = formatWhatsAppPhone(farmer.phone);

          return (
            <div style={modalOverlayStyle}>
              <div style={modalCardStyle}>
                {/* Modal Header */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid #e2e8f0', paddingBottom: '14px', marginBottom: '16px' }}>
                  <div>
                    <h3 style={{ margin: 0, fontSize: '18px', color: '#0f172a' }}>
                      {mode === 'view' ? 'Consultation Details' : mode === 'edit' ? 'Edit Prescription' : 'Write Prescription'}
                    </h3>
                    <p style={{ margin: '4px 0 0 0', fontSize: '13px', color: '#64748b' }}>
                      Farmer: <strong>{farmer.name || 'N/A'}</strong> ({farmer.district || farm.location || 'N/A'}) · Phone: {farmer.phone || 'N/A'}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => setSelectedCase(null)}
                    style={{ background: 'transparent', border: 'none', fontSize: '18px', color: '#64748b', cursor: 'pointer' }}
                  >
                    ✕
                  </button>
                </div>

                {/* Quick Contact Bar */}
                <div style={{ display: 'flex', gap: '8px', marginBottom: '14px', flexWrap: 'wrap' }}>
                  {farmer.phone && (
                    <>
                      <a href={`tel:${farmer.phone}`} style={contactLinkStyle}>Call: {farmer.phone}</a>
                      <a
                        href={`https://wa.me/${wpPhone}`}
                        target="_blank"
                        rel="noreferrer"
                        style={{ ...contactLinkStyle, background: '#dcfce7', color: '#166534', borderColor: '#bbf7d0' }}
                      >
                        WhatsApp
                      </a>
                    </>
                  )}
                  <button
                    type="button"
                    onClick={() => openChatWithFarmer(farmer)}
                    style={{ ...contactLinkStyle, cursor: 'pointer' }}
                  >
                    Direct Message
                  </button>
                </div>

                {/* Crop & Soil Context */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', background: '#f8fafc', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', fontSize: '12.5px', color: '#334155', marginBottom: '14px' }}>
                  <div><strong>Crop:</strong> {crop.cropType} ({crop.variety || 'Local'})</div>
                  <div><strong>Stage & Age:</strong> {crop.currentStage} ({getCropAge(crop.sowingDate)})</div>
                  <div><strong>Land Area:</strong> {crop.allocatedArea > 0 ? `${crop.allocatedArea} ${crop.areaUnit}` : `${farm.landSize || 'N/A'} ${farm.unit || ''}`}</div>
                  <div><strong>Soil & pH:</strong> {farm.soilType || 'Loamy'} (pH: {farm.ph || 'Normal'})</div>
                </div>

                {/* Farmer's Reported Problem & Photo */}
                <div style={{ padding: '12px', background: '#fffbeb', borderRadius: '8px', border: '1px solid #fde68a', marginBottom: '14px' }}>
                  <div style={{ fontSize: '11.5px', fontWeight: '700', color: '#b45309', marginBottom: '4px' }}>Reported Issue:</div>
                  <div style={{ fontSize: '14px', color: '#0f172a', fontWeight: '500', lineHeight: '1.4' }}>{issue.issueText}</div>
                </div>

                {issue.imageBase64 && (
                  <div style={{ marginBottom: '16px' }}>
                    <img
                      src={`data:image/jpeg;base64,${issue.imageBase64}`}
                      alt="Crop Issue"
                      style={{ width: '100%', maxHeight: '220px', objectFit: 'cover', borderRadius: '8px', border: '1px solid #cbd5e1' }}
                    />
                  </div>
                )}

                {/* VIEW MODE vs FORM MODE */}
                {mode === 'view' ? (
                  <div>
                    <div style={{ padding: '14px', background: '#f0fdf4', borderRadius: '8px', border: '1px solid #bbf7d0', marginBottom: '18px' }}>
                      <div style={{ fontSize: '12px', fontWeight: '700', color: '#15803d', marginBottom: '6px' }}>Provided Prescription:</div>
                      <div style={{ fontSize: '13.5px', color: '#14532d', whiteSpace: 'pre-line', lineHeight: '1.5' }}>
                        {issue.expertReply || 'No prescription recorded.'}
                      </div>
                    </div>

                    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', borderTop: '1px solid #e2e8f0', paddingTop: '14px' }}>
                      <button
                        type="button"
                        onClick={() => setSelectedCase(null)}
                        style={cancelBtnStyle}
                      >
                        Close
                      </button>
                      <button
                        type="button"
                        onClick={() => setSelectedCase({ issue, mode: 'edit' })}
                        style={primarySubmitBtnStyle}
                      >
                        Edit Prescription
                      </button>
                    </div>
                  </div>
                ) : (
                  <form onSubmit={handlePrescriptionSubmit}>
                    <div style={{ marginBottom: '12px' }}>
                      <label style={labelStyle}>1. Identified Disease / Issue</label>
                      <input
                        type="text"
                        placeholder="e.g. Late Blight / Nitrogen Deficiency"
                        value={prescriptionForm.diseaseName}
                        onChange={(e) => setPrescriptionForm({ ...prescriptionForm, diseaseName: e.target.value })}
                        style={lightInputStyle}
                      />
                    </div>

                    <div style={{ marginBottom: '12px' }}>
                      <label style={labelStyle}>2. Recommended Treatment & Dosage *</label>
                      <textarea
                        rows="4"
                        placeholder="Write clear treatment instructions and dosage..."
                        value={prescriptionForm.medicineAdvice}
                        onChange={(e) => setPrescriptionForm({ ...prescriptionForm, medicineAdvice: e.target.value })}
                        style={{ ...lightInputStyle, resize: 'vertical' }}
                        required
                      />
                    </div>

                    <div style={{ marginBottom: '18px' }}>
                      <label style={labelStyle}>3. Precautions (Optional)</label>
                      <input
                        type="text"
                        placeholder="e.g. Apply in late afternoon during dry weather"
                        value={prescriptionForm.precaution}
                        onChange={(e) => setPrescriptionForm({ ...prescriptionForm, precaution: e.target.value })}
                        style={lightInputStyle}
                      />
                    </div>

                    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', borderTop: '1px solid #e2e8f0', paddingTop: '14px' }}>
                      <button
                        type="button"
                        onClick={() => setSelectedCase(null)}
                        style={cancelBtnStyle}
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        disabled={submitting}
                        style={primarySubmitBtnStyle}
                      >
                        {submitting ? 'Saving...' : mode === 'edit' ? 'Update Prescription' : 'Send Prescription'}
                      </button>
                    </div>
                  </form>
                )}
              </div>
            </div>
          );
        })()}
      </main>
    </div>
  );
};

const labelStyle = {
  display: 'block',
  fontSize: '12.5px',
  fontWeight: '600',
  color: '#334155',
  marginBottom: '5px',
};

const lightInputStyle = {
  width: '100%',
  padding: '9px 12px',
  borderRadius: '8px',
  border: '1px solid #cbd5e1',
  backgroundColor: '#f8fafc',
  color: '#0f172a',
  fontSize: '13.5px',
  boxSizing: 'border-box',
  fontFamily: 'inherit',
  outline: 'none',
};

const primaryActionBtnStyle = {
  background: '#15803d',
  color: '#ffffff',
  border: 'none',
  padding: '6px 12px',
  borderRadius: '6px',
  fontSize: '12.5px',
  fontWeight: '600',
  cursor: 'pointer',
};

const secondaryActionBtnStyle = {
  background: '#e0f2fe',
  color: '#0369a1',
  border: 'none',
  padding: '6px 12px',
  borderRadius: '6px',
  fontSize: '12.5px',
  fontWeight: '600',
  cursor: 'pointer',
};

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
};

const modalCardStyle = {
  background: '#ffffff',
  borderRadius: '14px',
  padding: '24px',
  width: '100%',
  maxWidth: '580px',
  maxHeight: '90vh',
  overflowY: 'auto',
  boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.15)',
};

const contactLinkStyle = {
  textDecoration: 'none',
  background: '#f8fafc',
  color: '#334155',
  border: '1px solid #cbd5e1',
  padding: '5px 10px',
  borderRadius: '6px',
  fontSize: '12px',
  fontWeight: '600',
};

const cancelBtnStyle = {
  padding: '9px 16px',
  borderRadius: '8px',
  border: '1px solid #cbd5e1',
  background: '#ffffff',
  color: '#334155',
  fontWeight: '600',
  cursor: 'pointer',
};

const primarySubmitBtnStyle = {
  padding: '9px 18px',
  borderRadius: '8px',
  border: 'none',
  background: '#15803d',
  color: '#ffffff',
  fontWeight: '600',
  cursor: 'pointer',
};

export default ExpertPanel;