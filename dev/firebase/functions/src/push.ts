// Remote push: token registration + send helpers (FCM for Android,
// APNs HTTP/2 for iOS) + dev/admin send entry points. Re-exported from index.ts
// (`export * from "./push"`) AFTER admin.initializeApp() runs there, so every
// admin.* access below is lazy (inside handlers), never at module load.
import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as http2 from "http2";
import * as crypto from "crypto";

// APNs credentials — set via `firebase functions:secrets:set`. APNS_KEY holds
// the full .p8 file contents.
const APNS_KEY     = defineSecret("APNS_KEY");
const APNS_KEY_ID  = defineSecret("APNS_KEY_ID");
const APNS_TEAM_ID = defineSecret("APNS_TEAM_ID");
// Exported so triggers in index.ts (weeklyReset) can bind the same secrets.
export const APNS_SECRETS = [APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID];

// Must match the other functions' region (index.ts setGlobalOptions). Set
// explicitly per-function because push.ts is imported by index.ts BEFORE its
// setGlobalOptions runs, so the global default wouldn't apply here.
const FN_REGION = "europe-west1";

const IOS_BUNDLE_ID = "com.normaldo.mobapp";
// A device token belongs to exactly one APNs environment, decided by how the
// build was signed (development vs distribution) — unknowable server-side. So we
// try production first and fall back to sandbox on BadDeviceToken. Release builds
// succeed on the first host; Xcode/dev builds on the second. No manual flipping.
const APNS_HOSTS = [
  "https://api.push.apple.com",
  "https://api.sandbox.push.apple.com",
];

interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

// ─── Token registration ────────────────────────────────────────────────────────

export const registerPushToken = onCall({region: FN_REGION}, async (request: CallableRequest) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required");
  const token = String(request.data?.token ?? "");
  const platform = String(request.data?.platform ?? "");
  if (!token || (platform !== "android" && platform !== "ios")) {
    throw new HttpsError("invalid-argument", "token + platform(android|ios) required");
  }
  await admin.firestore().doc(`users/${uid}`).set({
    push_token:      token,
    push_platform:   platform,
    push_updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {ok: true};
});

// ─── Senders ────────────────────────────────────────────────────────────────────

/** FCM data values must be strings; flatten everything to String. */
function flattenData(data?: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const k of Object.keys(data ?? {})) out[k] = String((data as Record<string, unknown>)[k]);
  return out;
}

async function sendFcm(token: string, msg: PushMessage): Promise<void> {
  // Data-only (no `notification` block) so the app's FirebaseMessagingService
  // ALWAYS gets onMessageReceived — even backgrounded — and builds the
  // notification itself through NotifScheduler, preserving deep-link routing.
  await admin.messaging().send({
    token,
    data:    {title: msg.title, body: msg.body, ...flattenData(msg.data)},
    android: {priority: "high"},
  });
}

function b64url(input: Buffer | string): string {
  return Buffer.from(input).toString("base64")
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// APNs provider JWT (ES256 over the .p8 key). Valid ~1h; cache and reuse — Apple
// rejects tokens regenerated too often.
let cachedJwt: {token: string; iat: number} = {token: "", iat: 0};
function apnsJwt(keyP8: string, keyId: string, teamId: string): string {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt.token && now - cachedJwt.iat < 3000) return cachedJwt.token;
  const header = b64url(JSON.stringify({alg: "ES256", kid: keyId}));
  const claims = b64url(JSON.stringify({iss: teamId, iat: now}));
  const signingInput = `${header}.${claims}`;
  const key = crypto.createPrivateKey(keyP8);
  // ieee-p1363 → raw r||s, the encoding JWT ES256 expects.
  const sig = crypto.sign("sha256", Buffer.from(signingInput), {key, dsaEncoding: "ieee-p1363"});
  const jwt = `${signingInput}.${b64url(sig)}`;
  cachedJwt = {token: jwt, iat: now};
  return jwt;
}

// One HTTP/2 POST to a specific APNs host. Rejects with "APNs <status>: <body>".
function apnsPost(host: string, token: string, jwt: string, payload: string): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const client = http2.connect(host);
    client.on("error", reject);
    const req = client.request({
      ":method":         "POST",
      ":path":           `/3/device/${token}`,
      "authorization":   `bearer ${jwt}`,
      "apns-topic":      IOS_BUNDLE_ID,
      "apns-push-type":  "alert",
      "content-type":    "application/json",
    });
    let status = 0;
    let respBody = "";
    req.on("response", (h) => { status = Number(h[":status"]); });
    req.on("data", (d) => { respBody += d; });
    req.on("end", () => {
      client.close();
      if (status === 200) resolve();
      else reject(new Error(`APNs ${status}: ${respBody}`));
    });
    req.on("error", reject);
    req.end(payload);
  });
}

async function sendApns(token: string, msg: PushMessage): Promise<void> {
  const jwt = apnsJwt(APNS_KEY.value(), APNS_KEY_ID.value(), APNS_TEAM_ID.value());
  const payload = JSON.stringify({
    aps: {alert: {title: msg.title, body: msg.body}, sound: "default"},
    ...flattenData(msg.data),
  });
  // A token's environment is unknowable server-side, so try every host and
  // succeed on whichever accepts the token. If all fail, surface each host's
  // result so a host-specific mismatch is distinguishable from a key/JWT error.
  const errors: string[] = [];
  for (const host of APNS_HOSTS) {
    try {
      await apnsPost(host, token, jwt, payload);
      return; // delivered
    } catch (e) {
      const m = e instanceof Error ? e.message : String(e);
      errors.push(`${host.replace("https://", "")} → ${m}`);
    }
  }
  throw new Error(`all APNs hosts failed: ${errors.join(" | ")}`);
}

/** Resolve the user's stored token + platform and dispatch. Returns false when
 *  the user has no registered token. */
export async function sendPushToUser(uid: string, msg: PushMessage): Promise<boolean> {
  const snap = await admin.firestore().doc(`users/${uid}`).get();
  const token = snap.get("push_token") as string | undefined;
  const platform = snap.get("push_platform") as string | undefined;
  if (!token) return false;
  if (platform === "android") {
    await sendFcm(token, msg);
    return true;
  }
  if (platform === "ios") {
    await sendApns(token, msg);
    return true;
  }
  return false;
}

// ─── Entry points ───────────────────────────────────────────────────────────────

// Dev-only end-to-end check: pushes to the caller (or an explicit uid).
export const sendTestPush = onCall({region: FN_REGION, secrets: APNS_SECRETS}, async (request: CallableRequest) => {
  const uid = String(request.data?.uid ?? request.auth?.uid ?? "");
  if (!uid) throw new HttpsError("invalid-argument", "uid required");
  // Catch + return the reason (APNs/FCM rejection, key parse error, …) instead
  // of throwing — a thrown error surfaces to the client only as opaque INTERNAL.
  try {
    const ok = await sendPushToUser(uid, {
      title: "Normaldo",
      body:  "Тестовый remote-пуш 🐢",
      data:  {id: "dev_remote", deep_link: "leaderboard", category: "dev"},
    });
    return {ok, error: ok ? "" : "no push_token registered for this user"};
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("sendTestPush failed:", msg);
    return {ok: false, error: msg};
  }
});

// H1/H2 manual content campaigns. Admin-gated via a custom claim
// (`admin.auth().setCustomUserClaims(uid, {admin: true})`). Fans out to every
// user with a registered token, in batches.
export const sendCampaign = onCall({region: FN_REGION, secrets: APNS_SECRETS}, async (request: CallableRequest) => {
  if (request.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "admin only");
  }
  const title = String(request.data?.title ?? "");
  const body  = String(request.data?.body ?? "");
  const data  = (request.data?.data ?? {}) as Record<string, unknown>;
  if (!title || !body) throw new HttpsError("invalid-argument", "title + body required");

  const users = await admin.firestore().collection("users")
    .where("push_token", "!=", "").get();
  let sent = 0;
  let failed = 0;
  for (const doc of users.docs) {
    try {
      const ok = await sendPushToUser(doc.id, {title, body, data});
      if (ok) sent += 1;
    } catch (e) {
      failed += 1;
      console.error(`campaign send failed for ${doc.id}: ${String(e)}`);
    }
  }
  return {ok: true, sent, failed};
});

// ─── G3 — weekly reset prize push ───────────────────────────────────────────────
// Called from weeklyReset (index.ts) for each user who placed last week.
export async function sendResetPrizePush(
  uid: string, place: number, dollars: number, tokens: number,
): Promise<void> {
  const prize = dollars > 0 ? `$${dollars} + ${tokens} жет.` : `${tokens} жет.`;
  await sendPushToUser(uid, {
    title: "Новая неделя — новые места",
    body:  `Награды прошлой недели в кармане: ${prize} (#${place}).`,
    data:  {id: "notif_g3", deep_link: "leaderboard", category: "G"},
  }).catch((e) => console.error(`G3 send failed ${uid}: ${String(e)}`));
}

// ─── G2 — "someone overtook you" ────────────────────────────────────────────────
// Fires on every leaderboard score write. When a score improves, the users it
// just passed (score strictly between old and new) get a one-off nudge — capped
// to recently-active players, throttled per recipient to avoid spam.
const G2_THROTTLE_SECS      = 6 * 3600;   // ≤ 1 G2 per recipient / 6h
const G2_ACTIVE_WINDOW_SECS = 10 * 3600;  // only ping players active ≤ 10h ago
const G2_MAX_RECIPIENTS     = 5;          // cap work per write

export const onLeaderboardWrite = onDocumentWritten(
  {document: "leaderboards/{week}/{metric}/{uid}", region: FN_REGION, secrets: APNS_SECRETS},
  async (event) => {
    const after = event.data?.after;
    const before = event.data?.before;
    if (!after?.exists) return;
    const newScore = Number(after.get("score") ?? 0);
    const oldScore = before?.exists ? Number(before.get("score") ?? 0) : 0;
    if (newScore <= oldScore) return; // only react to improvements

    const db = admin.firestore();
    const week = event.params.week as string;
    const metric = event.params.metric as string;
    const moverUid = event.params.uid as string;
    const moverName = String(after.get("display_name") ?? "Кто-то");
    const nowSecs = Math.floor(Date.now() / 1000);

    // Players the mover just passed: score in (oldScore, newScore), closest first.
    const overtaken = await db.collection(`leaderboards/${week}/${metric}`)
      .where("score", ">", oldScore)
      .where("score", "<", newScore)
      .orderBy("score", "desc")
      .limit(G2_MAX_RECIPIENTS)
      .get();

    for (const doc of overtaken.docs) {
      const uid = doc.get("user_id") as string | undefined;
      if (!uid || uid === moverUid) continue;
      const userSnap = await db.doc(`users/${uid}`).get();
      if (!userSnap.exists || !userSnap.get("push_token")) continue;

      const updatedAt = userSnap.get("updated_at") as admin.firestore.Timestamp | undefined;
      const lastActive = updatedAt ? Math.floor(updatedAt.toMillis() / 1000) : 0;
      if (nowSecs - lastActive > G2_ACTIVE_WINDOW_SECS) continue;
      const lastG2 = Number(userSnap.get("g2_last_sent_at") ?? 0);
      if (nowSecs - lastG2 < G2_THROTTLE_SECS) continue;

      const rankSnap = await db.collection(`leaderboards/${week}/${metric}`)
        .where("score", ">", Number(doc.get("score"))).count().get();
      const place = rankSnap.data().count + 1;
      if (place > 100) continue; // top-100 only, per the concept

      try {
        await sendPushToUser(uid, {
          title: "Тебя обогнали",
          body:  `${moverName} забрал ${place}-е место. Реванш?`,
          data:  {id: "notif_g2", deep_link: "leaderboard", category: "G"},
        });
        await db.doc(`users/${uid}`).update({g2_last_sent_at: nowSecs});
      } catch (e) {
        console.error(`G2 send failed ${uid}: ${String(e)}`);
      }
    }
  });
