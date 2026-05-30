import { useEffect, useState } from 'react'
import { ref, onValue, get, set, remove } from 'firebase/database'
import { db } from '../firebase'
import { ChevronRight, ChevronDown, Edit2, Trash2, Check, X, RefreshCw, ExternalLink } from 'lucide-react'

const SHORTCUTS = ['users','chats','stories','raceRooms','ludoRooms','notifications','appConfig','userStats','adminLogs','inviteCodes','liveLocations']

function JsonNode({ nodeKey, value, depth = 0, onDelete }) {
  const [open, setOpen] = useState(depth < 1)
  const isObj = value !== null && typeof value === 'object'
  const entries = isObj ? Object.entries(value) : []
  const indent = depth * 16

  if (!isObj) {
    const typeColor = typeof value === 'boolean' ? 'text-yellow-400' : typeof value === 'number' ? 'text-blue-300' : 'text-green-300'
    return (
      <div className="flex items-center gap-2 py-0.5 group" style={{ paddingLeft: indent }}>
        <span className="text-purple-300 font-mono text-xs">{nodeKey}</span>
        <span className="text-white/30 text-xs">:</span>
        <span className={`font-mono text-xs ${typeColor}`}>{String(value)}</span>
        {onDelete && (
          <button onClick={onDelete} className="opacity-0 group-hover:opacity-100 text-red-400/50 hover:text-red-400 p-0.5 rounded transition-all">
            <Trash2 size={11}/>
          </button>
        )}
      </div>
    )
  }

  return (
    <div>
      <div className="flex items-center gap-1 py-0.5 cursor-pointer hover:bg-white/3 rounded px-1 group"
        style={{ paddingLeft: indent }} onClick={() => setOpen(o => !o)}>
        {open ? <ChevronDown size={12} className="text-white/40"/> : <ChevronRight size={12} className="text-white/40"/>}
        <span className="text-purple-300 font-mono text-xs font-semibold">{nodeKey}</span>
        <span className="text-white/20 text-xs ml-1">{`{${entries.length}}`}</span>
        {onDelete && (
          <button onClick={e => { e.stopPropagation(); onDelete() }}
            className="opacity-0 group-hover:opacity-100 text-red-400/50 hover:text-red-400 p-0.5 rounded transition-all ml-auto mr-2">
            <Trash2 size={11}/>
          </button>
        )}
      </div>
      {open && entries.map(([k, v]) => (
        <JsonNode key={k} nodeKey={k} value={v} depth={depth+1} />
      ))}
    </div>
  )
}

export default function Database() {
  const [path, setPath] = useState('appConfig')
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const fetchData = async (p = path) => {
    setLoading(true); setError(''); setData(null)
    try {
      const snap = await get(ref(db, p))
      setData(snap.exists() ? snap.val() : '(empty)')
    } catch (e) {
      setError(e.message)
    }
    setLoading(false)
  }

  useEffect(() => { fetchData() }, [])

  return (
    <div className="space-y-4">
      {/* Path bar */}
      <div className="glass-card p-4 flex items-center gap-3">
        <span className="text-purple-400 font-mono text-sm flex-shrink-0">RTDB /</span>
        <input value={path} onChange={e => setPath(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && fetchData()}
          className="input-field flex-1 font-mono text-sm py-2"
          placeholder="path/to/node" />
        <button onClick={() => fetchData()} className="btn-primary">
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''}/> Fetch
        </button>
      </div>

      {/* Shortcuts */}
      <div className="flex flex-wrap gap-2">
        {SHORTCUTS.map(s => (
          <button key={s} onClick={() => { setPath(s); fetchData(s) }}
            className={`px-3 py-1.5 rounded-xl text-xs font-mono font-semibold transition-all ${
              path === s ? 'bg-primary text-white' : 'bg-white/5 hover:bg-white/10 text-white/60'}`}>
            {s}/
          </button>
        ))}
      </div>

      {/* Data viewer */}
      <div className="glass-card p-5 min-h-64">
        <div className="flex items-center justify-between mb-4">
          <p className="text-white/40 text-xs font-mono">/{path}</p>
          {data && typeof data === 'object' && (
            <span className="badge bg-white/8 text-white/40">{Object.keys(data).length} keys</span>
          )}
        </div>

        {loading && <div className="text-center py-8 text-white/30 text-sm">Loading…</div>}
        {error   && <div className="text-red-400 text-sm">{error}</div>}
        {!loading && !error && data !== null && (
          <div className="font-mono text-xs overflow-auto max-h-[500px]">
            {typeof data === 'object'
              ? Object.entries(data).map(([k,v]) => (
                  <JsonNode key={k} nodeKey={k} value={v} depth={0} />
                ))
              : <span className="text-green-300">{String(data)}</span>
            }
          </div>
        )}
        {!loading && !error && data === null && (
          <p className="text-white/20 text-sm text-center py-8">Press Fetch to load data</p>
        )}
      </div>

      {/* Raw JSON */}
      {data && (
        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-3">📄 Raw JSON</h3>
          <pre className="text-xs font-mono text-green-300/70 overflow-auto max-h-64 leading-relaxed">
            {JSON.stringify(data, null, 2)}
          </pre>
        </div>
      )}
    </div>
  )
}
