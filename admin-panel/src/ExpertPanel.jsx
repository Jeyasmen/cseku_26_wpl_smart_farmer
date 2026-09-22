import React, { useState, useEffect } from 'react';

const ExpertPanel = () => {
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(true);
  const [replyText, setReplyText] = useState({});

  useEffect(() => {
    fetchPendingIssues();
  }, []);

  const fetchPendingIssues = async () => {
    try {
      const token = localStorage.getItem('adminToken'); // adminToken ব্যবহার করা হয়েছে
      const response = await fetch('http://localhost:5000/api/admin/issues/pending', {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
      });
      const data = await response.json();
      if (response.ok) {
        setIssues(data.issues || []);
      }
    } catch (error) {
      console.error('Failed to fetch issues:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleReplyChange = (issueId, text) => {
    setReplyText((prev) => ({ ...prev, [issueId]: text }));
  };

  const submitReply = async (issueId) => {
    const text = replyText[issueId];
    if (!text || text.trim() === '') {
      alert('দয়া করে উত্তর লিখুন!');
      return;
    }

    try {
      const token = localStorage.getItem('adminToken');
      const response = await fetch(`http://localhost:5000/api/admin/issues/${issueId}/reply`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ expertReply: text }),
      });

      if (response.ok) {
        alert('✅ কৃষকের কাছে সফলভাবে উত্তর পাঠানো হয়েছে!');
        setReplyText((prev) => ({ ...prev, [issueId]: '' }));
        fetchPendingIssues(); 
      } else {
        alert('উত্তর পাঠাতে সমস্যা হয়েছে।');
      }
    } catch (error) {
      console.error('Reply failed:', error);
    }
  };

  // ফসলের বয়স বের করার ফাংশন
  const getCropAge = (sowingDate) => {
    if (!sowingDate) return 'N/A';
    const diff = new Date() - new Date(sowingDate);
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    return days > 0 ? `${days} Days` : 'Just Planted';
  };

  if (loading) return <div style={{ textAlign: 'center', marginTop: '50px' }}>Loading issues...</div>;

  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif', maxWidth: '1200px', margin: '0 auto' }}>
      <h2 style={{ color: '#12362b', borderBottom: '2px solid #2f8d5c', paddingBottom: '10px' }}>
        👨‍🌾 Expert Support Panel
      </h2>
      
      {issues.length === 0 ? (
        <p style={{ textAlign: 'center', color: 'gray', marginTop: '40px', fontSize: '18px' }}>
          এই মুহূর্তে নতুন কোনো সমস্যা নেই! 🎉
        </p>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: '20px', marginTop: '20px' }}>
          {issues.map((issue) => {
            const crop = issue.cropId || {};
            const farm = crop.farmId || {};

            return (
              <div key={issue._id} style={{ border: '1px solid #e0e0e0', borderRadius: '12px', padding: '16px', backgroundColor: '#fff', boxShadow: '0 4px 6px rgba(0,0,0,0.05)' }}>
                
                {/* 1. Farmer Info */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                  <div>
                    <h4 style={{ margin: 0, color: '#18392d' }}>{issue.userId?.name || 'অজ্ঞাত কৃষক'}</h4>
                    <small style={{ color: '#666' }}>📞 {issue.userId?.phone || 'No phone'}</small>
                  </div>
                  <span style={{ backgroundColor: '#ffebee', color: '#c62828', padding: '4px 8px', borderRadius: '12px', fontSize: '12px', fontWeight: 'bold' }}>
                    Pending
                  </span>
                </div>
                
                {/* 2. CRITICAL CONTEXT FOR EXPERT (আপনার চাওয়া অনুযায়ী) */}
                <div style={{ backgroundColor: '#edf9f1', padding: '12px', borderRadius: '8px', marginBottom: '12px', fontSize: '13px', color: '#12362b', border: '1px solid #cce8d9' }}>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <div><strong>🌱 Crop:</strong> {crop.cropType} ({crop.variety || 'Local'})</div>
                    <div><strong>⏳ Age:</strong> {getCropAge(crop.sowingDate)} ({crop.currentStage})</div>
                    <div><strong>🌍 Area:</strong> {farm.location || 'Unknown'}</div>
                    <div><strong>🟤 Soil:</strong> {farm.soilType || 'N/A'} (pH: {farm.ph || 'N/A'})</div>
                  </div>
                </div>

                {/* 3. Issue Details */}
                <p style={{ fontSize: '14px', color: '#333', marginTop: '10px', fontWeight: '500' }}>
                  <strong>কৃষকের সমস্যা:</strong> {issue.issueText}
                </p>

                {/* 4. Image if available */}
                {issue.imageBase64 && (
                  <img 
                    src={`data:image/jpeg;base64,${issue.imageBase64}`} 
                    alt="Crop Issue" 
                    style={{ width: '100%', height: '180px', objectFit: 'cover', borderRadius: '8px', marginTop: '10px' }} 
                  />
                )}

                {/* 5. AI Advice Box */}
                <div style={{ backgroundColor: '#f4f6f8', padding: '10px', borderRadius: '8px', marginTop: '12px', fontSize: '13px', color: '#455a64' }}>
                  <strong>🤖 এআই-এর পূর্বের পরামর্শ:</strong><br/>
                  <span style={{ fontStyle: 'italic' }}>{issue.aiAdvice || 'এআই কোনো উত্তর দেয়নি।'}</span>
                </div>

                {/* 6. Expert Reply Input */}
                <div style={{ marginTop: '16px' }}>
                  <textarea 
                    placeholder="বিশেষজ্ঞ হিসেবে আপনার নির্ভুল সমাধান এখানে লিখুন..."
                    value={replyText[issue._id] || ''}
                    onChange={(e) => handleReplyChange(issue._id, e.target.value)}
                    style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #ccc', minHeight: '80px', boxSizing: 'border-box', fontFamily: 'inherit' }}
                  />
                  <button 
                    onClick={() => submitReply(issue._id)}
                    style={{ width: '100%', padding: '10px', marginTop: '10px', backgroundColor: '#2f8d5c', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold' }}
                  >
                    উত্তর পাঠিয়ে দিন 🚀
                  </button>
                </div>

              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default ExpertPanel;