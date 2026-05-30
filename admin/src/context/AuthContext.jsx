import { createContext, useContext, useEffect, useState } from 'react'
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth'
import { ref, get } from 'firebase/database'
import { auth, db } from '../firebase'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user,    setUser]    = useState(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error,   setError]   = useState('')

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (u) {
        // Check admin role in RTDB
        try {
          const snap = await get(ref(db, `users/${u.uid}/role`))
          if (snap.exists() && snap.val() === 'admin') {
            setUser(u); setIsAdmin(true)
          } else {
            await signOut(auth)
            setUser(null); setIsAdmin(false)
            setError('Not authorized as admin')
          }
        } catch {
          await signOut(auth)
          setUser(null); setIsAdmin(false)
        }
      } else {
        setUser(null); setIsAdmin(false)
      }
      setLoading(false)
    })
    return unsub
  }, [])

  const login = async (email, password) => {
    setError('')
    try {
      await signInWithEmailAndPassword(auth, email, password)
    } catch (e) {
      const msgs = {
        'auth/user-not-found':   'No account with this email',
        'auth/wrong-password':   'Wrong password',
        'auth/invalid-credential': 'Wrong email or password',
        'auth/too-many-requests': 'Too many attempts. Try again later.',
      }
      setError(msgs[e.code] || e.message)
      throw e
    }
  }

  const logout = () => signOut(auth)

  return (
    <AuthContext.Provider value={{ user, isAdmin, loading, error, setError, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
