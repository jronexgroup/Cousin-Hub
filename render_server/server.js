const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const app = express();

// Allow requests from Admin Panel
app.use(cors({
  origin: ['https://cousin-hub.web.app', 'http://localhost:3000', 'http://localhost:3001', 'http://localhost:3002'],
  methods: ['GET', 'POST'],
  credentials: true
}));

app.use(express.json());

// Firebase Admin initialize
const serviceAccount = {
  type: "service_account",
  project_id: "cousin-hub",
  private_key_id: "6ee9ff1d965b50d024a2f80f658302b6543a77d3",
  private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDHNS2dgFRcgZO4\ncmSMJ2I+ARRsC0+JdxQGWirZNlwBNMWWepPWC1WcGTmNJAIqhmfAPMKH2upa33Cj\nstMSgF9eXWUuIkTNCfaSRQLX8a9HlpQGfkVkHYiCPWYNgQDpMS6WOPWdjNUJ6H9p\nraDaGOJqot3hCPd3522ZYs8CmmMA7gfpkxLgL5YDpBu7NmKRqidrdfba6+4j4xF7\nQ4LHUZ2kWKF4vudIelvER8jJYqu+eol2uBzkX/IgRdkEibBTHIGuPJHwN1grmCHj\nb3g/93/ggrTFD7QsWQTHNGrdJ3juGdbkaAL3e3czMOTVSoqY+tVt1TsoJPhXDlkr\nzOiVYMzVAgMBAAECggEAHzrWwx+ceiElSbADU9aTyAEu1K5kQnp81O8bUxC61USS\n6l+eoBqISg/JTjd0MHsANmrAG4DGJ0dqtvsgrICcEuTk6Rndu+BBO9aeVsDQuBIi\n9C6lDcg0f6iFAH52KFi5wzq8RL4QovxER0q9Uhu/GTUdwDsB4tYRAFA1gGS4OyuP\nGwFXkoqqh0Zl/7r9lzX1C5Gi6+r0d8r/LD1w2UoJE4Zsocq62JrAGFGxMiBFUWMK\nNSDMx4cQPs/BIyKHadw3FlX2sWBJTiYZpmApa+syN9p/Z13JF9+wH7vuSlHQ54+L\nmeN/6nGc045dV8GvhodYn+uYWjiz3Ih9zfgnG6JSIQKBgQDiKmy7cWUR1wLxoM7H\np+KgIhlss2QLrVcAEXxSYPcVCQie/JmcR79Hp+URVa5547PxL3AOhvks/MEeiuB9\nSZ7Bk3AAxzWS76jGaFFwFCYczn8Vf80rwaxthhDlrEsn0h6vQZC5dHMbqabutATH\nsuCZlvr+eLgccXdw/vo/0fxBoQKBgQDhfGMK9dCTVmw/QqoAAe2+hrIPY4CGS+DU\nQW3Pj8yWNa1uSafPKjohPxf1xE9jukNYDsuTJNA6sUNcX75T1h23eEQ1u4R0LPTJ\nuBSjHQh+NaiFOtPapNj63Fl4cJN612/EWeBRbjbNPYA/GGuPIQ75TIWs8hNv7uyn\nypo7yHimtQKBgHl05R2ooOl6uWb/v+xy2X67sUGx+QlYVn9/5G7tCePvDQUsjGXk\nFfIqVRcBF4j34rukiR4UGB6zwhZf6H0AG1TDlAOm97toHxAmF44EFA+mSZNHJezY\nvnu24r4kz9ubuMTPhiRCSErTygUpAeQoyPtSnIoqVF1aBhXVqJi7cSfhAoGAbfDK\nEcP86HnQ2Z9VaB+Incbq9pnbRp+khZlJQ1Snue1+HDIJgfbi1OcAdbI7yzI8N6kv\nFRVz+coIP/fmwtW5M4WOLGy7jjGFQP1iAo3bYD4lZqBiP071BIt/jDvHjLOSKThx\nKQMF8Vg1OY5ckzLZLDBlVQfK9l6WQNGGFfQO76kCgYBUGj3jgw5CDLqtUGF73Xq1\nJtVrc76P0q+1TSOVlYtB4i01LZ+g4MNj2p60FxQTbuYDk1CdRevbUCDICjHTwNT4\nC16sSpRl5W5JtsMiHfy+GrcGPLEKq3VscviK0OX2ZppBA6U1/YEg2weMemW8ZcV5\nk+mEYO90knOwiZh8P9ypXw==\n-----END PRIVATE KEY-----\n",
  client_email: "firebase-adminsdk-fbsvc@cousin-hub.iam.gserviceaccount.com",
  client_id: "102078372491682917866",
  auth_uri: "https://accounts.google.com/o/oauth2/auth",
  token_uri: "https://oauth2.googleapis.com/token",
  auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
  client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40cousin-hub.iam.gserviceaccount.com"
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://cousin-hub-default-rtdb.asia-southeast1.firebasedatabase.app',
});

const db = admin.database();
const messaging = admin.messaging();
console.log('✅ Firebase connected');

// ── Endpoints for Admin Panel ────────────────────────────────────────────────

// Health check
app.get('/health', (req, res) => {
  res.json({ status: '🚀 Server Online', time: new Date().toISOString() });
});

// Send FCM to a single token (POST)
app.post('/send-notification', async (req, res) => {
  const { toToken, title, body } = req.body;
  if (!toToken || !title || !body) {
    return res.status(400).json({ error: 'Missing parameters' });
  }

  const success = await sendFCM(toToken, title, body);
  if (success) {
    res.json({ success: true });
  } else {
    res.status(500).json({ error: 'Failed to send notification' });
  }
});

// Database Cleanup (POST)
app.post('/cleanup', async (req, res) => {
  try {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const snap = await db.ref('stories').orderByChild('timestamp').endAt(cutoff).once('value');
    if (!snap.exists()) return res.json({ message: 'Nothing to clean' });

    let count = 0;
    snap.forEach(child => {
      child.ref.remove();
      count++;
    });
    res.json({ success: true, removed: count });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── FCM Functions ───────────────────────────────────────────────────────────

async function sendFCM(token, title, body, data = {}) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'cousin_hub_channel' }
      }
    });
    return true;
  } catch (e) {
    console.error('FCM error:', e.message);
    if (e.code === 'messaging/invalid-registration-token' ||
        e.code === 'messaging/registration-token-not-registered') {
      await db.ref('users').orderByChild('fcmToken').equalTo(token).once('value', snap => {
        snap.forEach(child => child.ref.child('fcmToken').remove());
      });
    }
    return false;
  }
}

async function sendToAll(title, body, excludeUid = null) {
  try {
    const snap = await db.ref('users').once('value');
    if (!snap.exists()) return;
    const users = snap.val();
    const promises = [];
    for (const [uid, user] of Object.entries(users)) {
      if (uid === excludeUid) continue;
      if (user.fcmToken) {
        promises.push(sendFCM(user.fcmToken, title, body));
      }
    }
    await Promise.all(promises);
  } catch (e) {
    console.error('sendToAll error:', e.message);
  }
}

// Background Task: Process queued notifications
async function processNotifications() {
  try {
    const snap = await db.ref('notifications')
      .orderByChild('sent').equalTo(false).limitToFirst(20).once('value');
    if (!snap.exists()) return;

    const updates = {};
    const promises = [];

    snap.forEach(child => {
      const n = child.val();
      const key = child.key;
      updates[`notifications/${key}/sent`] = true;
      updates[`notifications/${key}/sentAt`] = Date.now();

      if (n.toAll) {
        promises.push(sendToAll(n.title, n.body, n.fromUid));
      } else if (n.toToken) {
        promises.push(sendFCM(n.toToken, n.title, n.body));
      }
    });

    await Promise.all(promises);
    if (Object.keys(updates).length > 0) await db.ref().update(updates);
  } catch (e) {
    console.error('processNotifications error:', e.message);
  }
}

setInterval(processNotifications, 8000);

// ── Real-time Triggers (Chat, Events, etc.) ──────────────────────────────────

let lastChatKey = null;
db.ref('chats/main').orderByChild('timestamp').limitToLast(1).on('child_added', async snap => {
  if (snap.key === lastChatKey) return;
  lastChatKey = snap.key;
  const msg = snap.val();
  if (!msg || !msg.text || !msg.senderName) return;
  await sendToAll(`💬 ${msg.senderName}`, msg.text.substring(0, 60), msg.senderUid);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
