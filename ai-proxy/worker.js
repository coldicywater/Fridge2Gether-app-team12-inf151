// Fridge2Gether AI proxy (Cloudflare Worker).
// The app sends its chat request here with the user's Firebase ID token.
// The Worker checks the token, then forwards the request to DeepSeek with the real key,
// so the key never ships inside the app.
//
// Settings (Cloudflare dashboard → Worker → Settings → Variables and Secrets):
//   DEEPSEEK_API_KEY     secret, your DeepSeek key
//   FIREBASE_PROJECT_ID  plain text, the Firebase project ID (Project settings → General)
//   MODEL                optional, defaults to deepseek-flash

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
const GOOGLE_KEYS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const MAX_BODY_BYTES = 2_000_000; // a 768px photo is ~100 KB; this leaves plenty of room
const MAX_TOKENS = 4000;

let cachedKeys = null;
let cachedUntil = 0;

export default {
  async fetch(request, env) {
    if (request.method !== "POST" || new URL(request.url).pathname !== "/chat") {
      return json({ error: "Not found" }, 404);
    }

    // 1. Only signed-in Fridge2Gether users.
    const auth = request.headers.get("Authorization") || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    let uid;
    try {
      uid = await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
    } catch (e) {
      return json({ error: "Not signed in: " + e.message }, 401);
    }

    // 2. Read and limit the request.
    const raw = await request.arrayBuffer();
    if (raw.byteLength > MAX_BODY_BYTES) return json({ error: "Request too large" }, 413);
    let body;
    try {
      body = JSON.parse(new TextDecoder().decode(raw));
    } catch {
      return json({ error: "Bad JSON" }, 400);
    }
    if (!Array.isArray(body.messages)) return json({ error: "messages missing" }, 400);

    // 3. Forward with our key. The model and limits are set here, not by the app.
    const upstream = await fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model: env.MODEL || "deepseek-flash",
        messages: body.messages,
        response_format: body.response_format,
        temperature: typeof body.temperature === "number" ? body.temperature : 0.4,
        max_tokens: MAX_TOKENS,
        stream: false,
        user: uid,
      }),
    });

    return new Response(upstream.body, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ---- Firebase ID token check (RS256 JWT signed by Google) ----

async function verifyFirebaseToken(token, projectId) {
  if (!projectId) throw new Error("FIREBASE_PROJECT_ID not set on the Worker");
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("no token");

  const header = JSON.parse(b64urlText(parts[0]));
  const payload = JSON.parse(b64urlText(parts[1]));
  const now = Math.floor(Date.now() / 1000);

  if (header.alg !== "RS256") throw new Error("bad alg");
  if (payload.aud !== projectId) throw new Error("wrong project");
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error("wrong issuer");
  if (!payload.sub) throw new Error("no user");
  if (payload.exp < now - 60) throw new Error("expired");
  if (payload.iat > now + 300) throw new Error("issued in the future");

  const keys = await googleKeys();
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error("unknown key");

  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    b64urlBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
  );
  if (!ok) throw new Error("bad signature");
  return payload.sub;
}

async function googleKeys() {
  if (cachedKeys && Date.now() < cachedUntil) return cachedKeys;
  const res = await fetch(GOOGLE_KEYS_URL);
  const data = await res.json();
  const maxAge = /max-age=(\d+)/.exec(res.headers.get("Cache-Control") || "");
  cachedKeys = data.keys;
  cachedUntil = Date.now() + (maxAge ? Number(maxAge[1]) * 1000 : 3600_000);
  return cachedKeys;
}

function b64urlBytes(s) {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  const bin = atob(b64);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

function b64urlText(s) {
  return new TextDecoder().decode(b64urlBytes(s));
}
