import { useEffect, useState } from 'react'
import { ref, onValue, remove, push } from 'firebase/database'
import { db } from '../firebase'
import { Trash2, Eye, Search, Filter, Grid, MessageSquare, Image, Play } from 'lucide-react'
import Modal from '../components/Modal'

function timeAgo(ts) {
  if (!ts) return ''
  const m = Math.floor((Date.now() - ts) / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  return `${Math.floor(m/60)}h ago`
}

async function logAction(action, message) {
  await push(ref(db, 'adminLogs'), { action, message, emoji: '🛡️', timestamp: Date.now() })
}

export default function Moderation() {
  const [tab, setTab] = useState('stories')
  const [stories, setStories] = useState([])
  const [photos, setPhotos] = useState([])
  const [chats, setChats] = useState([])
  const [chatGroup, setChatGroup] = useState('main')
  const [search, setSearch] = useState('')
  const [preview, setPreview] = useState(null)
  const [selected, setSelected] = useState([])
  const [confirmBulk, setConfirmBulk] = useState(false)

  useEffect(() => {
    const cutoff = Date.now() - 24*60*60*1000
    const unsub1 = onValue(ref(db, 'stories'), snap => {
      if (!snap.exists()) { setStories([]); return }
      const list = Object.entries(snap.val())
        .map(([k,v]) => ({id:k,...v}))
        .filter(s => s.timestamp > cutoff)
        .sort((a,b) => b.timestamp - a.timestamp)
      setStories(list)
    })
    const unsub2 = onValue(ref(db, 'photos'), snap => {
      if (!snap.exists()) { setPhotos([]); return }
      setPhotos(Object.entries(snap.val()).map(([k,v]) => ({id:k,...v})).sort((a,b) => b.timestamp - a.timestamp))
    })
    return () => { unsub1(); unsub2() }
  }, [])

  useEffect(() => {
    const unsub = onValue(ref(db, `chats/${chatGroup}`), snap => {
      if (!snap.exists()) { setChats([]); return }
      const list = Object.entries(snap.val()).map(([k,v]) => ({id:k,...v})).sort((a,b) => b.timestamp - a.timestamp)
      setChats(list)
    })
    return unsub
  }, [chatGroup])

  const deleteStory = async (id) => {
    await remove(ref(db, `stories/${id}`))
    await logAction('STORY_DELETED', `Admin deleted story`)
    setPreview(null)
  }

  const deletePhoto = async (id) => {
    await remove(ref(db, `photos/${id}`))
    await logAction('PHOTO_DELETED', `Admin deleted photo`)
  }

  const deleteMsg = async (id) => {
    await remove(ref(db, `chats/${chatGroup}/${id}`))
    await logAction('MESSAGE_DELETED', `Admin deleted message from ${chatGroup}`)
  }

  const bulkDelete = async () => {
    for (const id of selected) await remove(ref(db, `stories/${id}`))
    await logAction('BULK_DELETE', `Admin bulk deleted ${selected.length} stories`)
    setSelected([])
    setConfirmBulk(false)
  }

  const toggleSelect = (id) => setSelected(s => s.includes(id) ? s.filter(x=>x!==id) : [...s,id])

  const filteredChat = chats.filter(m => !search || m.text?.toLowerCase().includes(search.toLowerCase()) || m.senderName?.toLowerCase().includes(search.toLowerCase()))

  return (
    <div className="space-y-4">
      {/* Tab Bar */}
      <div className="glass-card p-1 flex gap-1 w-fit">
        {[
          { id:'stories', icon:'✨', label:'Stories' },
          { id:'photos',  icon:'📸', label:'Photos' },
          { id:'chat',    icon:'💬', label:'Chat' },
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold transition-all ${
              tab === t.id ? 'bg-primary text-white' : 'text-white/50 hover:text-white hover:bg-white/5'}`}>
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {/* STORIES */}
      {tab === 'stories' && (
        <div className="space-y-4">
          <div className="flex items-center gap-3">
            <p className="text-white/50 text-sm flex-1">{stories.length} active stories (last 24h)</p>
            {selected.length > 0 && (
              <button onClick={() => setConfirmBulk(true)} className="btn-danger">
                <Trash2 size={14}/> Delete {selected.length} selected
              </button>
            )}
          </div>
          <div className="grid grid-cols-4 gap-3">
            {stories.map(s => (
              <div key={s.id}
                className={`relative rounded-xl overflow-hidden cursor-pointer group border-2 transition-all ${selected.includes(s.id) ? 'border-primary' : 'border-transparent'}`}
                style={{ aspectRatio: '9/16', background: s.type==='text' ? `#${(s.bgColor||0x7C3AED).toString(16).slice(-6)}` : '#000' }}
                onClick={() => setPreview(s)}>
                {s.type === 'photo' && s.url && (
                  <img src={s.url} alt="" className="w-full h-full object-cover" />
                )}
                {s.type === 'video' && (
                  <div className="w-full h-full flex items-center justify-center">
                    <Play size={32} className="text-white/50" />
                  </div>
                )}
                {s.type === 'text' && (
                  <div className="w-full h-full flex items-center justify-center p-3">
                    <p className="text-white font-bold text-center text-xs leading-tight">{s.text}</p>
                  </div>
                )}
                {/* Overlay */}
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-all flex items-center justify-center opacity-0 group-hover:opacity-100">
                  <Eye size={20} className="text-white" />
                </div>
                {/* Checkbox */}
                <div className="absolute top-2 left-2" onClick={e => { e.stopPropagation(); toggleSelect(s.id) }}>
                  <div className={`w-5 h-5 rounded border-2 flex items-center justify-center text-xs
                    ${selected.includes(s.id) ? 'bg-primary border-primary text-white' : 'border-white/40 bg-black/30'}`}>
                    {selected.includes(s.id) && '✓'}
                  </div>
                </div>
                {/* Info */}
                <div className="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/80 to-transparent">
                  <p className="text-white text-xs font-semibold truncate">{s.uploaderName}</p>
                  <p className="text-white/50 text-xs">👁 {Object.keys(s.views||{}).length} · {timeAgo(s.timestamp)}</p>
                </div>
              </div>
            ))}
            {stories.length === 0 && (
              <div className="col-span-4 text-center py-16 text-white/20">No active stories</div>
            )}
          </div>
        </div>
      )}

      {/* PHOTOS */}
      {tab === 'photos' && (
        <div className="grid grid-cols-4 gap-3">
          {photos.map(p => (
            <div key={p.id} className="relative group rounded-xl overflow-hidden glass-card">
              {p.url && <img src={p.url} alt="" className="w-full h-40 object-cover" />}
              <div className="p-3">
                <p className="text-white text-xs font-semibold truncate">{p.uploaderName || 'Unknown'}</p>
                <p className="text-white/30 text-xs">{timeAgo(p.timestamp)}</p>
              </div>
              <button onClick={() => deletePhoto(p.id)}
                className="absolute top-2 right-2 w-7 h-7 bg-red-500 rounded-full flex items-center justify-center
                           opacity-0 group-hover:opacity-100 transition-opacity">
                <Trash2 size={12} className="text-white" />
              </button>
            </div>
          ))}
          {photos.length === 0 && <div className="col-span-4 text-center py-16 text-white/20">No photos</div>}
        </div>
      )}

      {/* CHAT */}
      {tab === 'chat' && (
        <div className="glass-card overflow-hidden">
          <div className="flex items-center gap-3 p-4 border-b border-white/8">
            <select value={chatGroup} onChange={e => setChatGroup(e.target.value)}
              className="input-field w-auto text-sm">
              {['main','gaming','travel','study','foodies'].map(g => (
                <option key={g} value={g}>{g.charAt(0).toUpperCase()+g.slice(1)}</option>
              ))}
            </select>
            <div className="relative flex-1">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30" />
              <input value={search} onChange={e => setSearch(e.target.value)}
                placeholder="Search messages…" className="input-field pl-9 py-2 text-sm" />
            </div>
            <span className="text-white/30 text-xs">{filteredChat.length} messages</span>
          </div>
          <div className="max-h-[500px] overflow-y-auto divide-y divide-white/5">
            {filteredChat.map(m => (
              <div key={m.id} className="flex items-start gap-3 p-4 hover:bg-white/3 group transition-colors">
                <div className="w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center text-xs font-bold text-white"
                  style={{ background: 'linear-gradient(135deg,#7C3AED,#60A5FA)' }}>
                  {m.senderName?.[0]?.toUpperCase() || '?'}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <p className="text-white font-semibold text-xs">{m.senderName}</p>
                    <span className="badge bg-white/8 text-white/30">{m.type}</span>
                    <span className="text-white/25 text-xs">{timeAgo(m.timestamp)}</span>
                  </div>
                  <p className="text-white/60 text-sm truncate">{m.text}</p>
                </div>
                <button onClick={() => deleteMsg(m.id)}
                  className="opacity-0 group-hover:opacity-100 text-red-400/60 hover:text-red-400 p-1 rounded-lg hover:bg-red-500/10 transition-all">
                  <Trash2 size={14}/>
                </button>
              </div>
            ))}
            {filteredChat.length === 0 && <p className="text-center py-12 text-white/20 text-sm">No messages</p>}
          </div>
        </div>
      )}

      {/* Story Preview Modal */}
      <Modal open={!!preview} onClose={() => setPreview(null)} title="Story Preview">
        {preview && (
          <div className="space-y-4">
            <div className="rounded-xl overflow-hidden" style={{aspectRatio:'9/16', maxHeight:400, background: preview.type==='text' ? `#${(preview.bgColor||0x7C3AED).toString(16).slice(-6)}` : '#000'}}>
              {preview.type==='photo' && preview.url && <img src={preview.url} alt="" className="w-full h-full object-contain"/>}
              {preview.type==='text' && <div className="w-full h-full flex items-center justify-center p-6"><p className="text-white font-bold text-xl text-center">{preview.text}</p></div>}
            </div>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-white font-semibold">{preview.uploaderName}</p>
                <p className="text-white/40 text-sm">{timeAgo(preview.timestamp)} · 👁 {Object.keys(preview.views||{}).length} views</p>
              </div>
              <button onClick={() => deleteStory(preview.id)} className="btn-danger">
                <Trash2 size={14}/> Delete Story
              </button>
            </div>
          </div>
        )}
      </Modal>

      {/* Bulk Delete Confirm */}
      <Modal open={confirmBulk} onClose={() => setConfirmBulk(false)} title="Confirm Bulk Delete">
        <p className="text-white/70 text-sm mb-6">Delete <strong className="text-white">{selected.length}</strong> selected stories?</p>
        <div className="flex gap-3">
          <button onClick={() => setConfirmBulk(false)} className="btn-ghost flex-1">Cancel</button>
          <button onClick={bulkDelete} className="btn-danger flex-1">Delete All</button>
        </div>
      </Modal>
    </div>
  )
}
