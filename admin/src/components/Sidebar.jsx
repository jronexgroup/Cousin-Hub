import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard, Users, Shield, Gamepad2, Bell,
  Settings, BarChart3, Database, Cloud, Lock, ChevronRight
} from 'lucide-react'

const nav = [
  { to: '/',              icon: LayoutDashboard, label: 'Dashboard',     end: true },
  { to: '/members',       icon: Users,           label: 'Members' },
  { to: '/moderation',    icon: Shield,          label: 'Moderation' },
  { to: '/games',         icon: Gamepad2,        label: 'Games' },
  { to: '/notifications', icon: Bell,            label: 'Notifications' },
  { to: '/config',        icon: Settings,        label: 'App Config' },
  { to: '/analytics',     icon: BarChart3,       label: 'Analytics' },
  { to: '/database',      icon: Database,        label: 'Database' },
  { to: '/storage',       icon: Cloud,           label: 'Storage' },
  { to: '/security',      icon: Lock,            label: 'Security' },
]

export default function Sidebar() {
  return (
    <aside className="w-60 flex-shrink-0 flex flex-col h-full"
      style={{ background: 'linear-gradient(180deg, #0F0A1E 0%, #120E24 100%)', borderRight: '1px solid rgba(255,255,255,0.06)' }}>

      {/* Logo */}
      <div className="px-6 py-5 border-b border-white/5">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl flex items-center justify-center text-xl"
            style={{ background: 'linear-gradient(135deg, #7C3AED, #60A5FA)' }}>
            🎲
          </div>
          <div>
            <p className="text-white font-bold text-sm leading-tight">Cousin Hub</p>
            <p className="text-purple-400/70 text-xs font-medium">Admin Panel</p>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        {nav.map(({ to, icon: Icon, label, end }) => (
          <NavLink
            key={to} to={to} end={end}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 group ${
                isActive
                  ? 'bg-primary/20 text-white border border-primary/30'
                  : 'text-white/50 hover:text-white hover:bg-white/5'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <Icon size={16} className={isActive ? 'text-primary-light' : 'text-white/40 group-hover:text-white/70'} />
                <span className="flex-1">{label}</span>
                {isActive && <ChevronRight size={12} className="text-primary-light" />}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Footer */}
      <div className="px-4 py-4 border-t border-white/5">
        <div className="flex items-center gap-2 px-2">
          <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
          <span className="text-white/30 text-xs">JroNex • v1.0.0</span>
        </div>
      </div>
    </aside>
  )
}
