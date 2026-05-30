import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import Layout    from './components/Layout'
import Login     from './pages/Login'
import Dashboard from './pages/Dashboard'
import Members   from './pages/Members'
import Moderation from './pages/Moderation'
import Games     from './pages/Games'
import Notifications from './pages/Notifications'
import Config    from './pages/Config'
import Analytics from './pages/Analytics'
import Database  from './pages/Database'
import Storage   from './pages/Storage'
import Security  from './pages/Security'

function ProtectedRoute({ children }) {
  const { user, isAdmin, loading } = useAuth()
  if (loading) return (
    <div className="flex items-center justify-center h-screen bg-sidebar-bg">
      <div className="text-center">
        <div className="text-5xl mb-4 animate-pulse">🎲</div>
        <p className="text-white/50 text-sm">Loading Admin Panel...</p>
      </div>
    </div>
  )
  if (!user || !isAdmin) return <Navigate to="/login" replace />
  return children
}

function AppRoutes() {
  const { user, isAdmin } = useAuth()
  return (
    <Routes>
      <Route path="/login" element={user && isAdmin ? <Navigate to="/" replace /> : <Login />} />
      <Route path="/" element={<ProtectedRoute><Layout /></ProtectedRoute>}>
        <Route index element={<Dashboard />} />
        <Route path="members"       element={<Members />} />
        <Route path="moderation"    element={<Moderation />} />
        <Route path="games"         element={<Games />} />
        <Route path="notifications" element={<Notifications />} />
        <Route path="config"        element={<Config />} />
        <Route path="analytics"     element={<Analytics />} />
        <Route path="database"      element={<Database />} />
        <Route path="storage"       element={<Storage />} />
        <Route path="security"      element={<Security />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </AuthProvider>
  )
}
