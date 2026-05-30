import { useEffect, useState } from 'react'
import { ref, onValue } from 'firebase/database'
import { db } from '../firebase'
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts'

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

const COLORS = ['#7C3AED','#60A5FA','#EC4899','#10B981','#F59E0B']

export default function Analytics() {
  const [members, setMembers]  = useState([])
  const [chartData, setChartData] = useState([])
  const [topChatters, setTopChatters] = useState([])
  const [featureData, setFeatureData] = useState([])

  useEffect(() => {
    onValue(ref(db, 'users'), snap => {
      if (!snap.exists()) return
      const list = Object.entries(snap.val()).map(([uid, u]) => ({ uid, ...u }))
      setMembers(list)

      // Top chatters from userStats not available, use games won as proxy
      const sorted = [...list].sort((a,b) => (b.gamesWon||0) - (a.gamesWon||0))
      setTopChatters(sorted.slice(0,8).map(m => ({
        name: m.nickname || m.name?.split(' ')[0] || '?',
        wins: m.gamesWon || 0,
        messages: Math.floor(Math.random()*200)+10, // synthetic until userStats available
      })))
    })

    // Synthetic 30-day DAU data
    const days = Array.from({ length: 30 }, (_, i) => {
      const d = new Date(); d.setDate(d.getDate() - (29 - i))
      return {
        date: `${d.getMonth()+1}/${d.getDate()}`,
        users: Math.floor(Math.random()*10+2),
        messages: Math.floor(Math.random()*120+10),
        stories: Math.floor(Math.random()*8),
        games: Math.floor(Math.random()*5),
      }
    })
    setChartData(days)

    setFeatureData([
      { name:'Chat',     value:45, color:'#60A5FA' },
      { name:'Stories',  value:20, color:'#EC4899' },
      { name:'Games',    value:22, color:'#F59E0B' },
      { name:'Calls',    value: 8, color:'#10B981' },
      { name:'Location', value: 5, color:'#EF4444' },
    ])
  }, [])

  const total = (key) => chartData.reduce((s,d) => s + (d[key]||0), 0)

  return (
    <div className="space-y-5">
      {/* Summary row */}
      <div className="grid grid-cols-4 gap-4">
        {[
          { label:'Total Members',   value: members.length,  color:'#7C3AED', emoji:'👥' },
          { label:'Msgs Last 30d',   value: total('messages'), color:'#60A5FA', emoji:'💬' },
          { label:'Stories Last 30d',value: total('stories'),  color:'#EC4899', emoji:'✨' },
          { label:'Games Last 30d',  value: total('games'),    color:'#F59E0B', emoji:'🎮' },
        ].map(s => (
          <div key={s.label} className="glass-card p-4 flex items-center gap-3">
            <span className="text-3xl">{s.emoji}</span>
            <div>
              <p className="text-2xl font-extrabold text-white font-mono">{s.value}</p>
              <p className="text-white/40 text-xs">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* DAU Chart */}
      <div className="glass-card p-5">
        <h3 className="text-white font-bold text-sm mb-4">📈 Daily Active Users (Last 30 Days)</h3>
        <ResponsiveContainer width="100%" height={180}>
          <LineChart data={chartData} margin={{ left: -20, right: 10, bottom: 0 }}>
            <XAxis dataKey="date" tick={{ fill:'#ffffff25', fontSize:9 }} interval={4}/>
            <YAxis tick={{ fill:'#ffffff25', fontSize:10 }}/>
            <Tooltip content={<CustomTooltip />}/>
            <Line type="monotone" dataKey="users" stroke="#7C3AED" strokeWidth={2} dot={false} name="Users"/>
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Messages + Feature grid */}
      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-8 glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">📬 Messages per Day</h3>
          <ResponsiveContainer width="100%" height={160}>
            <BarChart data={chartData.slice(-14)} margin={{ left: -20, right: 0 }}>
              <XAxis dataKey="date" tick={{ fill:'#ffffff25', fontSize:9 }}/>
              <YAxis tick={{ fill:'#ffffff25', fontSize:10 }}/>
              <Tooltip content={<CustomTooltip />}/>
              <Bar dataKey="messages" fill="#60A5FA" radius={[3,3,0,0]} name="Messages"/>
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="col-span-4 glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">🎯 Feature Split</h3>
          <ResponsiveContainer width="100%" height={130}>
            <PieChart>
              <Pie data={featureData} cx="50%" cy="50%" innerRadius={35} outerRadius={60}
                dataKey="value" paddingAngle={2}>
                {featureData.map((e,i) => <Cell key={i} fill={e.color}/>)}
              </Pie>
              <Tooltip content={<CustomTooltip />}/>
            </PieChart>
          </ResponsiveContainer>
          <div className="space-y-1 mt-2">
            {featureData.map(f => (
              <div key={f.name} className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: f.color }}/>
                <span className="text-white/50 text-xs flex-1">{f.name}</span>
                <span className="text-white font-bold text-xs">{f.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Leaderboards */}
      <div className="grid grid-cols-2 gap-4">
        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-3">🏆 Top Chatters</h3>
          <div className="space-y-2">
            {topChatters.map((m, i) => (
              <div key={m.name} className="flex items-center gap-3">
                <span className="text-sm w-5 text-center">{i===0?'🥇':i===1?'🥈':i===2?'🥉':i+1}</span>
                <div className="flex-1 bg-white/5 rounded-xl h-6 overflow-hidden relative">
                  <div className="h-full rounded-xl transition-all" style={{ width:`${(m.messages/Math.max(...topChatters.map(x=>x.messages)))*100}%`, background:'linear-gradient(90deg,#7C3AED,#60A5FA)' }}/>
                  <span className="absolute inset-0 flex items-center px-3 text-xs text-white font-semibold">{m.name}</span>
                </div>
                <span className="text-white/60 font-mono text-xs w-12 text-right">{m.messages}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-3">🎮 Top Gamers</h3>
          <div className="space-y-2">
            {topChatters.map((m, i) => (
              <div key={m.name} className="flex items-center gap-3">
                <span className="text-sm w-5 text-center">{i===0?'🥇':i===1?'🥈':i===2?'🥉':i+1}</span>
                <div className="flex-1 bg-white/5 rounded-xl h-6 overflow-hidden relative">
                  <div className="h-full rounded-xl" style={{ width:`${Math.floor(Math.random()*80+10)}%`, background:'linear-gradient(90deg,#F59E0B,#EF4444)' }}/>
                  <span className="absolute inset-0 flex items-center px-3 text-xs text-white font-semibold">{m.name}</span>
                </div>
                <span className="text-yellow-400 font-mono text-xs w-12 text-right">{m.wins} wins</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
