# Cousin Hub — Admin Panel Web Dashboard

## Setup (YOUR JOBS)

### Step 1: Create `.env` file
Copy `.env.example` to `.env` and fill in your values:
```
VITE_FIREBASE_API_KEY=AIzaSyBSUN13LwyQhzCBWDxdxXU725P0QGu32V0
VITE_FIREBASE_AUTH_DOMAIN=cousin-hub.firebaseapp.com
VITE_FIREBASE_DATABASE_URL=https://cousin-hub-default-rtdb.asia-southeast1.firebasedatabase.app
VITE_FIREBASE_PROJECT_ID=cousin-hub
VITE_CLOUDINARY_CLOUD_NAME=dcxpakce2
VITE_CLOUDINARY_API_KEY=493964167874853
VITE_RENDER_SERVER=https://cousin-hub-server.onrender.com
VITE_ADMIN_UID=YOUR_UID_HERE
```

### Step 2: Install & Run
```bash
cd d:\cousin_hub\admin
npm install
npm run dev
```

### Step 3: Set Your UID in RTDB
Firebase Console → cousin-hub → Realtime Database:
`users/{YOUR_UID}/role = "admin"`

### Step 4: Deploy to Firebase Hosting
```bash
npm run build
firebase init hosting  # dist folder, SPA: yes
firebase deploy
```
