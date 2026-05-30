# Render Server Setup — Cousin Hub Notifications

## Step 1: Firebase Service Account বানাও
1. Firebase Console → Project Settings → Service Accounts
2. "Generate new private key" click করো
3. JSON file download হবে — ওটার content copy করো

## Step 2: Render এ Deploy করো
1. render.com এ free account বানাও
2. "New Web Service" click করো
3. GitHub এ এই `render_server` folder টা push করো
4. Render এ repo connect করো

## Step 3: Environment Variables set করো
Render dashboard → Environment এ এগুলো add করো:

| Key | Value |
|-----|-------|
| FIREBASE_PROJECT_ID | cousin-hub |
| FIREBASE_DATABASE_URL | https://cousin-hub-default-rtdb.asia-southeast1.firebasedatabase.app |
| FIREBASE_SERVICE_ACCOUNT | (service account JSON এর পুরো content) |

## Step 4: UptimeRobot দিয়ে ping করো (FREE)
1. uptimerobot.com এ free account বানাও
2. "Add New Monitor" click করো
3. Monitor Type: HTTP(s)
4. URL: তোমার Render URL (যেমন https://cousin-hub.onrender.com)
5. Monitoring Interval: Every 5 minutes
6. Save!

এটা করলে Render server সবসময় চালু থাকবে।
