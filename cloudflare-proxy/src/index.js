// Cloudflare Worker: OpenAI proxy with rate limiting & spend caps
// Routes: POST / → chat completions, POST /tts → text-to-speech

// ── Cost estimates (gpt-4o-mini, March 2026) ──
// Input:  $0.15 / 1M tokens  → $0.00015 / 1K tokens
// Output: $0.60 / 1M tokens  → $0.00060 / 1K tokens
// TTS-1:  $15.00 / 1M chars  → $0.015   / 1K chars

const OPENAI_API = "https://api.openai.com/v1";

// Per-IP rate limits (requests per window)
const LIMITS = {
  chat:       { max: 30,  windowSec: 3600 },   // 30 chat msgs/hr per IP
  tts:        { max: 5,   windowSec: 3600 },   // 5 TTS generations/hr per IP
  burstChat:  { max: 8,   windowSec: 60 },     // 8 chat msgs/min (burst)
  burstTts:   { max: 2,   windowSec: 60 },     // 2 TTS/min (burst)
};

// Hard caps on what the client can request
const MAX_CHAT_TOKENS = 500;
const MAX_TTS_CHARS = 20000;   // ~20K chars ≈ 30-min meditation script
const ALLOWED_MODELS = new Set(["gpt-4o-mini"]);
const ALLOWED_TTS_MODELS = new Set(["tts-1"]);

export default {
  async fetch(request, env) {
    // CORS preflight
    if (request.method === "OPTIONS") {
      return corsResponse(new Response(null, { status: 204 }));
    }

    if (request.method !== "POST") {
      return corsResponse(jsonError("Method not allowed", 405));
    }

    const url = new URL(request.url);
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";

    try {
      if (url.pathname === "/tts") {
        return corsResponse(await handleTTS(request, env, ip));
      } else {
        return corsResponse(await handleChat(request, env, ip));
      }
    } catch (err) {
      console.error("Worker error:", err);
      return corsResponse(jsonError("Internal server error", 500));
    }
  },
};

// ── Chat Completions ──

async function handleChat(request, env, ip) {
  // Rate limit: burst + hourly
  const burstCheck = await checkRateLimit(env, `burst:chat:${ip}`, LIMITS.burstChat);
  if (burstCheck) return burstCheck;
  const hourCheck = await checkRateLimit(env, `hour:chat:${ip}`, LIMITS.chat);
  if (hourCheck) return hourCheck;

  // Daily/monthly spend caps
  const budgetCheck = await checkBudget(env);
  if (budgetCheck) return budgetCheck;

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonError("Invalid JSON", 400);
  }

  // Validate & clamp
  if (!body.messages || !Array.isArray(body.messages)) {
    return jsonError("Missing messages array", 400);
  }
  if (!ALLOWED_MODELS.has(body.model || "gpt-4o-mini")) {
    return jsonError("Model not allowed", 400);
  }

  const sanitized = {
    model: "gpt-4o-mini",
    messages: body.messages.slice(-22), // system + 20 history max + 1 user
    max_tokens: Math.min(body.max_tokens || 300, MAX_CHAT_TOKENS),
    temperature: 0.7,
  };

  const resp = await fetch(`${OPENAI_API}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify(sanitized),
  });

  const data = await resp.json();

  // Track spend
  if (data.usage) {
    const costCents =
      (data.usage.prompt_tokens / 1000) * 0.015 +
      (data.usage.completion_tokens / 1000) * 0.06;
    await trackSpend(env, costCents);
  }

  return new Response(JSON.stringify(data), {
    status: resp.status,
    headers: { "Content-Type": "application/json" },
  });
}

// ── Text-to-Speech ──

async function handleTTS(request, env, ip) {
  // Rate limit: burst + hourly
  const burstCheck = await checkRateLimit(env, `burst:tts:${ip}`, LIMITS.burstTts);
  if (burstCheck) return burstCheck;
  const hourCheck = await checkRateLimit(env, `hour:tts:${ip}`, LIMITS.chat);
  if (hourCheck) return hourCheck;

  // Budget check
  const budgetCheck = await checkBudget(env);
  if (budgetCheck) return budgetCheck;

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonError("Invalid JSON", 400);
  }

  if (!body.input || typeof body.input !== "string") {
    return jsonError("Missing input text", 400);
  }
  if (!ALLOWED_TTS_MODELS.has(body.model || "tts-1")) {
    return jsonError("TTS model not allowed", 400);
  }

  // Clamp input length
  const input = body.input.slice(0, MAX_TTS_CHARS);

  const sanitized = {
    model: "tts-1",
    input,
    voice: ["nova", "onyx", "shimmer"].includes(body.voice) ? body.voice : "nova",
    response_format: "mp3",
    speed: Math.max(0.5, Math.min(2.0, body.speed || 1.0)),
  };

  const resp = await fetch(`${OPENAI_API}/audio/speech`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify(sanitized),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error("TTS error:", errText);
    return jsonError("TTS generation failed", resp.status);
  }

  // Track TTS spend (~$0.015 per 1K chars)
  const costCents = (input.length / 1000) * 1.5;
  await trackSpend(env, costCents);

  return new Response(resp.body, {
    status: 200,
    headers: {
      "Content-Type": "audio/mpeg",
      "Cache-Control": "private, max-age=86400",
    },
  });
}

// ── Rate Limiting (KV-based sliding window) ──

async function checkRateLimit(env, key, limit) {
  if (!env.RATE_LIMIT) return null; // Skip if KV not configured

  const now = Math.floor(Date.now() / 1000);
  const windowKey = `rl:${key}:${Math.floor(now / limit.windowSec)}`;

  const current = parseInt(await env.RATE_LIMIT.get(windowKey)) || 0;

  if (current >= limit.max) {
    return jsonError("Rate limit exceeded. Please try again later.", 429);
  }

  await env.RATE_LIMIT.put(windowKey, String(current + 1), {
    expirationTtl: limit.windowSec * 2,
  });

  return null;
}

// ── Budget / Spend Caps ──

function todayKey() {
  return `spend:day:${new Date().toISOString().slice(0, 10)}`;
}

function monthKey() {
  return `spend:month:${new Date().toISOString().slice(0, 7)}`;
}

async function trackSpend(env, costCents) {
  if (!env.RATE_LIMIT) return;

  const dKey = todayKey();
  const mKey = monthKey();

  const [dayVal, monthVal] = await Promise.all([
    env.RATE_LIMIT.get(dKey),
    env.RATE_LIMIT.get(mKey),
  ]);

  const newDay = (parseFloat(dayVal) || 0) + costCents;
  const newMonth = (parseFloat(monthVal) || 0) + costCents;

  await Promise.all([
    env.RATE_LIMIT.put(dKey, String(newDay), { expirationTtl: 86400 * 2 }),
    env.RATE_LIMIT.put(mKey, String(newMonth), { expirationTtl: 86400 * 35 }),
  ]);
}

async function checkBudget(env) {
  if (!env.RATE_LIMIT) return null;

  const dailyLimit = parseInt(env.DAILY_BUDGET_CENTS) || 500;    // Default $5/day
  const monthlyLimit = parseInt(env.MONTHLY_BUDGET_CENTS) || 10000; // Default $100/month

  const [dayVal, monthVal] = await Promise.all([
    env.RATE_LIMIT.get(todayKey()),
    env.RATE_LIMIT.get(monthKey()),
  ]);

  const daySpend = parseFloat(dayVal) || 0;
  const monthSpend = parseFloat(monthVal) || 0;

  if (daySpend >= dailyLimit) {
    console.warn(`Daily budget exceeded: ${daySpend.toFixed(1)}¢ / ${dailyLimit}¢`);
    return jsonError("Service temporarily unavailable. Please try again tomorrow.", 503);
  }

  if (monthSpend >= monthlyLimit) {
    console.warn(`Monthly budget exceeded: ${monthSpend.toFixed(1)}¢ / ${monthlyLimit}¢`);
    return jsonError("Service temporarily unavailable. Please try again later.", 503);
  }

  return null;
}

// ── Helpers ──

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: { message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function corsResponse(response) {
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type");
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}
