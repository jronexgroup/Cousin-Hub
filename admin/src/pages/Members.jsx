import { useEffect, useState } from 'react'
import { ref, onValue, update, remove, push, set } from 'firebase/database'
import { db } from '../firebase'
import Modal from '../components/Modal'
import { Search, Filter, Crown, Ban, Trash2, UserCheck, Send, X, ChevronRight, Shield, MessageSquare, Gamepad2, Star } from 'lucide-react'

function Avatar({ name, photo, size = 8 }) {
  return photo
    ? <img src={photo} alt={name} className={`w-${size} h-${size} rounded-full object-cover flex-shrink-0`} />
    : <div className={`w-${size} h-${size} rounded-full flex items-center justify-center text-white font-bold text-sm flex-shrink-0`}
        style={{ background: 'linear-gradient(135deg, #7C3AED, #60A5FA)' }}>
        {name?.[0]?.toUpperCase() || '?'}
      </div>
}

function RoleBadge({ role }) {
  return role === 'admin'
    ? <span className="badge bg-yellow-500/15 text-yellow-400 border border-yellow-500/20"><Crown size={10} />Admin</span>
    : <span className="badge bg-white/8 text-white/50">Member</span>
}

function StatusBadge({ banned }) {
  return banned
    ? <span className="badge bg-red-500/15 text-red-400 border border-red-500/20">Banned</span>
    : <span className="badge bg-green-500/15 text-green-400 border border-green-500/20">Active</span>
}

function timeAgo(ts) {
  if (!ts) return 'Never'
  const m = Math.floor((Date.now() - ts) / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h/24)}d ago`
}

async function logAction(action, message, emoji = '📋') {
  await push(ref(db, 'adminLogs'), { action, message, emoji, timestamp: Date.now() })
}

export default function Members() {
  const [members, setMembers] = useState([])
  const [search,  setSearch]  = useState('')
  const [roleF,   setRoleF]   = useState('all')
  const [statusF, setStatusF] = useState('all')
  const [sortBy,  setSortBy]  = useState('name')
  const [selected, setSelected] = useState(null)
  const [confirmAction, setConfirmAction] = useState(null)
  const [inviteOpen, setInviteOpen] = useState(false)
  const [newCode, setNewCode]  = useState('')
  const [codes, setCodes]      = useState([])

  useEffect(() => {
    const unsub = onValue(ref(db, 'users'), snap => {
      if (!snap.exists()) return
      const list = Object.entries(snap.val()).map(([uid, u]) => ({ uid, ...u }))
      setMembers(list)
    })
    const unsub2 = onValue(ref(db, 'inviteCodes'), snap => {
      if (!snap.exists()) { setCodes([]); return }
      setCodes(Object.entries(snap.val()).map(([k, v]) => ({ code: k, ...v })))
    })
    return () => { unsub(); unsub2() }
  }, [])

  const filtered = members
    .filter(m => {
      const q = search.toLowerCase()
      if (q && !m.name?.toLowerCase().includes(q) && !m.nickname?.toLowerCase().includes(q) && !m.email?.toLowerCase().includes(q)) return false
      if (roleF !== 'all' && m.role !== roleF) return false
      if (statusF === 'active' && m.banned) return false
      if (statusF === 'banned' && !m.banned) return false
      return true
    })
    .sort((a, b) => {
      if (sortBy === 'name')     return (a.name || '').localeCompare(b.name || '')
      if (sortBy === 'joined')   return (b.joinedAt || '').localeCompare(a.joinedAt || '')
      if (sortBy === 'lastSeen') return (b.lastSeen || 0) - (a.lastSeen || 0)
      return 0
    })

  const doAction = async (action, member) => {
    switch (action) {
      case 'promote':
        await update(ref(db, `users/${member.uid}`), { role: 'admin' })
        await logAction('MEMBER_PROMOTED', `Promoted ${member.name} to Admin`, '👑')
        break
      case 'demote':
        await update(ref(db, `users/${member.uid}`), { role: 'member' })
        await logAction('MEMBER_DEMOTED', `Demoted ${member.name} to Member`, '⬇️')
        break
      case 'ban':
        await update(ref(db, `users/${member.uid}`), { banned: true })
        await logAction('MEMBER_BANNED', `Banned ${member.name}`, '🔴')
        break
      case 'unban':
        await update(ref(db, `users/${member.uid}`), { banned: false })
        await logAction('MEMBER_UNBANNED', `Unbanned ${member.name}`, '✅')
        break
      case 'delete':
        await remove(ref(db, `users/${member.uid}`))
        await logAction('MEMBER_DELETED', `Deleted account: ${member.name}`, '🗑️')
        setSelected(null)
        break
    }
    setConfirmAction(null)
    if (selected?.uid === member.uid) {
      setSelected(prev => ({...prev, role: action === 'promote' ? 'admin' : action === 'demote' ? 'member' : prev?.role, banned: action === 'ban'}))
    }
  }

  const addInviteCode = async () => {
    const code = newCode.trim().toUpperCase() || Math.random().toString(36).substring(2,8).toUpperCase()
    await set(ref(db, `inviteCodes/${code}`), { active: true, createdAt: Date.now() })
    await logAction('INVITE_CODE_ADDED', `Added invite code: ${code}`, '🎫')
    setNewCode('')
  }

  const deleteCode = async (code) => {
    await remove(ref(db, `inviteCodes/${code}`))
  }

  return (
    <div className="flex gap-4 h-full">
      {/* Main Table */}
      <div className="flex-1 min-w-0 space-y-4">
        {/* Controls */}
        <div className="glass-card p-4 flex items-center gap-3 flex-wrap">
          <div className="relative flex-1 min-w-48">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30" />
            <input value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search by name, nickname, email…"
              className="input-field pl-9 py-2" />
          </div>
          <select value={roleF} onChange={e => setRoleF(e.target.value)}
            className="input-field w-auto py-2 text-xs">
            <option value="all">All Roles</option>
            <option value="admin">Admin</option>
            <option value="member">Member</option>
          </select>
          <select value={statusF} onChange={e => setStatusF(e.target.value)}
            className="input-field w-auto py-2 text-xs">
            <option value="all">All Status</option>
            <option value="active">Active</option>
            <option value="banned">Banned</option>
          </select>
          <select value={sortBy} onChange={e => setSortBy(e.target.value)}
            className="input-field w-auto py-2 text-xs">
            <option value="name">Sort: Name</option>
            <option value="joined">Sort: Joined</option>
            <option value="lastSeen">Sort: Last Active</option>
          </select>
          <button onClick={() => setInviteOpen(true)} className="btn-primary">
            <span>🎫</span> Invite Codes ({codes.filter(c=>c.active).length})
          </button>
        </div>

        {/* Table */}
        <div className="glass-card overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/8">
                <th className="table-header text-left">Member</th>
                <th className="table-header text-left">Nickname</th>
                <th className="table-header text-left">Role</th>
                <th className="table-header text-left">Joined</th>
                <th className="table-header text-left">Last Active</th>
                <th className="table-header text-left">Status</th>
                <th className="table-header"></th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(m => (
                <tr key={m.uid} className="table-row cursor-pointer" onClick={() => setSelected(m)}>
                  <td className="table-cell">
                    <div className="flex items-center gap-2.5">
                      <Avatar name={m.name} photo={m.photoUrl} />
                      <div>
                        <p className="text-white font-semibold text-sm">{m.name || '—'}</p>
                        <p className="text-white/30 text-xs">{m.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="table-cell text-white/60">{m.nickname || '—'}</td>
                  <td className="table-cell"><RoleBadge role={m.role} /></td>
                  <td className="table-cell text-white/40 text-xs">
                    {m.joinedAt ? new Date(m.joinedAt).toLocaleDateString() : '—'}
                  </td>
                  <td className="table-cell text-white/40 text-xs">{timeAgo(m.lastSeen)}</td>
                  <td className="table-cell"><StatusBadge banned={m.banned} /></td>
                  <td className="table-cell">
                    <ChevronRight size={14} className="text-white/20 group-hover:text-white/60" />
                  </td>
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr><td colSpan={7} className="text-center py-12 text-white/20 text-sm">No members found</td></tr>
              )}
            </tbody>
          </table>
          <div className="px-4 py-3 border-t border-white/5 text-white/30 text-xs">
            Showing {filtered.length} of {members.length} members
          </div>
        </div>
      </div>

      {/* Detail Drawer */}
      {selected && (
        <div className="w-96 flex-shrink-0 glass-card p-5 flex flex-col gap-4 overflow-y-auto">
          <div className="flex items-center justify-between">
            <h3 className="text-white font-bold text-sm">Member Detail</h3>
            <button onClick={() => setSelected(null)} className="text-white/30 hover:text-white p-1 rounded-lg hover:bg-white/10">
              <X size={16} />
            </button>
          </div>

          {/* Profile */}
          <div className="text-center py-4 border-b border-white/8">
            <Avatar name={selected.name} photo={selected.photoUrl} size={16} />
            <p className="text-white font-bold mt-3">{selected.name}</p>
            <p className="text-white/40 text-sm">{selected.email}</p>
            <div className="flex items-center justify-center gap-2 mt-2">
              <RoleBadge role={selected.role} />
              <StatusBadge banned={selected.banned} />
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 gap-2">
            {[
              { label:'Relation',   value: selected.relation || '—' },
              { label:'Joined',     value: selected.joinedAt ? new Date(selected.joinedAt).toLocaleDateString() : '—' },
              { label:'Last Active',value: timeAgo(selected.lastSeen) },
              { label:'Games Won',  value: selected.gamesWon ?? 0 },
              { label:'Invite Code',value: selected.inviteCode || '—' },
              { label:'Birthday',   value: selected.birthday || '—' },
            ].map(s => (
              <div key={s.label} className="bg-white/4 rounded-xl p-3">
                <p className="text-white/30 text-xs uppercase tracking-wider mb-0.5">{s.label}</p>
                <p className="text-white font-semibold text-sm">{s.value}</p>
              </div>
            ))}
          </div>

          {/* Actions */}
          <div className="space-y-2 border-t border-white/8 pt-4">
            <p className="text-white/30 text-xs uppercase tracking-wider mb-2">Actions</p>
            {selected.role !== 'admin'
              ? <button onClick={() => setConfirmAction({type:'promote', member:selected})}
                  className="w-full btn-ghost text-yellow-400 hover:text-yellow-300 border-yellow-500/20">
                  <Crown size={14}/> Promote to Admin
                </button>
              : <button onClick={() => setConfirmAction({type:'demote', member:selected})}
                  className="w-full btn-ghost">
                  <Shield size={14}/> Demote to Member
                </button>
            }
            {!selected.banned
              ? <button onClick={() => setConfirmAction({type:'ban', member:selected})}
                  className="w-full btn-ghost text-red-400 hover:text-red-300 border-red-500/20">
                  <Ban size={14}/> Ban Member
                </button>
              : <button onClick={() => doAction('unban', selected)}
                  className="w-full btn-ghost text-green-400 border-green-500/20">
                  <UserCheck size={14}/> Unban Member
                </button>
            }
            <button onClick={() => setConfirmAction({type:'delete', member:selected})}
              className="w-full btn-danger">
              <Trash2 size={14}/> Delete Account
            </button>
          </div>
        </div>
      )}

      {/* Confirm Modal */}
      <Modal open={!!confirmAction} onClose={() => setConfirmAction(null)}
        title={`Confirm: ${confirmAction?.type?.toUpperCase()}`}>
        <p className="text-white/70 text-sm mb-6">
          Are you sure you want to <strong className="text-white">{confirmAction?.type}</strong>{' '}
          <strong className="text-purple-300">{confirmAction?.member?.name}</strong>?
          {confirmAction?.type === 'delete' && (
            <span className="block mt-2 text-red-400 text-xs">⚠️ This action is permanent and cannot be undone!</span>
          )}
        </p>
        <div className="flex gap-3">
          <button onClick={() => setConfirmAction(null)} className="btn-ghost flex-1">Cancel</button>
          <button onClick={() => doAction(confirmAction.type, confirmAction.member)}
            className={confirmAction?.type === 'delete' ? 'btn-danger flex-1' : 'btn-primary flex-1'}>
            Confirm
          </button>
        </div>
      </Modal>

      {/* Invite Codes Modal */}
      <Modal open={inviteOpen} onClose={() => setInviteOpen(false)} title="🎫 Invite Codes" maxW="max-w-md">
        <div className="flex gap-2 mb-4">
          <input value={newCode} onChange={e => setNewCode(e.target.value.toUpperCase())}
            placeholder="Custom code or leave blank for random" className="input-field flex-1" />
          <button onClick={addInviteCode} className="btn-primary">Add</button>
        </div>
        <div className="space-y-2 max-h-72 overflow-y-auto">
          {codes.map(c => (
            <div key={c.code} className="flex items-center gap-3 bg-white/4 rounded-xl px-4 py-3">
              <code className="text-purple-300 font-bold font-mono text-sm flex-1 tracking-widest">{c.code}</code>
              <span className={`badge ${c.active ? 'bg-green-500/15 text-green-400' : 'bg-red-500/15 text-red-400'}`}>
                {c.active ? 'Active' : 'Inactive'}
              </span>
              <button onClick={() => navigator.clipboard.writeText(c.code)}
                className="text-white/30 hover:text-white text-xs px-2 py-1 rounded-lg hover:bg-white/10">Copy</button>
              <button onClick={() => deleteCode(c.code)}
                className="text-red-400/50 hover:text-red-400 p-1 rounded-lg hover:bg-red-500/10">
                <Trash2 size={13}/>
              </button>
            </div>
          ))}
          {codes.length === 0 && <p className="text-white/30 text-sm text-center py-4">No invite codes yet</p>}
        </div>
      </Modal>
    </div>
  )
}
