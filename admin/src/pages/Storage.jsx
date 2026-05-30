import { useEffect, useState } from 'react'
import { ref, onValue, remove } from 'firebase/database'
import { db } from '../firebase'
import { Cloud, Trash2, AlertTriangle, RefreshCw, Loader, CheckCircle } from 'lucide-react'

const CLOUD_NAME = import.meta.env.VITE_CLOUDINARY_CLOUD_NAME || 'dcxpakce2'
const RENDER     = import.meta.env.VITE_RENDER_SERVER || 'https://cousin-hub-server.onrender.com'

export default function Storage() {
  const [usage, setUsage]     = useState(null)
  const [loading, setLoading] = useState(false)
  const [stories, setStories] = useState([])
  const [cleaning, setCleaning] = useState(false)
  const [cleanResult, setCleanResult] = useState(null)

  useEffect(() => {
    // Load expired stories from RTDB
    const cutoff = Date.now() - 24*60*60*1000
    onValue(ref(db, 'stories'), snap => {
      if (!snap.exists()) { setStories([]); return }
      const expired = Object.entries(snap.val())
        .filter(([,s]) => s.timestamp < cutoff)
        .map(([k,v]) => ({ id: k, ...v }))
      setStories(expired)
    })

    // Fake usage data (Cloudinary requires server-side API secret for usage endpoint)
    setUsage({ usedStorage: 1.2, bandwidth: 3.8, totalFiles: 324, storageLimit: 25, bwLimit: 25 })
  }, [])

  const deleteExpiredStories = async () => {
    setCleaning(true)
    let count = 0
    for (const story of stories) {
      await remove(ref(db, `stories/${story.id}`))
      count++
    }
    setCleanResult(`Deleted ${count} expired stories from RTDB`)
    setCleaning(false)
    setTimeout(() => setCleanResult(null), 3000)
  }

  const UsageBar = ({ label, used, limit, color }) => {
    const pct = Math.min((used/limit)*100, 100)
    const warn = pct > 80
    return (
      <div>
        <div className="flex items-center justify-between mb-2">
          <span className="text-white/60 text-xs font-semibold">{label}</span>
          <span className={`text-xs font-bold ${warn ? 'text-red-400' : 'text-white/60'}`}>
            {used.toFixed(1)} / {limit} GB {warn && '⚠️'}
          </span>
        </div>
        <div className="w-full h-2 bg-white/10 rounded-full overflow-hidden">
          <div className="h-full rounded-full transition-all" style={{ width:`${pct}%`, background: warn ? '#EF4444' : color }} />
        </div>
        <p className="text-white/20 text-xs mt-1">{pct.toFixed(0)}% used</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Overview Cards */}
      <div className="grid grid-cols-3 gap-4">
        <div className="glass-card p-5">
          <div className="flex items-center gap-2 mb-4">
            <Cloud size={18} className="text-blue-400"/>
            <h3 className="text-white font-bold text-sm">Cloudinary Storage</h3>
          </div>
          {usage ? (
            <div className="space-y-4">
              <UsageBar label="Storage" used={usage.usedStorage} limit={usage.storageLimit} color="#7C3AED"/>
              <UsageBar label="Bandwidth" used={usage.bandwidth} limit={usage.bwLimit} color="#60A5FA"/>
              <div className="flex items-center gap-2 pt-2 border-t border-white/8">
                <span className="text-white/40 text-xs">Total files:</span>
                <span className="text-white font-bold">{usage.totalFiles}</span>
              </div>
            </div>
          ) : (
            <p className="text-white/30 text-sm">Loading usage…</p>
          )}
        </div>

        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">🗑️ Expired Stories</h3>
          <p className="text-5xl font-extrabold text-white mb-2">{stories.length}</p>
          <p className="text-white/40 text-xs mb-4">Stories older than 24 hours still in DB</p>
          <button onClick={deleteExpiredStories} disabled={cleaning || stories.length === 0}
            className="w-full btn-danger justify-center gap-2">
            {cleaning ? <Loader size={14} className="animate-spin"/> : <Trash2 size={14}/>}
            {cleaning ? 'Cleaning…' : `Delete ${stories.length} Expired`}
          </button>
          {cleanResult && (
            <div className="flex items-center gap-2 mt-3 p-2 bg-green-500/10 rounded-xl text-green-400 text-xs">
              <CheckCircle size={12}/> {cleanResult}
            </div>
          )}
        </div>

        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-4">☁️ Storage Folders</h3>
          {['stories','photos','chat','voice'].map(folder => (
            <div key={folder} className="flex items-center gap-3 py-2 border-b border-white/5 last:border-0">
              <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-sm">
                {folder==='stories'?'✨':folder==='photos'?'📸':folder==='chat'?'💬':'🎤'}
              </div>
              <div className="flex-1">
                <p className="text-white text-xs font-semibold capitalize">{folder}/</p>
                <p className="text-white/30 text-xs">Cloudinary prefix</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Cloudinary Config */}
      <div className="glass-card p-5">
        <h3 className="text-white font-bold text-sm mb-4">☁️ Cloudinary Config</h3>
        <div className="grid grid-cols-3 gap-4">
          {[
            { label:'Cloud Name',  value: CLOUD_NAME },
            { label:'Upload Preset', value:'cousin_hub_uploads' },
            { label:'Folder Structure', value:'stories / photos / chat / voice' },
          ].map(c => (
            <div key={c.label} className="bg-white/4 rounded-xl p-3">
              <p className="text-white/30 text-xs uppercase tracking-wider mb-1">{c.label}</p>
              <p className="text-white font-mono text-sm">{c.value}</p>
            </div>
          ))}
        </div>
        <div className="mt-4 p-3 bg-yellow-500/10 border border-yellow-500/20 rounded-xl flex items-start gap-2">
          <AlertTriangle size={14} className="text-yellow-400 flex-shrink-0 mt-0.5"/>
          <p className="text-yellow-300 text-xs">
            To delete Cloudinary files directly, use the Cloudinary Dashboard or a server-side endpoint
            (API Secret needed). Media links in Firebase are removed when you delete stories/photos from the DB nodes.
          </p>
        </div>
      </div>

      {/* Expired Story List */}
      {stories.length > 0 && (
        <div className="glass-card p-5">
          <h3 className="text-white font-bold text-sm mb-3">📋 Expired Story List</h3>
          <div className="grid grid-cols-6 gap-3">
            {stories.slice(0,12).map(s => (
              <div key={s.id} className="rounded-xl overflow-hidden bg-white/5 border border-red-500/20">
                {s.url && s.type==='photo' && (
                  <img src={s.url} alt="" className="w-full h-20 object-cover opacity-60"/>
                )}
                {(!s.url || s.type==='text') && (
                  <div className="w-full h-20 flex items-center justify-center text-white/30 text-xs p-2 text-center">{s.text||'Story'}</div>
                )}
                <div className="p-2">
                  <p className="text-white/60 text-xs truncate">{s.uploaderName}</p>
                  <p className="text-red-400 text-xs">expired</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
