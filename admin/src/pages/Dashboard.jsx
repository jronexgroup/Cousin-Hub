import { useEffect, useState } from 'react'
import { ref, onValue, get } from 'firebase/database'
import { db } from '../firebase'
import StatCard from '../components/StatCard'
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts'
import { Bell, Plus, Activity, Trash2 } from 'lucide-react'
import { useNavigate } from 'react-router-dom'

const PURPLE = '#7C3AED'
const BLUE   = '#60A5FA'

function timeAgo(ts) {
  if (!ts) return ''
  const diff = Date.now() - ts
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h/24)}d ago`
}

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-[#1A1035] border border-white/10 rounded-xl px-3 py-2 text-xs">
      <p className="text-white/50 mb-1">{label}</p>
      {payload.map((p, i) => (
        <p key={i} style={{ color: p.color }} className="font-bold">{p.name}: {p.value}</p>
      ))}
    </div>
  )
}

export default function Dashboard() {
  const navigate = useNavigate()
  const [stats, setStats] = useState({ members: 0, online: 0, stories: 0, unread: 0, races: 0, ludo: 0 })
  const [activity, setActivity] = useState([])
  const [msgChart, setMsgChart] = useState([])
  const [featureChart, setFeatureChart] = useState([])

  useEffect(() => {
    // Members
    const unsub1 = onValue(ref(db, 'users'), snap => {
      if (!snap.exists()) return
      const users = Object.entries(snap.val())
      const now = Date.now()
      const online = users.filter(([, u]) => u.lastSeen && (now - u.lastSeen) < 5*60*1000).length
      setStats(s => ({ ...s, members: users.length, online }))
    })

    // Stories
    const unsub2 = onValue(ref(db, 'stories'), snap => {
      if (!snap.exists()) return
      const cutoff = Date.now() - 24*60*60*1000
      const active = Object.values(snap.val()).filter(s => s.timestamp > cutoff).length
      setStats(s => ({ ...s, stories: active }))
    })

    // Unread notifications
    const unsub3 = onValue(ref(db, 'notifications'), snap => {
      if (!snap.exists()) return
      const unread = Object.values(snap.val()).filter(n => !n.sent).length
      setStats(s => ({ ...s, unread }))
    })

    // Active races + ludo
    const unsub4 = onValue(ref(db, 'raceRooms'), snap => {
      if (!snap.exists()) return
      const races = Object.values(snap.val()).filter(r => r.status === 'playing').length
      setStats(s => ({ ...s, races }))
    })
    const unsub5 = onValue(ref(db, 'ludoRooms'), snap => {
      if (!snap.exists()) return
      const ludo = Object.values(snap.val()).filter(r => r.status === 'playing').length
      setStats(s => ({ ...s, ludo }))
    })

    // Recent activity
    const unsub6 = onValue(ref(db, 'adminLogs'), snap => {
      if (!snap.exists()) return
      const logs = Object.entries(snap.val()).map(([k, v]) => ({ id: k, ...v }))
        .sort((a, b) => b.timestamp - a.timestamp).slice(0, 20)
      setActivity(logs)
    })

    // Synthetic chart data (last 14 days)
    const days = Array.from({ length: 14 }, (_, i) => {
      const d = new Date(); d.setDate(d.getDate() - (13 - i))
      return { date: `${d.getMonth()+1}/${d.getDate()}`, messages: Math.floor(Math.random()*80+10), users: Math.floor(Math.random()*8+1) }
    })
    setMsgChart(days)

    setFeatureChart([
      { name: 'Chat',     value: 45, color: BLUE   },
      { name: 'Stories',  value: 20, color: '#EC4899' },
      { name: 'Games',    value: 22, color: '#F59E0B' },
      { name: 'Calls',    value: 8,  color: '#10B981' },
      { name: 'Location', value: 5,  color: '#EF4444' },
    ])

    return () => [unsub1,unsub2,unsub3,unsub4,unsub5,unsub6].forEach(u => u())
  }, [])

  const statCards = [
    { emoji: '👥', label: 'Total Members', value: stats.members, color: PURPLE, sub: 'registered users' },
    { emoji: '🟢', label: 'Online Now',    value: stats.online,  color: '#10B981', sub: 'active < 5 min' },
    { emoji: '✨', label: 'Active Stories', value: stats.stories, color: '#EC4899', sub: 'last 24 hours' },
    { emoji: '🔔', label: 'Unsent Notifs', value: stats.unread,  color: '#F59E0B', sub: 'in queue' },
    { emoji: '🏃', label: 'Active Races',  value: stats.races,   color: '#EF4444', sub: 'playing now' },
    { emoji: '🎲', label: 'Ludo Rooms',    value: stats.ludo,    color: '#3B82F6', sub: 'playing now' },
  ]

  return (
    <div className="space-y-6">
      {/* Stat Cards */}
      <div className="grid grid-cols-6 gap-4">
        {statCards.map(c => <StatCard key={c.label} {...c} />)}
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-12 gap-4">
        {/* Messages Chart */}
        <div className="col-span-7 glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">📬 Messages per Day (Last 14 Days)</h3>
          <ResponsiveContainer width="100%" height={180}>
            <BarChart data={msgChart} margin={{ top: 0, right: 0, bottom: 0, left: -20 }}>
              <XAxis dataKey="date" tick={{ fill: '#ffffff30', fontSize: 10 }} />
              <YAxis tick={{ fill: '#ffffff30', fontSize: 10 }} />
              <Tooltip content={<CustomTooltip />} />
              <Bar dataKey="messages" fill={BLUE} radius={[4,4,0,0]} name="Messages" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Feature Usage Pie */}
        <div className="col-span-5 glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">🎯 Feature Usage</h3>
          <div className="flex items-center gap-4">
            <ResponsiveContainer width={140} height={140}>
              <PieChart>
                <Pie data={featureChart} cx={65} cy={65} innerRadius={40} outerRadius={65}
                  dataKey="value" paddingAngle={2}>
                  {featureChart.map((e, i) => <Cell key={i} fill={e.color} />)}
                </Pie>
                <Tooltip content={<CustomTooltip />} />
              </PieChart>
            </ResponsiveContainer>
            <div className="flex-1 space-y-2">
              {featureChart.map(f => (
                <div key={f.name} className="flex items-center gap-2">
                  <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: f.color }} />
                  <span className="text-white/60 text-xs flex-1">{f.name}</span>
                  <span className="text-white font-bold text-xs">{f.value}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Activity Feed + Quick Actions */}
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-8 glass-card p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-white font-bold text-sm flex items-center gap-2">
              <Activity size={15} className="text-purple-400" /> Recent Activity
            </h3>
            <span className="text-white/30 text-xs">{activity.length} events</span>
          </div>
          <div className="space-y-2 max-h-72 overflow-y-auto">
            {activity.length === 0 ? (
              <div className="text-white/20 text-sm text-center py-8">No activity yet</div>
            ) : activity.map(log => (
              <div key={log.id} className="flex items-center gap-3 py-2 border-b border-white/5 last:border-0">
                <span className="text-base flex-shrink-0">{log.emoji || '📋'}</span>
                <p className="text-white/70 text-xs flex-1">{log.message || log.action}</p>
                <span className="text-white/25 text-xs flex-shrink-0">{timeAgo(log.timestamp)}</span>
              </div>
            ))}
            {activity.length === 0 && (
              <>
                {[
                  {emoji:'🟢',msg:'Admin Panel started',t: Date.now()-120000},
                  {emoji:'📊',msg:'Dashboard loaded',t: Date.now()-60000},
                ].map((a,i) => (
                  <div key={i} className="flex items-center gap-3 py-2 border-b border-white/5">
                    <span className="text-base">{a.emoji}</span>
                    <p className="text-white/70 text-xs flex-1">{a.msg}</p>
                    <span className="text-white/25 text-xs">{timeAgo(a.t)}</span>
                  </div>
                ))}
              </>
            )}
          </div>
        </div>

        {/* Quick Actions */}
        <div className="col-span-4 glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">⚡ Quick Actions</h3>
          <div className="space-y-2">
            {[
              { emoji:'🔔', label:'Send Notification', to:'/notifications', color:'#7C3AED' },
              { emoji:'🎫', label:'Add Invite Code',   to:'/config',        color:'#10B981' },
              { emoji:'🛡️', label:'Moderate Stories',  to:'/moderation',   color:'#EC4899' },
              { emoji:'📊', label:'View Analytics',    to:'/analytics',     color:'#F59E0B' },
              { emoji:'🗄️', label:'Browse Database',   to:'/database',     color:'#60A5FA' },
            ].map(a => (
              <button key={a.label} onClick={() => navigate(a.to)}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-white/4 hover:bg-white/8
                           border border-white/8 hover:border-white/15 transition-all duration-200 text-left group">
                <span className="text-lg">{a.emoji}</span>
                <span className="text-white/70 group-hover:text-white text-sm font-medium transition-colors">{a.label}</span>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
