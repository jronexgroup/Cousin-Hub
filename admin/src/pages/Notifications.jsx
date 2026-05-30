import { useEffect, useState } from 'react'
import { ref, onValue, push, update } from 'firebase/database'
import { db } from '../firebase'
import { Send, Bell, Clock, Users, CheckCircle, XCircle, Loader } from 'lucide-react'

const RENDER = import.meta.env.VITE_RENDER_SERVER || 'https://cousin-hub-server.onrender.com'

const TEMPLATES = [
  { emoji:'🚀', title:'New Feature!',    body:'Check out the latest features in Cousin Hub! Open the app to explore.' },
  { emoji:'🎉', title:'Happy Eid!',      body:'Eid Mubarak from all of us! 🌙 Enjoy the celebrations with family.' },
  { emoji:'🎮', title:'Game Time!',      body:'Challenge your cousins to a Ludo or Race! 🎲🏃' },
  { emoji:'📲', title:'App Update',     body:'A new version of Cousin Hub is available. Please update now!' },
]

function timeAgo(ts) {
  if (!ts) return ''
  const m = Math.floor((Date.now() - ts) / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m/60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h/24)}d ago`
}

export default function Notifications() {
  const [members, setMembers] = useState([])
  const [history, setHistory] = useState([])
  const [target, setTarget] = useState('all')
  const [selUsers, setSelUsers] = useState([])
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [sending, setSending] = useState(false)
  const [result, setResult] = useState(null)
  const [serverOk, setServerOk] = useState(null)
  const [queueDepth, setQueueDepth] = useState(0)

  useEffect(() => {
    onValue(ref(db, 'users'), snap => {
      if (!snap.exists()) return
      setMembers(Object.entries(snap.val()).map(([uid, u]) => ({ uid, ...u })))
    })
    onValue(ref(db, 'notifications'), snap => {
      if (!snap.exists()) { setHistory([]); setQueueDepth(0); return }
      const list = Object.entries(snap.val()).map(([k,v]) => ({id:k,...v})).sort((a,b) => b.timestamp - a.timestamp)
      setHistory(list)
      setQueueDepth(list.filter(n => !n.sent).length)
    })

    // Ping server
    fetch(`${RENDER}/health`).then(r => setServerOk(r.ok)).catch(() => setServerOk(false))
  }, [])

  const applyTemplate = (t) => { setTitle(t.title); setBody(t.body) }

  const sendNotification = async () => {
    if (!title.trim() || !body.trim()) return
    setSending(true); setResult(null)

    try {
      const targets = target === 'all'
        ? members.filter(m => m.fcmToken)
        : selUsers.map(uid => members.find(m => m.uid === uid)).filter(m => m?.fcmToken)

      let sent = 0, failed = 0, lastError = ''
      for (const m of targets) {
        try {
          const res = await fetch(`${RENDER}/send-notification`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ toToken: m.fcmToken, title, body }),
          })
          if (res.ok) {
            sent++
            await push(ref(db, 'notifications'), { toToken: m.fcmToken, title, body, sent: true, timestamp: Date.now() })
          } else { 
            failed++
            lastError = `Server returned ${res.status}: ${res.statusText}`
          }
        } catch (e) { 
          failed++
          lastError = e.message
        }
      }

      // Log
      await push(ref(db, 'adminLogs'), {
        action: 'NOTIFICATION_SENT', emoji: '🔔',
        message: `Sent "${title}" to ${sent} members (${failed} failed). ${failed > 0 ? 'Last error: ' + lastError : ''}`,
        timestamp: Date.now()
      })

      setResult({ sent, failed, total: targets.length, error: failed === targets.length ? `All failed: ${lastError}` : null })
      if (sent > 0) {
        setTitle(''); setBody(''); setSelUsers([])
      }
    } catch (e) {
      setResult({ error: `Critical Error: ${e.message}` })
    }
    setSending(false)
  }

  return (
    <div className="grid grid-cols-12 gap-4">
      {/* Compose */}
      <div className="col-span-7 space-y-4">
        <div className="glass-card p-5 space-y-4">
          <h2 className="text-white font-bold text-base flex items-center gap-2">
            <Bell size={16} className="text-purple-400"/> Compose Notification
          </h2>

          {/* Server status */}
          <div className="flex items-center gap-3">
            <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border ${
              serverOk === null ? 'bg-white/5 border-white/10 text-white/40' :
              serverOk ? 'bg-green-500/10 border-green-500/20 text-green-400' : 'bg-red-500/10 border-red-500/20 text-red-400'}`}>
              <div className={`w-2 h-2 rounded-full ${serverOk===null?'bg-white/20':serverOk?'bg-green-400':'bg-red-400'} animate-pulse`} />
              {serverOk===null ? 'Checking server…' : serverOk ? 'Render server online' : 'Render server offline'}
            </div>
            <span className="badge bg-yellow-500/10 border border-yellow-500/20 text-yellow-400">
              <Clock size={10}/> {queueDepth} unsent in queue
            </span>
          </div>

          {/* Target */}
          <div>
            <label className="block text-white/40 text-xs font-semibold uppercase tracking-wider mb-2">Target</label>
            <div className="flex gap-2">
              {[{v:'all',l:`Everyone (${members.length})`},{v:'select',l:'Select members'}].map(opt => (
                <button key={opt.v} onClick={() => setTarget(opt.v)}
                  className={`px-4 py-2 rounded-xl text-sm font-semibold flex items-center gap-2 transition-all ${
                    target===opt.v ? 'bg-primary text-white' : 'bg-white/5 text-white/50 hover:bg-white/10'}`}>
                  {opt.v==='all' ? <Users size={13}/> : <Bell size={13}/>} {opt.l}
                </button>
              ))}
            </div>
            {target === 'select' && (
              <div className="mt-3 max-h-40 overflow-y-auto space-y-1">
                {members.map(m => (
                  <label key={m.uid} className="flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-white/5 cursor-pointer">
                    <input type="checkbox" checked={selUsers.includes(m.uid)}
                      onChange={e => setSelUsers(s => e.target.checked ? [...s,m.uid] : s.filter(u=>u!==m.uid))}
                      className="w-3.5 h-3.5 accent-purple-500"/>
                    <span className="text-white/80 text-sm">{m.nickname || m.name}</span>
                    {!m.fcmToken && <span className="text-red-400/60 text-xs">(no token)</span>}
                  </label>
                ))}
              </div>
            )}
          </div>

          {/* Title */}
          <div>
            <label className="block text-white/40 text-xs font-semibold uppercase tracking-wider mb-2">
              Title <span className="text-white/20 font-normal normal-case">{title.length}/60</span>
            </label>
            <input value={title} onChange={e => setTitle(e.target.value.slice(0,60))}
              placeholder="Notification title…" className="input-field"/>
          </div>

          {/* Body */}
          <div>
            <label className="block text-white/40 text-xs font-semibold uppercase tracking-wider mb-2">
              Message <span className="text-white/20 font-normal normal-case">{body.length}/200</span>
            </label>
            <textarea value={body} onChange={e => setBody(e.target.value.slice(0,200))}
              placeholder="Notification body…" rows={3} className="input-field resize-none"/>
          </div>

          {/* Preview */}
          {(title || body) && (
            <div className="rounded-2xl p-4 border border-white/10" style={{ background: '#1A1035' }}>
              <p className="text-white/30 text-xs mb-2 uppercase tracking-wider">📱 Preview</p>
              <div className="flex gap-3">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl flex-shrink-0"
                  style={{ background: 'linear-gradient(135deg,#7C3AED,#60A5FA)' }}>🎲</div>
                <div>
                  <p className="text-white font-bold text-sm">{title || 'Title'}</p>
                  <p className="text-white/60 text-xs mt-0.5 leading-relaxed">{body || 'Message body'}</p>
                </div>
              </div>
            </div>
          )}

          {result && (
            <div className={`flex items-center gap-2 p-4 rounded-xl border text-sm ${result.error ? 'bg-red-500/10 border-red-500/20 text-red-400' : 'bg-green-500/10 border-green-500/20 text-green-400'}`}>
              {result.error ? <XCircle size={16}/> : <CheckCircle size={16}/>}
              {result.error ? result.error : `✅ Sent to ${result.sent} members${result.failed ? `, ${result.failed} failed` : ''}`}
            </div>
          )}

          <button onClick={sendNotification} disabled={sending || !title.trim() || !body.trim()} className="w-full btn-primary justify-center py-3">
            {sending ? <Loader size={16} className="animate-spin"/> : <Send size={16}/>}
            {sending ? 'Sending…' : `Send to ${target==='all' ? 'All Members' : `${selUsers.length} selected`}`}
          </button>
        </div>

        {/* Templates */}
        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-3">📋 Templates</h3>
          <div className="grid grid-cols-2 gap-2">
            {TEMPLATES.map(t => (
              <button key={t.title} onClick={() => applyTemplate(t)}
                className="text-left p-3 rounded-xl bg-white/4 hover:bg-white/8 border border-white/8 hover:border-primary/30 transition-all">
                <p className="text-sm font-semibold text-white">{t.emoji} {t.title}</p>
                <p className="text-xs text-white/40 mt-0.5 truncate">{t.body}</p>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* History */}
      <div className="col-span-5">
        <div className="glass-card overflow-hidden">
          <div className="px-5 py-4 border-b border-white/8 flex items-center justify-between">
            <h3 className="text-white font-bold text-sm">📜 History</h3>
            <span className="text-white/30 text-xs">{history.length} total</span>
          </div>
          <div className="max-h-[600px] overflow-y-auto divide-y divide-white/5">
            {history.map(n => (
              <div key={n.id} className="px-5 py-3">
                <div className="flex items-start justify-between gap-2 mb-1">
                  <p className="text-white font-semibold text-xs leading-tight">{n.title}</p>
                  <span className={`badge flex-shrink-0 ${n.sent ? 'bg-green-500/15 text-green-400' : 'bg-yellow-500/15 text-yellow-400'}`}>
                    {n.sent ? '✓ Sent' : '⏳'}
                  </span>
                </div>
                <p className="text-white/50 text-xs leading-relaxed">{n.body}</p>
                <p className="text-white/25 text-xs mt-1">{timeAgo(n.timestamp)}</p>
              </div>
            ))}
            {history.length === 0 && <p className="text-center py-12 text-white/20 text-sm">No notifications sent yet</p>}
          </div>
        </div>
      </div>
    </div>
  )
}
