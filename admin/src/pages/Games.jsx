import { useEffect, useState } from 'react'
import { ref, onValue, update, remove } from 'firebase/database'
import { db } from '../firebase'
import { Gamepad2, Swords, Car, Trophy, StopCircle, Trash2 } from 'lucide-react'

function timeAgo(ts) {
  if (!ts) return ''
  const m = Math.floor((Date.now() - ts) / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  return `${Math.floor(m/60)}h ago`
}

function RoomCard({ id, room, type, onForceEnd, onDelete }) {
  const players = Object.values(room.players || {})
  const colors = ['#E53935','#1E88E5','#FDD835','#43A047']

  return (
    <div className="glass-card p-4 space-y-3">
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-2">
          <span className="text-2xl">{type === 'ludo' ? '🎲' : type === 'race' ? '🏃' : '🎮'}</span>
          <div>
            <p className="text-white font-bold text-sm">{type === 'ludo' ? 'Ludo' : type === 'race' ? 'Cousin Racer' : 'Game'}</p>
            <p className="text-white/40 text-xs font-mono">{id.slice(0,16)}…</p>
          </div>
        </div>
        <div className="flex items-center gap-1">
          <span className={`badge ${room.status === 'playing' ? 'bg-green-500/15 text-green-400' : 'bg-yellow-500/15 text-yellow-400'}`}>
            {room.status}
          </span>
        </div>
      </div>

      {/* Players */}
      <div className="flex gap-1 flex-wrap">
        {players.map((p, i) => (
          <div key={i} className="flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium"
            style={{ background: `${colors[i % colors.length]}22`, border: `1px solid ${colors[i % colors.length]}44` }}>
            <div className="w-2 h-2 rounded-full" style={{ background: colors[i % colors.length] }} />
            <span className="text-white/80">{p.name || 'Cousin'}</span>
            {type === 'race' && p.distance !== undefined && (
              <span className="text-white/40">{Math.floor(p.distance)}m</span>
            )}
          </div>
        ))}
      </div>

      {room.roomCode && (
        <p className="text-purple-300 text-xs font-mono">Room Code: <strong className="tracking-widest">{room.roomCode}</strong></p>
      )}

      <p className="text-white/30 text-xs">Created: {timeAgo(room.created || room.createdAt)}</p>

      <div className="flex gap-2 pt-1">
        <button onClick={() => onForceEnd(id)}
          className="flex-1 flex items-center justify-center gap-1.5 py-1.5 rounded-xl text-xs font-semibold
                     bg-yellow-500/10 hover:bg-yellow-500/20 border border-yellow-500/20 text-yellow-400 transition-colors">
          <StopCircle size={12}/> Force End
        </button>
        <button onClick={() => onDelete(id)}
          className="flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold
                     bg-red-500/10 hover:bg-red-500/20 border border-red-500/20 text-red-400 transition-colors">
          <Trash2 size={12}/>
        </button>
      </div>
    </div>
  )
}

export default function Games() {
  const [ludoRooms, setLudoRooms] = useState({})
  const [raceRooms, setRaceRooms] = useState({})
  const [leaderboard, setLeaderboard] = useState([])
  const [tab, setTab] = useState('live')

  useEffect(() => {
    const u1 = onValue(ref(db, 'ludoRooms'), snap => setLudoRooms(snap.exists() ? snap.val() : {}))
    const u2 = onValue(ref(db, 'raceRooms'), snap => setRaceRooms(snap.exists() ? snap.val() : {}))
    const u3 = onValue(ref(db, 'users'), snap => {
      if (!snap.exists()) return
      const list = Object.entries(snap.val())
        .map(([uid, u]) => ({ uid, name: u.name, nickname: u.nickname, photo: u.photoUrl, wins: u.gamesWon || 0 }))
        .sort((a,b) => b.wins - a.wins)
      setLeaderboard(list)
    })
    return () => { u1(); u2(); u3() }
  }, [])

  const forceEndLudo = async (id) => {
    await update(ref(db, `ludoRooms/${id}`), { status: 'finished' })
  }
  const forceEndRace = async (id) => {
    await update(ref(db, `raceRooms/${id}`), { status: 'finished' })
  }
  const deleteLudo = async (id) => remove(ref(db, `ludoRooms/${id}`))
  const deleteRace = async (id) => remove(ref(db, `raceRooms/${id}`))

  const allLudo = Object.entries(ludoRooms)
  const allRace = Object.entries(raceRooms)
  const playingLudo = allLudo.filter(([,r]) => r.status === 'playing').length
  const playingRace = allRace.filter(([,r]) => r.status === 'playing').length

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-4 gap-4">
        {[
          { emoji:'🎲', label:'Total Ludo Rooms',  value: allLudo.length,  color:'#7C3AED' },
          { emoji:'▶️', label:'Playing Now',       value: playingLudo,     color:'#10B981' },
          { emoji:'🏃', label:'Total Race Rooms',  value: allRace.length,  color:'#EF4444' },
          { emoji:'🏁', label:'Racing Now',        value: playingRace,     color:'#F59E0B' },
        ].map(s => (
          <div key={s.label} className="glass-card p-4 flex items-center gap-3">
            <div className="text-3xl">{s.emoji}</div>
            <div>
              <p className="text-2xl font-extrabold text-white">{s.value}</p>
              <p className="text-white/40 text-xs">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Tabs */}
      <div className="glass-card p-1 flex gap-1 w-fit">
        {['live','ludo','race','leaderboard'].map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-xl text-sm font-semibold capitalize transition-all ${tab===t ? 'bg-primary text-white' : 'text-white/50 hover:text-white hover:bg-white/5'}`}>
            {t === 'leaderboard' ? '🏆 Leaderboard' : t === 'live' ? '🔴 Live' : t === 'ludo' ? '🎲 Ludo All' : '🏃 Race All'}
          </button>
        ))}
      </div>

      {/* Live Rooms */}
      {tab === 'live' && (
        <div className="grid grid-cols-3 gap-4">
          {allLudo.filter(([,r]) => r.status === 'playing').map(([id, room]) => (
            <RoomCard key={id} id={id} room={room} type="ludo" onForceEnd={forceEndLudo} onDelete={deleteLudo} />
          ))}
          {allRace.filter(([,r]) => r.status === 'playing').map(([id, room]) => (
            <RoomCard key={id} id={id} room={room} type="race" onForceEnd={forceEndRace} onDelete={deleteRace} />
          ))}
          {playingLudo === 0 && playingRace === 0 && (
            <div className="col-span-3 text-center py-16 text-white/20">No active games right now</div>
          )}
        </div>
      )}

      {/* All Ludo */}
      {tab === 'ludo' && (
        <div className="grid grid-cols-3 gap-4">
          {allLudo.map(([id, room]) => (
            <RoomCard key={id} id={id} room={room} type="ludo" onForceEnd={forceEndLudo} onDelete={deleteLudo} />
          ))}
          {allLudo.length === 0 && <div className="col-span-3 text-center py-16 text-white/20">No Ludo rooms</div>}
        </div>
      )}

      {/* All Race */}
      {tab === 'race' && (
        <div className="grid grid-cols-3 gap-4">
          {allRace.map(([id, room]) => (
            <RoomCard key={id} id={id} room={room} type="race" onForceEnd={forceEndRace} onDelete={deleteRace} />
          ))}
          {allRace.length === 0 && <div className="col-span-3 text-center py-16 text-white/20">No Race rooms</div>}
        </div>
      )}

      {/* Leaderboard */}
      {tab === 'leaderboard' && (
        <div className="glass-card overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/8">
                <th className="table-header text-left">#</th>
                <th className="table-header text-left">Member</th>
                <th className="table-header text-left">Nickname</th>
                <th className="table-header text-center">🏆 Wins</th>
              </tr>
            </thead>
            <tbody>
              {leaderboard.map((m, i) => (
                <tr key={m.uid} className="table-row">
                  <td className="table-cell">
                    <span className="font-bold text-lg">{i===0?'🥇':i===1?'🥈':i===2?'🥉':i+1}</span>
                  </td>
                  <td className="table-cell">
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white"
                        style={{ background: 'linear-gradient(135deg,#7C3AED,#60A5FA)' }}>
                        {m.name?.[0]?.toUpperCase() || '?'}
                      </div>
                      <p className="text-white font-medium text-sm">{m.name}</p>
                    </div>
                  </td>
                  <td className="table-cell text-white/50">{m.nickname || '—'}</td>
                  <td className="table-cell text-center">
                    <span className="text-yellow-400 font-bold text-lg">{m.wins}</span>
                  </td>
                </tr>
              ))}
              {leaderboard.length === 0 && <tr><td colSpan={4} className="text-center py-12 text-white/20 text-sm">No data yet</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
