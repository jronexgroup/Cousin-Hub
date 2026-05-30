import { useState } from 'react'
import { useAuth } from '../context/AuthContext'
import { Eye, EyeOff, LogIn, AlertCircle } from 'lucide-react'

export default function Login() {
  const { login, error, setError } = useAuth()
  const [email,    setEmail]    = useState('')
  const [password, setPassword] = useState('')
  const [show,     setShow]     = useState(false)
  const [loading,  setLoading]  = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try { await login(email, password) }
    catch { /* error handled in context */ }
    finally { setLoading(false) }
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden"
      style={{ background: 'radial-gradient(ellipse at 50% 0%, #2D1B69 0%, #0F0A1E 60%)' }}>

      {/* Decorative blobs */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 rounded-full opacity-10 blur-3xl pointer-events-none"
        style={{ background: '#7C3AED' }} />
      <div className="absolute bottom-1/4 right-1/4 w-72 h-72 rounded-full opacity-8 blur-3xl pointer-events-none"
        style={{ background: '#60A5FA' }} />

      <div className="relative z-10 w-full max-w-sm px-4">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="w-20 h-20 mx-auto rounded-3xl flex items-center justify-center text-4xl mb-4 shadow-2xl"
            style={{ background: 'linear-gradient(135deg, #7C3AED, #60A5FA)', boxShadow: '0 0 40px rgba(124,58,237,0.4)' }}>
            🎲
          </div>
          <h1 className="text-white font-extrabold text-2xl mb-1">Cousin Hub</h1>
          <p className="text-purple-400/60 text-sm font-medium tracking-wider uppercase">Admin Panel</p>
        </div>

        {/* Card */}
        <div className="rounded-3xl p-8 border border-white/10 shadow-2xl"
          style={{ background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(20px)' }}>
          <h2 className="text-white font-bold text-lg mb-6 text-center">Welcome back 👋</h2>

          {error && (
            <div className="flex items-center gap-2 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3 mb-5">
              <AlertCircle size={14} className="text-red-400 flex-shrink-0" />
              <p className="text-red-400 text-sm">{error}</p>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-white/50 text-xs font-semibold uppercase tracking-wider mb-2">Email</label>
              <input
                type="email" value={email} onChange={e => { setEmail(e.target.value); setError('') }}
                placeholder="admin@example.com" required
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-white/50 text-xs font-semibold uppercase tracking-wider mb-2">Password</label>
              <div className="relative">
                <input
                  type={show ? 'text' : 'password'} value={password}
                  onChange={e => { setPassword(e.target.value); setError('') }}
                  placeholder="••••••••" required
                  className="input-field pr-10"
                />
                <button type="button" onClick={() => setShow(!show)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/70 transition-colors">
                  {show ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            <button type="submit" disabled={loading}
              className="w-full py-3 rounded-xl font-bold text-white text-sm flex items-center justify-center gap-2
                         transition-all duration-200 mt-2 disabled:opacity-60"
              style={{ background: loading ? '#5B21B6' : 'linear-gradient(135deg, #7C3AED, #60A5FA)',
                       boxShadow: loading ? 'none' : '0 0 20px rgba(124,58,237,0.35)' }}>
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <LogIn size={16} />
              )}
              {loading ? 'Signing in...' : 'Sign In as Admin'}
            </button>
          </form>
        </div>

        <p className="text-center text-white/20 text-xs mt-6">
          Cousin Hub Admin • JroNex 2026
        </p>
      </div>
    </div>
  )
}
