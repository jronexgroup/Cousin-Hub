// ═══════════════════════════════════════════════════════
// Add this to your Render server (cousin-hub-server)
// এটা auto-cleanup করবে — storage কখনো full হবে না
// ═══════════════════════════════════════════════════════

const admin = require('firebase-admin');
const db = admin.database();

// ── 1. Old chat messages delete (30 days old) ──────────
function cleanOldMessages() {
  const cutoff = Date.now() - (30 * 24 * 60 * 60 * 1000);
  const groups = ['main', 'gaming', 'travel', 'study', 'foodies'];
  
  groups.forEach(async (group) => {
    const snap = await db.ref(`chats/${group}`)
      .orderByChild('timestamp')
      .endAt(cutoff)
      .once('value');
    
    if (snap.exists()) {
      const updates = {};
      snap.forEach(child => { updates[child.key] = null; });
      await db.ref(`chats/${group}`).update(updates);
      console.log(`🧹 Cleaned ${Object.keys(updates).length} old messages from ${group}`);
    }
  });
}

// ── 2. Expired stories delete (24 hours) ───────────────
function cleanExpiredStories() {
  const cutoff = Date.now() - (24 * 60 * 60 * 1000);
  
  db.ref('stories')
    .orderByChild('timestamp')
    .endAt(cutoff)
    .once('value', snap => {
      if (!snap.exists()) return;
      const updates = {};
      let count = 0;
      snap.forEach(child => { updates[child.key] = null; count++; });
      db.ref('stories').update(updates);
      console.log(`🧹 Deleted ${count} expired stories`);
    });
}

// ── 3. Ended race/game rooms cleanup ───────────────────
function cleanFinishedGames() {
  const cutoff = Date.now() - (2 * 60 * 60 * 1000); // 2 hours
  
  ['raceRooms', 'ludoRooms', 'gameRooms'].forEach(async (ref) => {
    const snap = await db.ref(ref)
      .orderByChild('createdAt')
      .endAt(cutoff)
      .once('value');
    
    if (snap.exists()) {
      const updates = {};
      snap.forEach(child => { updates[child.key] = null; });
      await db.ref(ref).update(updates);
    }
  });
}

// ── 4. Old notifications cleanup ───────────────────────
function cleanSentNotifications() {
  db.ref('notifications')
    .orderByChild('sent')
    .equalTo(true)
    .once('value', snap => {
      if (!snap.exists()) return;
      const updates = {};
      snap.forEach(child => { updates[child.key] = null; });
      db.ref('notifications').update(updates);
    });
}

// ── 5. Old ludo invites cleanup ────────────────────────
function cleanOldInvites() {
  const cutoff = Date.now() - (60 * 60 * 1000); // 1 hour
  
  ['ludoInvites', 'raceInvites'].forEach(async (ref) => {
    const snap = await db.ref(ref).once('value');
    if (!snap.exists()) return;
    
    snap.forEach(userSnap => {
      userSnap.forEach(inviteSnap => {
        const invite = inviteSnap.val();
        if (invite.timestamp && invite.timestamp < cutoff) {
          inviteSnap.ref.remove();
        }
      });
    });
  });
}

// ── Schedule all cleanups ───────────────────────────────
setInterval(cleanOldMessages,        6 * 60 * 60 * 1000);  // every 6h
setInterval(cleanExpiredStories,     1 * 60 * 60 * 1000);  // every 1h
setInterval(cleanFinishedGames,      2 * 60 * 60 * 1000);  // every 2h
setInterval(cleanSentNotifications,  30 * 60 * 1000);       // every 30min
setInterval(cleanOldInvites,         1 * 60 * 60 * 1000);  // every 1h

// Run on startup too
cleanExpiredStories();
cleanSentNotifications();
cleanFinishedGames();

console.log('🛡️ Auto-cleanup system active!');
