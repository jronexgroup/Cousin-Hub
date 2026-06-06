# Cousin Hub — Project Overview

**Cousin Hub** is a private family social app built with **Flutter** (mobile app) + **Firebase** (backend) + **React Admin Panel** (web dashboard) + **Node.js Render Server** (notification processing). It's a complete digital space for a group of cousins/family members to connect.

---

## What It Does (Features)

### Social Features
- **Chat** — Group chat with 5 rooms: Main, Gaming, Travel, Study, Foodies. Supports text, images, videos, files, voice messages, emoji picker, seen/delivered status.
- **Stories** — Post 24-hour photo/video/text stories (like Instagram).
- **Memories / Photo Album** — Shared photo album where members can upload and view family photos.
- **Voice & Video Calls** — Placeholder screen; Agora removed. Will add WebRTC later.
- **Live Location** — See where family members are on a map (using flutter_map + geolocator).
- **Events** — Create and view family events.
- **Eidi (Gift Tracker)** — Track who gave what during holidays.
- **Voting** — Create family polls/votes.
- **Members List** — See all family members, call them directly.

### Games Zone
- **Ludo King** — Single Ludo game via deep link (`url_launcher`). Creates match in Firebase, shares room code, launches Ludo King app on all devices. Host declares results after match, XP awarded, leaderboard + match history tracked.
- **More games (4 main + 4 mini)** — Coming soon. Placeholder cards on home screen.

### Other Tools
- **Family Storybook** — A collaborative story writing feature.
- **Badges** — Achievement badges for members.
- **Birthday & Expense Split** — Track birthdays and shared expenses.
- **Profile** — Edit profile, photo, nickname.

### Technical Features
- **Invite-only registration** — New users need an invite code from Firebase DB.
- **Firebase Authentication** — Email/password login.
- **Firebase Realtime Database** — All data (chats, users, calls, games, etc.) stored in realtime.
- **Firebase Cloud Messaging (FCM)** — Push notifications for new messages and calls.
- **Cloudinary** — Images, videos, and files uploaded via Cloudinary.
- **Offline Caching** — Messages, user profiles, photos, and events cached locally with SharedPreferences.
- **In-App Update System** — Checks Firebase for newer APK version and downloads/installs it in-app.
- **Admin Panel** — React web app (Vite + Tailwind) for admin to manage members, moderation, games, notifications, config, analytics, database, storage, security.

### Server (render_server/)
- **Node.js + Express + Firebase Admin SDK**
- Processes queued FCM notifications (every 8 seconds)
- Sends push notifications when new chat messages arrive
- Endpoints: `/health`, `/send-notification`, `/cleanup` (auto-deletes old stories)
- Handles invalid FCM tokens cleanup
- Designed to be deployed on Render.com with UptimeRobot monitoring

---

## Project Structure

```
cousin_hub/                  # Flutter mobile app (Android/iOS/Web/Desktop)
├── lib/
│   ├── main.dart            # App entry, Firebase init, background FCM handler
│   ├── app_theme.dart       # Colors, gradient button, input styles
│   ├── firebase_options.dart # Firebase Android config
│   ├── models/
│   │   └── message_model.dart # Chat message data model
│   ├── screens/             # 19 screen files (all features)
│   │   ├── splash_screen.dart   # Animated splash → login or home
│   │   ├── login_screen.dart    # Login + invite code entry
│   │   ├── register_screen.dart # Register with invite code
│   │   ├── home_screen.dart     # Main hub with 5 bottom tabs + feature grid
│   │   ├── chat_screen.dart     # Full chat (text, media, voice, emoji)
│   │   ├── call_screen.dart     # Call placeholder (WebRTC coming)
│   │   ├── story_screen.dart    # Instagram-style stories
│   │   ├── memory_screen.dart   # Photo album/memories
│   │   ├── photo_album_screen.dart
│   │   ├── members_screen.dart  # Member list with call buttons
│   │   ├── profile_screen.dart
│   │   ├── event_screen.dart
│   │   ├── eidi_screen.dart
│   │   ├── voting_screen.dart
│   │   ├── badges_screen.dart
│   │   ├── live_location_screen.dart
│   │   ├── family_storybook_screen.dart
│   │   ├── birthday_expense_screen.dart
│   │   └── admin_screen.dart    # Quick admin from mobile
│   │   # ── Ludo King (deep link flow) ──
│   │   # ludo_king_invite_screen.dart    — Create match, share code
│   │   # ludo_match_lobby_screen.dart    — Start Match, auto-launch, Declare Results
│   │   # ludo_declare_results_screen.dart — Host ranks players
│   │   # ludo_result_screen.dart          — Post-match results with medals/XP
│   │   # ludo_king_match_screen.dart      — Stats, recent matches, leaderboard
│   │   # ludo_leaderboard_screen.dart     — XP leaderboard
│   │   # ludo_match_history_screen.dart   — Past matches
│   ├── services/
│       ├── auth_service.dart       # Firebase auth + invite code + profile CRUD
│       ├── call_service.dart       # Initiate/accept/reject/end calls via RTDB
│       ├── notification_service.dart # FCM token + local notifications + send to user/all
│       ├── cloudinary_service.dart  # Upload images/videos/files to Cloudinary
│       ├── cache_service.dart      # SharedPreferences caching for offline
│       └── update_service.dart     # In-app APK update checker + downloader
│
├── admin/                   # React admin dashboard (Vite + Tailwind + Firebase)
│   ├── src/pages/           # Dashboard, Members, Moderation, Games, Notifications, etc.
│   ├── src/context/AuthContext.jsx
│   └── src/firebase.js
│
├── render_server/           # Node.js Express server (FCM push + cleanup)
│   ├── server.js            # Notification queue + chat triggers + REST endpoints
│   ├── server_cleanup.js    # Database cleanup script
│   └── package.json
│
├── android/ ios/ web/ windows/ macos/ linux/  # Platform projects
└── assets/icon/             # App icon
```

---

## Key Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.5+ (Dart) |
| Backend | Firebase (Auth, RTDB, FCM, Hosting) |
| Media | Cloudinary (image/video/file upload) |
| Calls | Placeholder (Agora removed, WebRTC planned) |
| Maps | flutter_map + geolocator + latlong2 |
| Ludo King | Deep link via url_launcher (launches official Ludo King app) |
| Admin | React + Vite + Tailwind + Firebase Web SDK |
| Server | Node.js + Express + Firebase Admin SDK |
| Notifications | Firebase Cloud Messaging + flutter_local_notifications |

---

## Authentication Flow
1. User enters an **invite code** (validated against Firebase RTDB `inviteCodes/`)
2. If valid, proceeds to registration (name, nickname, relation, email, password)
3. After registration, user data stored in `users/{uid}` with role `member`
4. Admin sets role to `admin` manually in Firebase console

## Data Storage (Firebase Realtime Database)
- `users/{uid}` — Profile info, FCM token
- `chats/{group}` — Messages in each chat room
- `calls/{uid}` — Incoming call data
- `photos/` — Photo album entries
- `stories/` — Story posts (auto-deleted after 24h by render server)
- `events/` — Family events
- `notifications/` — Queued FCM pushes
- `inviteCodes/{code}` — Valid invite codes
- `ludoKingMatches/{matchId}` — Ludo match state (players, deepLink, status)
- `ludoKingResults/{matchId}` — Match results (ranks, XP earned)
- `ludoKingInvites/{uid}/{matchId}` — Pending Ludo King invites
- `appConfig/` — Update info (latestVersion, updateUrl, etc.)

## Important Notes
- Agora removed (app was 254 MB); calls replaced with placeholder for future WebRTC.
- Cloudinary keys are hardcoded in `cloudinary_service.dart`
- Firebase Admin private key is embedded in `render_server/server.js` (security concern)
- The app is **Android-only** currently (Firebase options only configured for Android)
- Ludo King uses deep link `https://lk.gggred.com/?rmc=CODE&gt=0&po=0` to launch official app
- Version: 1.0.0+1
