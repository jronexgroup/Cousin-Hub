import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'
import { getDatabase } from 'firebase/database'

const firebaseConfig = {
  apiKey:            import.meta.env.VITE_FIREBASE_API_KEY     || 'AIzaSyBSUN13LwyQhzCBWDxdxXU725P0QGu32V0',
  authDomain:        import.meta.env.VITE_FIREBASE_AUTH_DOMAIN  || 'cousin-hub.firebaseapp.com',
  databaseURL:       import.meta.env.VITE_FIREBASE_DATABASE_URL || 'https://cousin-hub-default-rtdb.asia-southeast1.firebasedatabase.app',
  projectId:         import.meta.env.VITE_FIREBASE_PROJECT_ID   || 'cousin-hub',
  storageBucket:     'cousin-hub.firebasestorage.app',
  messagingSenderId: '418854126363',
  appId:             '1:418854126363:android:270808bee8b7bb7bb489be',
}

const app  = initializeApp(firebaseConfig)
export const auth = getAuth(app)
export const db   = getDatabase(app)
export default app
