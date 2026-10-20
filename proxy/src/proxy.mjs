// duoTemp's caching proxy for MET Norway and the aurora Kp forecasts.
// Only a fixed set of upstream URLs can be reached; coordinates are rounded to 2 decimals so nearby
// requests share one cache entry; every upstream request carries duoTemp's User-Agent and contact,
// and never the user's IP address.

import { checkChallenge, checkToken, issueChallenge, issueToken, verifyAttestation, AttestError } from "./attest.mjs";
import { APPLE_APP_ATTEST_ROOT } from "./apple-root.mjs";

export const USER_AGENT = "duoTemp/0.1 api@trough.dev";
export const TOKEN_HEADER = "X-Duotemp-Token";
const MAX_ATTEST_BODY = 64 * 1024;

const MET = "https://api.met.no/weatherapi";
const AURORA = {
  "/aurora/gfz": "https://spaceweather.gfz.de/fileadmin/Kp-Forecast/CSV/kp_product_file_FORECAST_PAGER_SWIFT_LAST.csv",
  "/aurora/noaa": "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json",
};

// MET sets Expires on every response; keep its own lifetime within sensible bounds.
const MIN_TTL = 60;
const MAX_TTL = 6 * 3600;
// The Kp forecasts update every few hours; half an hour matches the app's own memo.
const AURORA_TTL = 30 * 60;

/** The upstream URL for a request, or an error response when the request isn't one the app makes. */
export function route(url) {
  const path = url.pathname.replace(/\/+$/, "");
  if (AURORA[path]) {
    return { upstream: AURORA[path], ttl: AURORA_TTL };
  }
  if (path === "/met/locationforecast/2.0/complete" || path === "/met/sunrise/3.0/sun") {
    const lat = coordinate(url.searchParams.get("lat"), 90);
    const lon = coordinate(url.searchParams.get("lon"), 180);
    if (lat === null || lon === null) {
      return { error: 400, message: "lat and lon must be numbers in range" };
    }
    const query = new URLSearchParams({ lat, lon });
    if (path.endsWith("/sun")) {
      const date = url.searchParams.get("date");
      const offset = url.searchParams.get("offset");
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? "") || !/^[+-]\d{2}:\d{2}$/.test(offset ?? "")) {
        return { error: 400, message: "date must be YYYY-MM-DD and offset +HH:MM" };
      }
      query.set("date", date);
      query.set("offset", offset);
    }
    return { upstream: `${MET}${path.slice("/met".length)}?${query}`, ttl: null };
  }
  return { error: 404, message: "not found" };
}

/** A coordinate rounded to 2 decimals, or null when it's missing or out of range. */
function coordinate(value, limit) {
  if (value === null || value.trim() === "") return null;
  const number = Number(value);
  if (!Number.isFinite(number) || Math.abs(number) > limit) return null;
  return number.toFixed(2);
}

/** Seconds until MET's Expires header, kept between MIN_TTL and MAX_TTL. */
export function ttlFromExpires(expires, now) {
  const at = Date.parse(expires ?? "");
  if (Number.isNaN(at)) return MIN_TTL;
  return Math.min(Math.max(Math.round((at - now) / 1000), MIN_TTL), MAX_TTL);
}

/**
 * Handles one request. `deps` supplies the cache, the upstream fetch and the clock, so tests can
 * run it without Cloudflare.
 */
export async function handle(request, { cache, fetchUpstream, now = Date.now(), waitUntil = () => {}, attest = {} }) {
  const url = new URL(request.url);
  if (url.pathname === "/attest/challenge" || url.pathname === "/attest") {
    return handleAttest(request, url, attest, now);
  }
  if (request.method !== "GET" && request.method !== "HEAD") {
    return json(405, "only GET and HEAD");
  }
  const target = route(url);
  if (target.error) {
    return json(target.error, target.message);
  }

  // Without a secret, tokens can't be checked, so requests pass as before.
  if (attest.secret) {
    const token = request.headers.get(TOKEN_HEADER);
    const status = !token ? "missing" : (await checkToken(attest.secret, token, now)) ? "valid" : "invalid";
    attest.log?.(`[duotemp-proxy] token ${status}`);
    if (attest.mode === "enforce" && status !== "valid") {
      return json(401, "a valid app token is required");
    }
  }

  // One cache entry per upstream URL, whatever order or precision the query arrived in.
  const key = new Request(`${url.origin}/cache?u=${encodeURIComponent(target.upstream)}`);
  const cached = await cache.match(key);
  if (cached) {
    return withHeader(cached, "X-Cache", "HIT");
  }

  let upstream;
  try {
    upstream = await fetchUpstream(target.upstream, {
      headers: { "User-Agent": USER_AGENT, Accept: "application/json, text/csv;q=0.9, */*;q=0.1" },
    });
  } catch {
    return json(502, "upstream unreachable");
  }

  const headers = new Headers({ "X-Cache": "MISS" });
  for (const name of ["Content-Type", "Expires", "Last-Modified"]) {
    const value = upstream.headers.get(name);
    if (value) headers.set(name, value);
  }

  // 200 is normal; 203 is MET's notice that an endpoint is deprecated, still with a valid body.
  if (upstream.status !== 200 && upstream.status !== 203) {
    headers.set("Cache-Control", "no-store");
    return new Response(upstream.body, { status: upstream.status, headers });
  }

  const ttl = target.ttl ?? ttlFromExpires(upstream.headers.get("Expires"), now);
  headers.set("Cache-Control", `public, max-age=${ttl}`);
  const response = new Response(upstream.body, { status: upstream.status, headers });
  waitUntil(cache.put(key, response.clone()));
  return response;
}

/**
 * GET /attest/challenge returns a challenge; POST /attest with { keyId, attestation, challenge } (base64)
 * returns { token, expires } when the attestation is from the app named by `attest.appId`.
 */
async function handleAttest(request, url, attest, now) {
  if (!attest.secret || !attest.appId) {
    return json(503, "app attestation isn't configured");
  }
  if (url.pathname === "/attest/challenge") {
    if (request.method !== "GET") return json(405, "only GET");
    return body(200, { challenge: await issueChallenge(attest.secret, now) });
  }
  if (request.method !== "POST") return json(405, "only POST");

  let keyId, attestation, challenge;
  try {
    const text = await request.text();
    if (text.length > MAX_ATTEST_BODY) return json(413, "too large");
    ({ keyId, attestation, challenge } = JSON.parse(text));
    keyId = Uint8Array.from(atob(keyId), (c) => c.charCodeAt(0));
    attestation = Uint8Array.from(atob(attestation), (c) => c.charCodeAt(0));
    if (typeof challenge !== "string") throw new Error();
  } catch {
    return json(400, "expected JSON with base64 keyId and attestation, and a challenge");
  }
  const challengeIsValid = attest.checkChallenge ?? ((value) => checkChallenge(attest.secret, value, now));
  if (!(await challengeIsValid(challenge))) {
    return json(401, "unknown or expired challenge");
  }
  try {
    const rootDer = attest.rootDer ?? Uint8Array.from(atob(APPLE_APP_ATTEST_ROOT), (c) => c.charCodeAt(0));
    await verifyAttestation({ attestation, keyId, challenge, appId: attest.appId, rootDer, now });
  } catch (error) {
    if (!(error instanceof AttestError)) throw error;
    attest.log?.(`[duotemp-proxy] attestation refused: ${error.message}`);
    return json(401, "attestation refused");
  }
  attest.log?.("[duotemp-proxy] attestation accepted");
  return body(200, await issueToken(attest.secret, now));
}

function body(status, value) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function json(status, message) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function withHeader(response, name, value) {
  const copy = new Response(response.body, response);
  copy.headers.set(name, value);
  return copy;
}
