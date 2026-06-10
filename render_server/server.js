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

// ── Pass The Bomb Game Engine ──────────────────────────────────

const bombTimers = {};

// Recover active games on server restart
async function recoverBombTimers() {
  const snap = await db.ref('passBombRooms').once('value');
  if (!snap.exists()) return;
  snap.forEach(child => {
    const room = child.val();
    const roomId = child.key;
    if (room.status === 'playing') {
      if (room.explosionAt && room.explosionAt > Date.now()) {
        const remaining = room.explosionAt - Date.now();
        bombTimers[roomId] = setTimeout(() => explode(roomId), Math.max(remaining, 1000));
        console.log(`🔁 Recovered bomb for ${roomId} (${Math.round(remaining/1000)}s)`);
      } else {
        console.log(`⚡ Missed timer — exploding ${roomId} immediately`);
        explode(roomId);
      }
    } else if (room.status === 'countdown') {
      setTimeout(() => startRound(roomId), 3000);
    }
  });
}

// Add createdAt on room creation
db.ref('passBombRooms').on('child_added', async (snap) => {
  const room = snap.val();
  if (!room || room.createdAt) return;
  await snap.ref.child('createdAt').set(Date.now());
});

// Listen for countdown → start round after 3s
db.ref('passBombRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'countdown') return;
  setTimeout(() => startRound(roomId), 3000);
});

// Listen for bomb holder changes → set cooldown
db.ref('passBombRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'playing' || !room.currentBombHolder) return;
  const prev = snap.previous.val();
  if (prev && prev.currentBombHolder === room.currentBombHolder) return;

  const cooldown = Math.floor(Math.random() * 5000) + 1000;
  await db.ref(`passBombRooms/${roomId}/cooldownUntil`).set(Date.now() + cooldown);
  console.log(`⏳ ${Math.round(cooldown/1000)}s cooldown for ${room.currentBombHolder} in ${roomId}`);
});

async function startRound(roomId) {
  const snap = await db.ref(`passBombRooms/${roomId}`).once('value');
  const room = snap.val();
  if (!room || room.status !== 'countdown') return;

  const players = room.players || {};
  const aliveUids = Object.keys(players).filter(uid => players[uid]?.alive !== false);
  if (aliveUids.length <= 1) return endGame(roomId, aliveUids[0] || null);

  const holder = aliveUids[Math.floor(Math.random() * aliveUids.length)];
  const delay = explodeDelay(aliveUids.length);
  const round = (room.round || 0) + 1;

  await db.ref(`passBombRooms/${roomId}`).update({
    currentBombHolder: holder,
    status: 'playing', round, roundStartAt: Date.now(),
    explosionAt: Date.now() + delay, bombState: 'held',
  });

  if (bombTimers[roomId]) clearTimeout(bombTimers[roomId]);
  bombTimers[roomId] = setTimeout(() => explode(roomId), delay);
  console.log(`💣 Round ${round} in ${roomId} — ${holder} (${Math.round(delay/1000)}s)`);
}

function explodeDelay(n) {
  const [min, max] =
    n >= 12 ? [20000, 60000] : n >= 8 ? [15000, 45000] :
    n >= 5  ? [10000, 30000] : n >= 3 ? [8000, 20000] : [8000, 15000];
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function explode(roomId) {
  const snap = await db.ref(`passBombRooms/${roomId}`).once('value');
  const room = snap.val();
  if (!room || room.status !== 'playing' || !room.currentBombHolder) return;

  const holder = room.currentBombHolder;
  const players = room.players || {};
  const eliminated = Object.values(players).filter(p => p?.alive === false).length + 1;

  await db.ref(`passBombRooms/${roomId}`).update({
    bombState: 'exploded',
    [`players/${holder}/alive`]: false,
    [`players/${holder}/eliminationOrder`]: eliminated,
  });
  console.log(`💥 ${holder} ELIMINATED #${eliminated} in ${roomId}`);

  setTimeout(async () => {
    const s = await db.ref(`passBombRooms/${roomId}`).once('value');
    const r = s.val();
    if (!r || r.status !== 'playing') return;
    const alive = Object.keys(r.players || {}).filter(u => r.players[u]?.alive !== false);
    alive.length <= 1 ? endGame(roomId, alive[0] || null) :
      db.ref(`passBombRooms/${roomId}/status`).set('countdown');
  }, 3000);
}

async function endGame(roomId, winnerUid) {
  await db.ref(`passBombRooms/${roomId}`).update({ status: 'finished', winner: winnerUid || '' });
  if (bombTimers[roomId]) clearTimeout(bombTimers[roomId]);
  delete bombTimers[roomId];
  console.log(`🏆 Winner ${winnerUid} in ${roomId}`);
  setTimeout(() => db.ref(`passBombRooms/${roomId}`).remove(), 2 * 60 * 60 * 1000);
}

// Start recovery
recoverBombTimers();

// ── Truth or Dare Live Engine ─────────────────────────────────

function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function alivePlayers(room) {
  return Object.keys(room.players || {}).filter(u => room.players[u]?.online !== false);
}

// On game start → pick random starter
db.ref('truthOrDareRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  const prev = snap.previous.val();
  if (!room || room.status !== 'playing' || prev?.status === 'playing') return;

  const alive = alivePlayers(room);
  if (alive.length === 0) return;

  const starter = pickRandom(alive);
  await snap.ref.child('currentSpinner').set(starter);
  await snap.ref.child('turnPhase').set('spin');
  await snap.ref.child('selectedPlayer').set(null);

  // Post system message
  const name = room.players?.[starter]?.name || 'Someone';
  const msgRef = db.ref(`chats/truthOrDare_${roomId}`).push();
  await msgRef.set({
    type: 'system', text: `🎯 ${name} starts the game!`, senderName: name,
    timestamp: Date.now(),
  });
  console.log(`🎯 Truth or Dare started in ${roomId} — starter: ${starter}`);
});

// On spinRequest → pick random target
db.ref('truthOrDareRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'playing') return;
  const req = room.spinRequest;
  if (!req?.by) return;

  const by = room.players?.[req.by];
  if (!by || by.online === false) {
    await snap.ref.child('spinRequest').remove();
    return;
  }

  const alive = alivePlayers(room).filter(u => u !== req.by);
  if (alive.length === 0) {
    await snap.ref.child('spinRequest').remove();
    return;
  }

  const target = pickRandom(alive);
  await snap.ref.child('selectedPlayer').set(target);
  await snap.ref.child('turnPhase').set('choose');
  await snap.ref.child('spinRequest').remove();

  const spinnerName = by.name || 'Someone';
  const targetName = room.players?.[target]?.name || 'Someone';
  const msgRef = db.ref(`chats/truthOrDare_${roomId}`).push();
  await msgRef.set({
    type: 'system', text: `🍾 ${spinnerName} spun the bottle → ${targetName}!`,
    senderName: spinnerName, timestamp: Date.now(),
  });
  console.log(`🍾 ${spinnerName} → ${targetName} in ${roomId}`);
});

// On player removal (online=false) → handle spinner/selected exit
db.ref('truthOrDareRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'playing') return;

  // Check if any player went offline recently
  const prev = snap.previous.val();
  if (!prev) return;

  for (const uid of Object.keys(room.players || {})) {
    const wasOnline = prev.players?.[uid]?.online !== false;
    const nowOnline = room.players?.[uid]?.online !== false;
    if (wasOnline && !nowOnline) {
      const name = room.players?.[uid]?.name || 'Someone';
      const msgRef = db.ref(`chats/truthOrDare_${roomId}`).push();
      await msgRef.set({
        type: 'system', text: `🚪 ${name} left the game.`,
        senderName: name, timestamp: Date.now(),
      });

      const alive = alivePlayers(room);

      // If spinner left → reassign
      if (room.currentSpinner === uid) {
        if (alive.length <= 1) return endTruthOrDare(roomId, room);

        const newSpinner = pickRandom(alive);
        await snap.ref.child('currentSpinner').set(newSpinner);
        await snap.ref.child('turnPhase').set('spin');
        await snap.ref.child('selectedPlayer').set(null);
        const newName = room.players?.[newSpinner]?.name || 'Someone';
        const m2 = db.ref(`chats/truthOrDare_${roomId}`).push();
        await m2.set({
          type: 'system', text: `${name} left. ${newName} now controls the bottle.`,
          senderName: name, timestamp: Date.now(),
        });
        console.log(`🔄 Spinner ${uid} left in ${roomId} → reassigned to ${newSpinner}`);
      }

      // If selected player left → cancel round
      if (room.selectedPlayer === uid && alive.length > 1) {
        await snap.ref.child('selectedPlayer').set(null);
        await snap.ref.child('turnPhase').set('spin');
        const m3 = db.ref(`chats/truthOrDare_${roomId}`).push();
        await m3.set({
          type: 'system', text: `${name} left. Round cancelled — spin again!`,
          senderName: name, timestamp: Date.now(),
        });
      }

      // If ≤2 alive and someone leaves → check for match end
      if (alive.length <= 2) {
        await db.ref(`truthOrDareRooms/${roomId}/exitRequest`).set({
          uid: uid, name: name, timestamp: Date.now(),
        });
      }
    }
  }
});

// On exitRequest from last player (≤2 alive)
db.ref('truthOrDareRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'playing') return;
  const er = room.exitRequest;
  if (!er?.confirmed) return;

  await snap.ref.child('exitRequest').remove();
  await endTruthOrDare(roomId, room);
});

async function endTruthOrDare(roomId, room) {
  const updates = { status: 'finished', endedAt: Date.now() };
  await db.ref(`truthOrDareRooms/${roomId}`).update(updates);

  const msgRef = db.ref(`chats/truthOrDare_${roomId}`).push();
  await msgRef.set({
    type: 'system', text: 'Match ended. Session saved.',
    senderName: '', timestamp: Date.now(),
  });
  console.log(`🎭 Truth or Dare ended in ${roomId}`);

  // Auto-cleanup after 24h
  setTimeout(() => db.ref(`truthOrDareRooms/${roomId}`).remove(), 24 * 60 * 60 * 1000);
}

// ── Pass The Card Game Engine ────────────────────────────────

const ptcTimers = {};
const PTC_TURN_TIME = 10000;
const PTC_SELECT_TIME = 15000;
const PTC_CARD_TYPES = [0,0,0,0, 1,1,1,1, 2,2,2,2, 3,3,3,3];

function shuffleDeck() {
  const deck = [...PTC_CARD_TYPES];
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

function nextClockwise(players, currentUid) {
  const uids = Object.keys(players).sort((a, b) => (players[a].position || 0) - (players[b].position || 0));
  const idx = uids.indexOf(currentUid);
  return uids[(idx + 1) % uids.length];
}

async function recoverPtcTimers() {
  const snap = await db.ref('passTheCardRooms').once('value');
  if (!snap.exists()) return;
  snap.forEach(child => {
    const room = child.val();
    const roomId = child.key;
    if (room.status === 'selecting' && room.selectionEndAt) {
      const remaining = room.selectionEndAt - Date.now();
      if (remaining > 0) {
        ptcTimers[roomId] = setTimeout(() => autoAssignPtcCards(roomId), remaining);
        console.log(`🔁 Recovered PTC selection ${roomId} (${Math.round(remaining/1000)}s)`);
      } else {
        autoAssignPtcCards(roomId);
      }
    } else if (room.status === 'playing' && room.turnEndAt) {
      const remaining = room.turnEndAt - Date.now();
      if (remaining > 0) {
        ptcTimers[`turn_${roomId}`] = setTimeout(() => afkPtcPass(roomId), remaining);
        console.log(`🔁 Recovered PTC turn ${roomId} (${Math.round(remaining/1000)}s)`);
      } else {
        afkPtcPass(roomId);
      }
    }
  });
}

db.ref('passTheCardRooms').on('child_added', async (snap) => {
  const room = snap.val();
  if (!room || room.createdAt) return;
  await snap.ref.child('createdAt').set(Date.now());
});

db.ref('passTheCardRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  const prev = snap.previous.val();
  if (!room || room.status !== 'selecting' || prev?.status === 'selecting') return;

  const players = room.players || {};
  const uids = Object.keys(players);
  const posUpdates = {};
  uids.forEach((uid, i) => { posUpdates[`players/${uid}/position`] = i; });
  posUpdates.selectionEndAt = Date.now() + PTC_SELECT_TIME;
  posUpdates.turnsPlayed = 0;
  posUpdates.cardsPassed = 0;

  const deck = shuffleDeck();
  deck.forEach((typeId, i) => { posUpdates[`cardPool/${i}`] = typeId; });

  await snap.ref.update(posUpdates);

  if (ptcTimers[roomId]) clearTimeout(ptcTimers[roomId]);
  ptcTimers[roomId] = setTimeout(() => autoAssignPtcCards(roomId), PTC_SELECT_TIME);
  console.log(`🃏 PTC selecting in ${roomId} — 15s`);
});

db.ref('passTheCardRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'selecting') return;
  const sel = room.selectedPositions || {};
  const players = room.players || {};
  const allSelected = Object.keys(players).length >= 4 &&
    Object.keys(players).every(uid => Array.isArray(sel[uid]) && sel[uid].length >= 4);
  if (!allSelected) return;

  if (ptcTimers[roomId]) clearTimeout(ptcTimers[roomId]);
  delete ptcTimers[roomId];
  assignPtcCards(roomId, room);
});

async function autoAssignPtcCards(roomId) {
  const snap = await db.ref(`passTheCardRooms/${roomId}`).once('value');
  const room = snap.val();
  if (!room || room.status !== 'selecting') return;
  delete ptcTimers[roomId];

  const sel = room.selectedPositions || {};
  const players = room.players || {};
  const allPositions = new Set(Array.from({length: 16}, (_, i) => i));

  for (const uid of Object.keys(players)) {
    if (Array.isArray(sel[uid])) sel[uid].forEach(p => allPositions.delete(p));
  }

  const remaining = Array.from(allPositions);
  for (const uid of Object.keys(players)) {
    if (!Array.isArray(sel[uid]) || sel[uid].length < 4) {
      const needed = 4 - (sel[uid]?.length || 0);
      const picks = remaining.splice(0, needed);
      if (!sel[uid]) sel[uid] = [];
      sel[uid].push(...picks);
      await db.ref(`passTheCardRooms/${roomId}/selectedPositions/${uid}`).set(sel[uid]);
    }
  }

  assignPtcCards(roomId, await db.ref(`passTheCardRooms/${roomId}`).once('value'));
}

async function assignPtcCards(roomId, snapOrRoom) {
  const snap = snapOrRoom.val ? snapOrRoom : await db.ref(`passTheCardRooms/${roomId}`).once('value');
  const room = snap.val();
  if (!room || room.status !== 'selecting') return;

  const sel = room.selectedPositions || {};
  const players = room.players || {};
  const pool = room.cardPool;
  if (!pool) return;

  const updates = {};
  for (const uid of Object.keys(players)) {
    const positions = sel[uid];
    if (!Array.isArray(positions) || positions.length < 4) continue;
    const hand = positions.map(pos => pool[pos]);
    updates[`players/${uid}/hand`] = hand;
  }

  updates.status = 'playing';
  updates.currentTurn = room.hostUid;
  updates.turnEndAt = Date.now() + PTC_TURN_TIME;
  updates.startedAt = Date.now();

  await db.ref(`passTheCardRooms/${roomId}`).update(updates);

  if (ptcTimers[`turn_${roomId}`]) clearTimeout(ptcTimers[`turn_${roomId}`]);
  ptcTimers[`turn_${roomId}`] = setTimeout(() => afkPtcPass(roomId), PTC_TURN_TIME);
  console.log(`🃏 PTC playing ${roomId} — turn: ${room.hostUid}`);
}

db.ref('passTheCardRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'playing') return;
  const pass = room.passAction;
  if (!pass || pass.cardIndex === undefined) return;

  const fromUid = room.currentTurn;
  const players = room.players || {};
  const fromHand = players[fromUid]?.hand;
  if (!Array.isArray(fromHand) || pass.cardIndex < 0 || pass.cardIndex >= fromHand.length) {
    await snap.ref.child('passAction').remove();
    return;
  }

  const toUid = nextClockwise(players, fromUid);
  const toHand = players[toUid]?.hand || [];
  const card = fromHand[pass.cardIndex];

  const newFromHand = [...fromHand];
  newFromHand.splice(pass.cardIndex, 1);
  const newToHand = [...toHand, card];

  const updates = {};
  updates[`players/${fromUid}/hand`] = newFromHand;
  updates[`players/${toUid}/hand`] = newToHand;
  updates.currentTurn = toUid;
  updates.turnEndAt = Date.now() + PTC_TURN_TIME;
  updates.turnsPlayed = (room.turnsPlayed || 0) + 1;
  updates.cardsPassed = (room.cardsPassed || 0) + 1;
  updates.recentPass = { fromUid, toUid, card, timestamp: Date.now() };
  updates.passAction = null;

  await db.ref(`passTheCardRooms/${roomId}`).update(updates);

  if (ptcTimers[`turn_${roomId}`]) clearTimeout(ptcTimers[`turn_${roomId}`]);
  ptcTimers[`turn_${roomId}`] = setTimeout(() => afkPtcPass(roomId), PTC_TURN_TIME);
  console.log(`🃏 ${fromUid}→${toUid} 🃏 in ${roomId} (turn ${room.turnsPlayed + 1})`);
});

db.ref('passTheCardRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status !== 'playing') return;
  const revealBy = room.revealRequest;
  if (!revealBy) return;

  const hand = room.players?.[revealBy]?.hand;
  if (!Array.isArray(hand) || hand.length !== 4 || !hand.every(c => c === hand[0])) {
    await snap.ref.update({ revealRequest: null, revealResult: 'invalid' });
    console.log(`❌ Invalid reveal by ${revealBy} in ${roomId}`);
    return;
  }

  if (ptcTimers[`turn_${roomId}`]) clearTimeout(ptcTimers[`turn_${roomId}`]);
  delete ptcTimers[`turn_${roomId}`];

  await snap.ref.update({
    winner: revealBy,
    status: 'finished',
    revealRequest: null,
    revealResult: 'valid',
    endedAt: Date.now(),
  });
  console.log(`🏆 PTC winner ${revealBy} in ${roomId}`);

  setTimeout(() => db.ref(`passTheCardRooms/${roomId}`).remove(), 2 * 60 * 60 * 1000);
});

async function afkPtcPass(roomId) {
  const snap = await db.ref(`passTheCardRooms/${roomId}`).once('value');
  const room = snap.val();
  if (!room || room.status !== 'playing') return;
  delete ptcTimers[`turn_${roomId}`];

  const fromUid = room.currentTurn;
  const fromHand = room.players?.[fromUid]?.hand;
  if (!Array.isArray(fromHand) || fromHand.length === 0) return;

  const randIdx = Math.floor(Math.random() * fromHand.length);
  const card = fromHand[randIdx];
  const players = room.players || {};
  const toUid = nextClockwise(players, fromUid);
  const toHand = players[toUid]?.hand || [];

  const newFromHand = [...fromHand];
  newFromHand.splice(randIdx, 1);
  const newToHand = [...toHand, card];

  const updates = {};
  updates[`players/${fromUid}/hand`] = newFromHand;
  updates[`players/${toUid}/hand`] = newToHand;
  updates.currentTurn = toUid;
  updates.turnEndAt = Date.now() + PTC_TURN_TIME;
  updates.turnsPlayed = (room.turnsPlayed || 0) + 1;
  updates.cardsPassed = (room.cardsPassed || 0) + 1;
  updates.recentPass = { fromUid, toUid, card, timestamp: Date.now(), afk: true };
  updates.afkMessage = fromUid;

  await db.ref(`passTheCardRooms/${roomId}`).update(updates);

  ptcTimers[`turn_${roomId}`] = setTimeout(() => afkPtcPass(roomId), PTC_TURN_TIME);
  console.log(`⏰ AFK ${fromUid} auto-passed in ${roomId}`);
}

// Player removed → end game
db.ref('passTheCardRooms').on('child_changed', async (snap) => {
  const room = snap.val(), roomId = snap.key;
  if (!room || room.status === 'finished') return;
  const players = room.players || {};
  const uids = Object.keys(players);
  if (uids.length < 4) {
    if (ptcTimers[roomId]) clearTimeout(ptcTimers[roomId]);
    if (ptcTimers[`turn_${roomId}`]) clearTimeout(ptcTimers[`turn_${roomId}`]);
    delete ptcTimers[roomId];
    delete ptcTimers[`turn_${roomId}`];
    await db.ref(`passTheCardRooms/${roomId}`).update({
      winner: null, status: 'finished', endedAt: Date.now(),
    });
    console.log(`🚪 PTC cancelled ${roomId} — player left`);
    setTimeout(() => db.ref(`passTheCardRooms/${roomId}`).remove(), 2 * 60 * 60 * 1000);
  }
});

recoverPtcTimers();

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
