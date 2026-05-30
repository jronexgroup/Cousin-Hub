import { useEffect, useState } from 'react'
import { ref, onValue, get } from 'firebase/database'
import { db } from '../firebase'
import { Shield, AlertTriangle, CheckCircle, Clock, Users, Lock } from 'lucide-react'

function timeAgo(ts) {
  if (!ts) return ''
  const m = Math.floor((Date.now() - ts) / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h/24)}d ago`
}

const RECOMMENDED_RULES = `{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null",
    "adminLogs": {
      ".write": "auth != null && root.child('users').child(auth.uid).child('role').val() === 'admin'"
    }
  }
}`

export default function Security() {
  const [logs, setLogs]         = useState([])
  const [activeUsers, setActive] = useState([])
  const [tab, setTab]           = useState('audit')

  useEffect(() => {
    const unsub1 = onValue(ref(db, 'adminLogs'), snap => {
      if (!snap.exists()) { setLogs([]); return }
      const list = Object.entries(snap.val())
        .map(([k,v]) => ({ id:k, ...v }))
        .sort((a,b) => b.timestamp - a.timestamp)
      setLogs(list)
    })

    const unsub2 = onValue(ref(db, 'users'), snap => {
      if (!snap.exists()) { setActive([]); return }
      const now = Date.now()
      const active = Object.entries(snap.val())
        .filter(([,u]) => u.lastSeen && (now - u.lastSeen) < 5*60*1000)
        .map(([uid,u]) => ({ uid, ...u }))
      setActive(active)
    })

    return () => { unsub1(); unsub2() }
  }, [])

  const ACTION_COLORS = {
    MEMBER_BANNED:    { color:'#EF4444', bg:'#EF444420' },
    MEMBER_DELETED:   { color:'#EF4444', bg:'#EF444420' },
    MEMBER_PROMOTED:  { color:'#F59E0B', bg:'#F59E0B20' },
    MEMBER_DEMOTED:   { color:'#60A5FA', bg:'#60A5FA20' },
    STORY_DELETED:    { color:'#EC4899', bg:'#EC489920' },
    NOTIFICATION_SENT:{ color:'#7C3AED', bg:'#7C3AED20' },
    CONFIG_UPDATED:   { color:'#10B981', bg:'#10B98120' },
    INVITE_CODE_ADDED:{ color:'#10B981', bg:'#10B98120' },
    BULK_DELETE:      { color:'#EF4444', bg:'#EF444420' },
  }

  const exportCSV = () => {
    const rows = [['Action','Message','Timestamp'],...logs.map(l => [l.action, l.message, new Date(l.timestamp).toISOString()])]
    const csv = rows.map(r => r.map(c => `"${c}"`).join(',')).join('\n')
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([csv]))
    a.download = 'admin_logs.csv'; a.click()
  }

  return (
    <div className="space-y-4">
      {/* Status Banner */}
      <div className="glass-card p-4 flex items-center gap-4">
        <div className="w-10 h-10 rounded-xl bg-green-500/15 border border-green-500/20 flex items-center justify-center">
          <Shield size={20} className="text-green-400"/>
        </div>
        <div className="flex-1">
          <p className="text-white font-bold text-sm">Security Status: Active</p>
          <p className="text-white/40 text-xs">Firebase Auth required for all reads/writes</p>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"/>
          <span className="text-green-400 text-xs font-semibold">{activeUsers.length} online now</span>
        </div>
      </div>

      {/* Tabs */}
      <div className="glass-card p-1 flex gap-1 w-fit">
        {['audit','active','rules'].map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-xl text-sm font-semibold capitalize transition-all ${tab===t ? 'bg-primary text-white' : 'text-white/50 hover:text-white hover:bg-white/5'}`}>
            {t==='audit'?'📋 Audit Log':t==='active'?'🟢 Active Sessions':'🔐 Rules'}
          </button>
        ))}
      </div>

      {/* AUDIT LOG */}
      {tab === 'audit' && (
        <div className="glass-card overflow-hidden">
          <div className="px-5 py-4 border-b border-white/8 flex items-center justify-between">
            <h3 className="text-white font-bold text-sm">Admin Audit Log</h3>
            <div className="flex items-center gap-2">
              <span className="text-white/30 text-xs">{logs.length} entries</span>
              <button onClick={exportCSV} className="btn-ghost text-xs py-1.5 px-3">
                ⬇️ Export CSV
              </button>
            </div>
          </div>
          <div className="max-h-[500px] overflow-y-auto divide-y divide-white/5">
            {logs.map(log => {
              const style = ACTION_COLORS[log.action] || { color:'#7C3AED', bg:'#7C3AED20' }
              return (
                <div key={log.id} className="flex items-start gap-4 px-5 py-3 hover:bg-white/3 transition-colors">
                  <span className="text-xl flex-shrink-0">{log.emoji || '📋'}</span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <span className="badge text-xs px-2 py-0.5 rounded-full font-bold"
                        style={{ color: style.color, background: style.bg }}>
                        {log.action}
                      </span>
                    </div>
                    <p className="text-white/70 text-xs">{log.message}</p>
                  </div>
                  <div className="flex items-center gap-1.5 text-white/25 text-xs flex-shrink-0">
                    <Clock size={11}/>
                    {timeAgo(log.timestamp)}
                  </div>
                </div>
              )
            })}
            {logs.length === 0 && (
              <p className="text-center py-12 text-white/20 text-sm">No admin actions logged yet</p>
            )}
          </div>
        </div>
      )}

      {/* ACTIVE SESSIONS */}
      {tab === 'active' && (
        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">
            🟢 Active Sessions ({activeUsers.length} online now)
          </h3>
          {activeUsers.length === 0 ? (
            <p className="text-white/30 text-sm text-center py-8">No one online right now</p>
          ) : (
            <div className="grid grid-cols-3 gap-3">
              {activeUsers.map(u => (
                <div key={u.uid} className="flex items-center gap-3 p-3 bg-white/4 rounded-xl border border-green-500/20">
                  <div className="relative">
                    <div className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold text-white"
                      style={{ background:'linear-gradient(135deg,#7C3AED,#60A5FA)' }}>
                      {u.name?.[0]?.toUpperCase() || '?'}
                    </div>
                    <div className="absolute bottom-0 right-0 w-3 h-3 bg-green-400 rounded-full border-2 border-[#0F0A1E]"/>
                  </div>
                  <div className="min-w-0">
                    <p className="text-white font-semibold text-sm truncate">{u.nickname || u.name}</p>
                    <p className="text-white/40 text-xs">Active {timeAgo(u.lastSeen)}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* RULES */}
      {tab === 'rules' && (
        <div className="space-y-4">
          <div className="glass-card p-5">
            <div className="flex items-center gap-2 mb-4">
              <CheckCircle size={16} className="text-green-400"/>
              <h3 className="text-white font-bold text-sm">Recommended Firebase Rules</h3>
            </div>
            <pre className="bg-black/30 rounded-xl p-4 font-mono text-xs text-green-300/80 overflow-x-auto leading-relaxed">
              {RECOMMENDED_RULES}
            </pre>
            <div className="mt-4 p-3 bg-blue-500/10 border border-blue-500/20 rounded-xl">
              <p className="text-blue-300 text-xs">
                ℹ️ Apply these rules in Firebase Console → Realtime Database → Rules tab.
                These ensure only authenticated users can read/write, and only admins can write to adminLogs.
              </p>
            </div>
          </div>

          <div className="glass-card p-5">
            <div className="flex items-center gap-2 mb-3">
              <AlertTriangle size={16} className="text-yellow-400"/>
              <h3 className="text-white font-bold text-sm">Security Checklist</h3>
            </div>
            {[
              { ok:true,  label:'Firebase Auth required for access' },
              { ok:true,  label:'Admin role verified on login' },
              { ok:true,  label:'All admin actions logged to adminLogs/' },
              { ok:true,  label:'Session re-checked on every navigation' },
              { ok:false, label:'Firebase rules applied (apply manually in Console)' },
              { ok:false, label:'Cloudinary API secret NOT exposed in frontend (use Render server)' },
            ].map((c, i) => (
              <div key={i} className="flex items-center gap-3 py-2 border-b border-white/5 last:border-0">
                {c.ok
                  ? <CheckCircle size={15} className="text-green-400 flex-shrink-0"/>
                  : <AlertTriangle size={15} className="text-yellow-400 flex-shrink-0"/>
                }
                <p className={`text-sm ${c.ok ? 'text-white/70' : 'text-yellow-300'}`}>{c.label}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
