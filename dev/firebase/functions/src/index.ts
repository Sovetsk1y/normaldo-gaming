import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {setGlobalOptions} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {sendResetPrizePush, APNS_SECRETS} from "./push";

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({region: "europe-west1", maxInstances: 10});

// ─── Tuning ──────────────────────────────────────────────────────────────────

const MAX_PIZZAS_PER_SECOND = 4.0;
const SCORE_BUFFER          = 50;
const MAX_RUN_SECONDS       = 3600;
const TOP_LIMIT             = 100;
const SUBMIT_THROTTLE_MS    = 5_000;

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** ISO 8601 week id, e.g. "2026-W24". */
function getCurrentWeekId(date: Date = new Date()): string {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNum = Math.ceil((((d.getTime() - yearStart.getTime()) / 86_400_000) + 1) / 7);
  return `${d.getUTCFullYear()}-W${weekNum.toString().padStart(2, "0")}`;
}

function rewardForPlace(place: number): {dollars: number; tokens: number} {
  if (place === 1)   return {dollars: 5000, tokens: 10};
  if (place <= 3)    return {dollars: 2500, tokens: 5};
  if (place <= 10)   return {dollars: 1000, tokens: 2};
  if (place <= 50)   return {dollars: 300,  tokens: 1};
  if (place <= 100)  return {dollars: 100,  tokens: 1};
  return {dollars: 0, tokens: 1};
}

function requireAuth(ctxAuth: {uid: string} | undefined): string {
  if (!ctxAuth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  return ctxAuth.uid;
}

async function computeRank(weekId: string, metric: "best" | "total", score: number): Promise<number> {
  if (score <= 0) return 0; // unranked
  const snap = await db.collection(`leaderboards/${weekId}/${metric}`)
    .where("score", ">", score)
    .count()
    .get();
  return snap.data().count + 1;
}

// ─── initUser ────────────────────────────────────────────────────────────────
// Idempotent: creates /users/{uid} on first call. If recovery_code_hash is
// provided and the user doc doesn't have one yet, attaches it and writes the
// /recovery_lookup mapping. Never overwrites an existing hash.
export const initUser = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const displayName     = (request.data?.display_name as string | undefined) ?? "";
  const recoveryHash    = (request.data?.recovery_code_hash as string | undefined) ?? "";

  if (!displayName || displayName.length > 32) {
    throw new HttpsError("invalid-argument", "display_name 1..32 chars required");
  }

  const userRef = db.doc(`users/${uid}`);
  const weekId = getCurrentWeekId();

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      const doc: Record<string, unknown> = {
        display_name:    displayName,
        week_id:         weekId,
        best_endless:    0,
        total_endless:   0,
        pending_rewards: [],
        last_submit_at:  0,
        created_at:      admin.firestore.FieldValue.serverTimestamp(),
        updated_at:      admin.firestore.FieldValue.serverTimestamp(),
      };
      if (recoveryHash) {
        doc.recovery_code_hash = recoveryHash;
      }
      tx.set(userRef, doc);
      if (recoveryHash) {
        tx.set(db.doc(`recovery_lookup/${recoveryHash}`), {
          user_id:    uid,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else if (recoveryHash && !userSnap.get("recovery_code_hash")) {
      tx.update(userRef, {recovery_code_hash: recoveryHash});
      tx.set(db.doc(`recovery_lookup/${recoveryHash}`), {
        user_id:    uid,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  const fresh = await userRef.get();
  return {
    user_id:         uid,
    display_name:    fresh.get("display_name"),
    avatar_skin:     fresh.get("avatar_skin") ?? "classic",
    avatar_fat:      fresh.get("avatar_fat")  ?? 0,
    week_id:         fresh.get("week_id"),
    best_endless:    fresh.get("best_endless") ?? 0,
    total_endless:   fresh.get("total_endless") ?? 0,
    pending_rewards: fresh.get("pending_rewards") ?? [],
  };
});

// ─── submitScore ─────────────────────────────────────────────────────────────
// Validates and writes an endless-run score. Always bumps total. Only writes
// to /leaderboards/{week}/best/{uid} when score beats the user's prior best.
export const submitScore = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const score      = Number(request.data?.score ?? 0);
  const runSeconds = Number(request.data?.run_seconds ?? 0);
  const avatarSkin = String(request.data?.avatar_skin ?? "classic").slice(0, 32);
  const avatarFatRaw = Number(request.data?.avatar_fat ?? 0);
  const avatarFat = Number.isFinite(avatarFatRaw)
    ? Math.max(0, Math.min(3, Math.floor(avatarFatRaw)))
    : 0;

  if (!Number.isFinite(score) || score < 0 || score > 100_000) {
    throw new HttpsError("invalid-argument", "score out of range");
  }
  if (!Number.isFinite(runSeconds) || runSeconds < 0 || runSeconds > MAX_RUN_SECONDS) {
    throw new HttpsError("invalid-argument", "run_seconds out of range");
  }
  const maxPlausible = Math.ceil(MAX_PIZZAS_PER_SECOND * runSeconds + SCORE_BUFFER);
  if (score > maxPlausible) {
    throw new HttpsError("failed-precondition",
      `score ${score} exceeds plausible max ${maxPlausible} for ${runSeconds}s`);
  }

  const weekId   = getCurrentWeekId();
  const userRef  = db.doc(`users/${uid}`);
  const lbBest   = db.doc(`leaderboards/${weekId}/best/${uid}`);
  const lbTotal  = db.doc(`leaderboards/${weekId}/total/${uid}`);

  let newBest = 0;
  let newTotal = 0;
  let displayName = "";

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("failed-precondition", "user not initialised");
    }
    const now = Date.now();
    const lastSubmit = userSnap.get("last_submit_at") ?? 0;
    if (now - lastSubmit < SUBMIT_THROTTLE_MS) {
      throw new HttpsError("resource-exhausted", "submit throttled");
    }
    // Week rollover: if user's stored week is stale, reset before adding
    const storedWeek = userSnap.get("week_id") ?? weekId;
    const prevBest  = storedWeek === weekId ? (userSnap.get("best_endless")  ?? 0) : 0;
    const prevTotal = storedWeek === weekId ? (userSnap.get("total_endless") ?? 0) : 0;
    displayName = userSnap.get("display_name") ?? "Normaldo";

    newBest  = Math.max(prevBest, score);
    newTotal = prevTotal + score;

    const updateData: Record<string, unknown> = {
      week_id:        weekId,
      best_endless:   newBest,
      total_endless:  newTotal,
      last_submit_at: now,
      updated_at:     admin.firestore.FieldValue.serverTimestamp(),
    };
    tx.update(userRef, updateData);

    const ts = admin.firestore.FieldValue.serverTimestamp();
    if (score > prevBest) {
      tx.set(lbBest, {
        user_id:      uid,
        display_name: displayName,
        avatar_skin:  avatarSkin,
        avatar_fat:   avatarFat,
        score:        newBest,
        updated_at:   ts,
      });
    }
    tx.set(lbTotal, {
      user_id:      uid,
      display_name: displayName,
      avatar_skin:  avatarSkin,
      avatar_fat:   avatarFat,
      score:        newTotal,
      updated_at:   ts,
    }, {merge: true});
  });

  // Rank queries (outside the transaction; eventual consistency is OK here)
  const [rankBest, rankTotal] = await Promise.all([
    computeRank(weekId, "best",  newBest),
    computeRank(weekId, "total", newTotal),
  ]);

  return {
    best_endless:  newBest,
    total_endless: newTotal,
    rank_best:     rankBest,
    rank_total:    rankTotal,
    week_id:       weekId,
  };
});

// ─── getLeaderboard ──────────────────────────────────────────────────────────
export const getLeaderboard = onCall(async (request) => {
  requireAuth(request.auth);
  const metric = String(request.data?.metric ?? "best");
  if (metric !== "best" && metric !== "total") {
    throw new HttpsError("invalid-argument", "metric must be 'best' or 'total'");
  }
  const limit = Math.min(Number(request.data?.limit ?? TOP_LIMIT), TOP_LIMIT);
  const weekId = getCurrentWeekId();

  const snap = await db.collection(`leaderboards/${weekId}/${metric}`)
    .orderBy("score", "desc")
    .orderBy("updated_at", "asc")
    .limit(limit)
    .get();

  const rows = snap.docs.map((doc, idx) => ({
    rank:         idx + 1,
    user_id:      doc.get("user_id"),
    display_name: doc.get("display_name"),
    avatar_skin:  doc.get("avatar_skin") ?? "classic",
    avatar_fat:   doc.get("avatar_fat")  ?? 0,
    score:        doc.get("score"),
  }));

  const totalSnap = await db.collection(`leaderboards/${weekId}/${metric}`).count().get();

  return {
    week_id:       weekId,
    rows,
    total_players: totalSnap.data().count,
  };
});

// ─── getWindow ───────────────────────────────────────────────────────────────
export const getWindow = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const metric = String(request.data?.metric ?? "best");
  if (metric !== "best" && metric !== "total") {
    throw new HttpsError("invalid-argument", "metric must be 'best' or 'total'");
  }
  const radius = Math.min(Math.max(Number(request.data?.radius ?? 5), 1), 20);
  const weekId = getCurrentWeekId();

  const playerDoc = await db.doc(`leaderboards/${weekId}/${metric}/${uid}`).get();
  if (!playerDoc.exists) {
    return {rows: [], player_rank: 0};
  }
  const myScore = playerDoc.get("score") as number;

  const [aboveSnap, belowSnap] = await Promise.all([
    db.collection(`leaderboards/${weekId}/${metric}`)
      .where("score", ">", myScore)
      .orderBy("score", "asc")
      .limit(radius)
      .get(),
    db.collection(`leaderboards/${weekId}/${metric}`)
      .where("score", "<", myScore)
      .orderBy("score", "desc")
      .limit(radius)
      .get(),
  ]);

  const playerRank = await computeRank(weekId, metric as "best" | "total", myScore);

  const above = aboveSnap.docs.reverse().map((doc, i) => ({
    rank:         playerRank - aboveSnap.size + i,
    user_id:      doc.get("user_id"),
    display_name: doc.get("display_name"),
    avatar_skin:  doc.get("avatar_skin") ?? "classic",
    avatar_fat:   doc.get("avatar_fat")  ?? 0,
    score:        doc.get("score"),
    is_player:    false,
  }));
  const player = {
    rank:         playerRank,
    user_id:      uid,
    display_name: playerDoc.get("display_name"),
    avatar_skin:  playerDoc.get("avatar_skin") ?? "classic",
    avatar_fat:   playerDoc.get("avatar_fat")  ?? 0,
    score:        myScore,
    is_player:    true,
  };
  const below = belowSnap.docs.map((doc, i) => ({
    rank:         playerRank + i + 1,
    user_id:      doc.get("user_id"),
    display_name: doc.get("display_name"),
    avatar_skin:  doc.get("avatar_skin") ?? "classic",
    avatar_fat:   doc.get("avatar_fat")  ?? 0,
    score:        doc.get("score"),
    is_player:    false,
  }));

  return {
    week_id:     weekId,
    rows:        [...above, player, ...below],
    player_rank: playerRank,
  };
});

// ─── claimReward ─────────────────────────────────────────────────────────────
export const claimReward = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const index = Number(request.data?.index ?? -1);
  if (!Number.isInteger(index) || index < 0) {
    throw new HttpsError("invalid-argument", "index required");
  }
  const userRef = db.doc(`users/${uid}`);

  return await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new HttpsError("not-found", "user not initialised");
    const rewards = (userSnap.get("pending_rewards") ?? []) as Array<Record<string, unknown>>;
    if (index >= rewards.length) throw new HttpsError("out-of-range", "index out of range");
    const reward = rewards[index];
    if (reward.claimed) throw new HttpsError("failed-precondition", "already claimed");

    rewards[index] = {...reward, claimed: true};
    tx.update(userRef, {
      pending_rewards: rewards,
      updated_at:      admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      dollars: Number(reward.dollars ?? 0),
      tokens:  Number(reward.tokens ?? 0),
      metric:  String(reward.metric ?? "best"),
      place:   Number(reward.place ?? 0),
      week:    String(reward.week ?? ""),
    };
  });
});

// ─── updateAvatar ────────────────────────────────────────────────────────────
// Persists the player's chosen avatar (skin + fat state) on the user doc and
// propagates it into any leaderboard entries for the current week.
export const updateAvatar = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const avatarSkin = String(request.data?.avatar_skin ?? "classic").slice(0, 32);
  const avatarFatRaw = Number(request.data?.avatar_fat ?? 0);
  const avatarFat = Number.isFinite(avatarFatRaw)
    ? Math.max(0, Math.min(3, Math.floor(avatarFatRaw)))
    : 0;
  if (!/^[a-z0-9_\-]+$/.test(avatarSkin)) {
    throw new HttpsError("invalid-argument", "avatar_skin invalid");
  }

  const weekId = getCurrentWeekId();
  const userRef = db.doc(`users/${uid}`);
  const lbBest  = db.doc(`leaderboards/${weekId}/best/${uid}`);
  const lbTotal = db.doc(`leaderboards/${weekId}/total/${uid}`);
  const ts = admin.firestore.FieldValue.serverTimestamp();

  await userRef.set({
    avatar_skin: avatarSkin,
    avatar_fat:  avatarFat,
    updated_at:  ts,
  }, {merge: true});

  // Only patch leaderboard rows that already exist — avoid creating empty
  // entries for users who haven't submitted a score yet.
  const [bestSnap, totalSnap] = await Promise.all([lbBest.get(), lbTotal.get()]);
  const batch = db.batch();
  if (bestSnap.exists)  batch.update(lbBest,  {avatar_skin: avatarSkin, avatar_fat: avatarFat});
  if (totalSnap.exists) batch.update(lbTotal, {avatar_skin: avatarSkin, avatar_fat: avatarFat});
  if (bestSnap.exists || totalSnap.exists) await batch.commit();

  return {avatar_skin: avatarSkin, avatar_fat: avatarFat};
});

// ─── setDisplayName ──────────────────────────────────────────────────────────
// Atomically reserves a (case-insensitive) display name. /names/{lower} doc
// acts as the uniqueness lock — enforced via transaction.
export const setDisplayName = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const raw = String(request.data?.display_name ?? "").trim();
  if (raw.length < 3 || raw.length > 12) {
    throw new HttpsError("invalid-argument", "name must be 3..12 chars");
  }
  if (!/^[A-Za-zА-Яа-яЁё0-9_\-]+$/u.test(raw)) {
    throw new HttpsError("invalid-argument", "name contains illegal characters");
  }
  const lower = raw.toLowerCase();
  const nameRef = db.doc(`names/${lower}`);
  const userRef = db.doc(`users/${uid}`);

  await db.runTransaction(async (tx) => {
    const nameSnap = await tx.get(nameRef);
    if (nameSnap.exists && nameSnap.get("user_id") !== uid) {
      throw new HttpsError("already-exists", "name taken");
    }
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("failed-precondition", "user not initialised");
    }
    const oldName = (userSnap.get("display_name") as string | undefined) ?? "";
    const oldLower = oldName.toLowerCase();
    if (oldLower && oldLower !== lower) {
      tx.delete(db.doc(`names/${oldLower}`));
    }
    tx.set(nameRef, {
      user_id:    uid,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(userRef, {
      display_name: raw,
      updated_at:   admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Propagate the new name to any existing leaderboard rows for this week.
  // Like updateAvatar, only patch — don't create empty entries.
  const weekId = getCurrentWeekId();
  const lbBest  = db.doc(`leaderboards/${weekId}/best/${uid}`);
  const lbTotal = db.doc(`leaderboards/${weekId}/total/${uid}`);
  const [bestSnap, totalSnap] = await Promise.all([lbBest.get(), lbTotal.get()]);
  const batch = db.batch();
  if (bestSnap.exists)  batch.update(lbBest,  {display_name: raw});
  if (totalSnap.exists) batch.update(lbTotal, {display_name: raw});
  if (bestSnap.exists || totalSnap.exists) await batch.commit();

  return {display_name: raw};
});

// ─── restoreAccount ──────────────────────────────────────────────────────────
// Auth is OPTIONAL: a freshly-installed app may call this without an idToken.
// When auth IS present (device already had an anon identity), we MERGE the
// anon's current-week leaderboard progress into the restored account so the
// player ends up as a single row whose score includes both identities:
//   best_endless  = max(anon.best,  restored.best)
//   total_endless = anon.total    + restored.total
// Then the anon's footprint is removed.
export const restoreAccount = onCall(async (request) => {
  const hash = String(request.data?.recovery_code_hash ?? "");
  if (!hash || hash.length < 16) {
    throw new HttpsError("invalid-argument", "recovery_code_hash required");
  }
  const lookup = await db.doc(`recovery_lookup/${hash}`).get();
  if (!lookup.exists) {
    throw new HttpsError("not-found", "code not found");
  }
  const newUid = lookup.get("user_id") as string;
  const callerUid = request.auth?.uid;
  if (callerUid && callerUid !== newUid) {
    await mergeAndCleanup(callerUid, newUid);
  }
  const customToken = await admin.auth().createCustomToken(newUid);
  return {custom_token: customToken, user_id: newUid};
});

async function mergeAndCleanup(oldUid: string, newUid: string): Promise<void> {
  const weekId = getCurrentWeekId();
  const ts = admin.firestore.FieldValue.serverTimestamp();

  const [oldUserSnap, newUserSnap, oldBestSnap, newBestSnap, oldTotalSnap, newTotalSnap]
    = await Promise.all([
      db.doc(`users/${oldUid}`).get(),
      db.doc(`users/${newUid}`).get(),
      db.doc(`leaderboards/${weekId}/best/${oldUid}`).get(),
      db.doc(`leaderboards/${weekId}/best/${newUid}`).get(),
      db.doc(`leaderboards/${weekId}/total/${oldUid}`).get(),
      db.doc(`leaderboards/${weekId}/total/${newUid}`).get(),
    ]);

  // Restored account identity drives the merged row (display_name + avatar).
  const displayName = (newUserSnap.get("display_name") as string | undefined) ?? "";
  const avatarSkin  = (newUserSnap.get("avatar_skin")  as string | undefined) ?? "classic";
  const avatarFat   = (newUserSnap.get("avatar_fat")   as number | undefined) ?? 0;

  const oldBest  = oldBestSnap.exists  ? (oldBestSnap.get("score")  as number) : 0;
  const newBest  = newBestSnap.exists  ? (newBestSnap.get("score")  as number) : 0;
  const oldTotal = oldTotalSnap.exists ? (oldTotalSnap.get("score") as number) : 0;
  const newTotal = newTotalSnap.exists ? (newTotalSnap.get("score") as number) : 0;
  const mergedBest  = Math.max(oldBest, newBest);
  const mergedTotal = oldTotal + newTotal;

  const batch = db.batch();

  // Write merged leaderboard rows under the restored uid.
  if (mergedBest > 0) {
    batch.set(db.doc(`leaderboards/${weekId}/best/${newUid}`), {
      user_id:      newUid,
      display_name: displayName,
      avatar_skin:  avatarSkin,
      avatar_fat:   avatarFat,
      score:        mergedBest,
      updated_at:   ts,
    });
  }
  if (mergedTotal > 0) {
    batch.set(db.doc(`leaderboards/${weekId}/total/${newUid}`), {
      user_id:      newUid,
      display_name: displayName,
      avatar_skin:  avatarSkin,
      avatar_fat:   avatarFat,
      score:        mergedTotal,
      updated_at:   ts,
    });
  }
  // Sync the user doc counters so client fetches see the merged values.
  batch.set(db.doc(`users/${newUid}`), {
    best_endless:  mergedBest,
    total_endless: mergedTotal,
    updated_at:    ts,
  }, {merge: true});

  // Remove the anon footprint: leaderboard rows, user doc, name reservation,
  // recovery_lookup.
  batch.delete(db.doc(`leaderboards/${weekId}/best/${oldUid}`));
  batch.delete(db.doc(`leaderboards/${weekId}/total/${oldUid}`));
  if (oldUserSnap.exists) {
    const oldName = oldUserSnap.get("display_name") as string | undefined;
    if (oldName) {
      batch.delete(db.doc(`names/${oldName.toLowerCase()}`));
    }
    const oldRecoveryHash = oldUserSnap.get("recovery_code_hash") as string | undefined;
    if (oldRecoveryHash) {
      batch.delete(db.doc(`recovery_lookup/${oldRecoveryHash}`));
    }
    batch.delete(db.doc(`users/${oldUid}`));
  }
  await batch.commit();

  // Drop the anon's Firebase Auth identity (cheap to leave, but cleaner removed)
  try {
    await admin.auth().deleteUser(oldUid);
  } catch (e) {
    console.warn(`mergeAndCleanup: deleteUser(${oldUid}) failed:`, e);
  }
}

// ─── weeklyReset ─────────────────────────────────────────────────────────────
// Runs every Monday 00:05 UTC (small buffer past midnight to avoid clock-edge
// races). Distributes prizes for the *previous* week to each ranked player's
// pending_rewards, then resets users' weekly counters.
export const weeklyReset = onSchedule({
  schedule: "5 0 * * 1",
  timeZone: "Etc/UTC",
  retryCount: 3,
  secrets: APNS_SECRETS, // weeklyReset sends the G3 prize push (iOS via APNs)
}, async () => {
  const now = new Date();
  // Last week's id = Monday-of-previous-week
  const prev = new Date(now);
  prev.setUTCDate(prev.getUTCDate() - 3);
  const prevWeek = getCurrentWeekId(prev);
  const newWeek  = getCurrentWeekId(now);

  // G3 — collect each ranked player's best prize across metrics; pushed after
  // the Firestore writes commit so a send failure can't poison the reset.
  const prizeTargets = new Map<string, {place: number; dollars: number; tokens: number}>();

  const metaRef = db.doc("meta/leaderboard");
  const metaSnap = await metaRef.get();
  if (metaSnap.exists && metaSnap.get("distributed_for_week") === prevWeek) {
    console.log(`Already distributed for ${prevWeek}, skipping`);
    return;
  }

  for (const metric of ["best", "total"] as const) {
    const lb = await db.collection(`leaderboards/${prevWeek}/${metric}`)
      .orderBy("score", "desc")
      .orderBy("updated_at", "asc")
      .get();

    let place = 0;
    const batch = db.batch();
    let ops = 0;
    for (const doc of lb.docs) {
      place += 1;
      const uid = doc.get("user_id") as string;
      const {dollars, tokens} = rewardForPlace(place);
      // Keep the better prize when a player ranks in both metrics.
      const prev = prizeTargets.get(uid);
      if (!prev || tokens > prev.tokens) prizeTargets.set(uid, {place, dollars, tokens});
      const reward = {
        week:    prevWeek,
        metric,
        place,
        dollars,
        tokens,
        claimed: false,
      };
      batch.update(db.doc(`users/${uid}`), {
        pending_rewards: admin.firestore.FieldValue.arrayUnion(reward),
        updated_at:      admin.firestore.FieldValue.serverTimestamp(),
      });
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();

    // Archive top-100 snapshot for history view
    const top100 = lb.docs.slice(0, 100).map((doc, idx) => ({
      rank:         idx + 1,
      user_id:      doc.get("user_id"),
      display_name: doc.get("display_name"),
      score:        doc.get("score"),
    }));
    await db.doc(`history/${prevWeek}/snapshots/${metric}`).set({rows: top100});
  }

  // Reset users' per-week counters
  const allUsers = await db.collection("users").get();
  let batch = db.batch();
  let ops = 0;
  for (const u of allUsers.docs) {
    batch.update(u.ref, {
      week_id:       newWeek,
      best_endless:  0,
      total_endless: 0,
      updated_at:    admin.firestore.FieldValue.serverTimestamp(),
    });
    ops += 1;
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  await metaRef.set({
    current_week:          newWeek,
    distributed_for_week:  prevWeek,
    last_run_at:           admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  // G3 — notify each ranked player their prize is waiting. Best-effort; a send
  // failure (no token / push error) is logged inside the helper, never thrown.
  let pushed = 0;
  for (const [uid, p] of prizeTargets) {
    await sendResetPrizePush(uid, p.place, p.dollars, p.tokens);
    pushed += 1;
  }

  console.log(`Distributed rewards for ${prevWeek}, new week is ${newWeek}, G3 pushed=${pushed}`);
});

// ─── Remote push ───────────────────────────────────────────────────────────────
// Re-export ONLY the deployable functions from push.ts (not the sendPushToUser /
// sendResetPrizePush / APNS_SECRETS helpers — exporting non-functions from the
// entry point confuses function discovery). G3 is wired into weeklyReset above.
export {registerPushToken, sendTestPush, sendCampaign, onLeaderboardWrite} from "./push";
