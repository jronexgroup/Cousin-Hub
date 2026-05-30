import { useLocation } from 'react-router-dom'
import { LogOut, RefreshCw } from 'lucide-react'
import { useAuth } from '../context/AuthContext'

const titles = {
  '/':              { label: 'Dashboard',     emoji: '🏠' },
  '/members':       { label: 'Members',       emoji: '👥' },
  '/moderation':    { label: 'Moderation',    emoji: '🛡️' },
  '/games':         { label: 'Games',         emoji: '🎮' },
  '/notifications': { label: 'Notifications', emoji: '🔔' },
  '/config':        { label: 'App Config',    emoji: '⚙️' },
  '/analytics':     { label: 'Analytics',     emoji: '📊' },
  '/database':      { label: 'Database',      emoji: '🗄️' },
  '/storage':       { label: 'Storage',       emoji: '☁️' },
  '/security':      { label: 'Security',      emoji: '🔐' },
}

export default function Header() {
  const { pathname } = useLocation()
  const { user, logout } = useAuth()
  const current = titles[pathname] || titles['/']

  return (
    <header className="h-14 flex items-center justify-between px-6 flex-shrink-0"
      style={{ background: 'rgba(15,10,30,0.8)', borderBottom: '1px solid rgba(255,255,255,0.06)', backdropFilter: 'blur(10px)' }}>
      
      <div className="flex items-center gap-3">
        <span className="text-xl">{current.emoji}</span>
        <div>
          <h1 className="text-white font-bold text-sm leading-tight">{current.label}</h1>
          <p className="text-white/30 text-xs">Cousin Hub Admin Panel</p>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-white/5 border border-white/10">
          <div className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold text-white"
            style={{ background: 'linear-gradient(135deg, #7C3AED, #60A5FA)' }}>
            {user?.email?.[0]?.toUpperCase() || 'A'}
          </div>
          <span className="text-white/70 text-xs font-medium">{user?.email?.split('@')[0] || 'Admin'}</span>
        </div>
        <button
          onClick={logout}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-red-500/10 hover:bg-red-500/20
                     border border-red-500/20 text-red-400 hover:text-red-300 text-xs font-semibold
                     transition-all duration-200"
        >
          <LogOut size={13} />
          Logout
        </button>
      </div>
    </header>
  )
}
