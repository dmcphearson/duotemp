import { test } from "node:test";
import assert from "node:assert/strict";
import { handle, route, ttlFromExpires, USER_AGENT } from "../src/proxy.mjs";

/** An in-memory stand-in for the Workers cache. */
function memoryCache() {
  const entries = new Map();
  return {
    entries,
    async match(request) {
      return entries.get(request.url)?.clone();
    },
    async put(request, response) {
      entries.set(request.url, response);
    },
  };
}

function upstream(status, body, headers = {}) {
  const calls = [];
  const fetchUpstream = async (url, init) => {
    calls.push({ url, init });
    return new Response(body, { status, headers });
  };
  return { calls, fetchUpstream };
}

const NOW = Date.parse("2026-10-17T20:00:00Z");
const get = (path) => new Request(`https://api.trough.dev${path}`);

test("forecast requests reach MET with rounded coordinates and duoTemp's User-Agent", async () => {
  const cache = memoryCache();
  const { calls, fetchUpstream } = upstream(200, "{}", { Expires: "Sat, 17 Oct 2026 20:30:00 GMT" });
  const response = await handle(get("/met/locationforecast/2.0/complete?lat=53.34981&lon=-6.26031"), {
    cache, fetchUpstream, now: NOW, waitUntil: (p) => p,
  });
  assert.equal(response.status, 200);
  assert.equal(calls[0].url, "https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=53.35&lon=-6.26");
  assert.equal(calls[0].init.headers["User-Agent"], USER_AGENT);
  assert.equal(response.headers.get("Cache-Control"), "public, max-age=1800");
});

test("a second request for the same rounded spot comes from the cache", async () => {
  const cache = memoryCache();
  const { calls, fetchUpstream } = upstream(200, "{}", { Expires: "Sat, 17 Oct 2026 20:30:00 GMT" });
  const deps = { cache, fetchUpstream, now: NOW, waitUntil: (p) => p };
  await handle(get("/met/locationforecast/2.0/complete?lat=53.351&lon=-6.261"), deps);
  const second = await handle(get("/met/locationforecast/2.0/complete?lon=-6.26&lat=53.35"), deps);
  assert.equal(calls.length, 1);
  assert.equal(second.headers.get("X-Cache"), "HIT");
});

test("sunrise requests keep date and offset and validate them", async () => {
  const { calls, fetchUpstream } = upstream(200, "{}", { Expires: "Sat, 17 Oct 2026 21:00:00 GMT" });
  const deps = { cache: memoryCache(), fetchUpstream, now: NOW };
  const ok = await handle(get("/met/sunrise/3.0/sun?lat=53.35&lon=-6.26&date=2026-10-17&offset=%2B01:00"), deps);
  assert.equal(ok.status, 200);
  assert.equal(calls[0].url, "https://api.met.no/weatherapi/sunrise/3.0/sun?lat=53.35&lon=-6.26&date=2026-10-17&offset=%2B01%3A00");
  const bad = await handle(get("/met/sunrise/3.0/sun?lat=53.35&lon=-6.26&date=tomorrow&offset=%2B01:00"), deps);
  assert.equal(bad.status, 400);
});

test("aurora files map to GFZ and NOAA and cache for half an hour", async () => {
  const { calls, fetchUpstream } = upstream(200, "csv", { "Content-Type": "text/csv" });
  const response = await handle(get("/aurora/gfz"), { cache: memoryCache(), fetchUpstream, now: NOW });
  assert.match(calls[0].url, /^https:\/\/spaceweather\.gfz\.de\//);
  assert.equal(response.headers.get("Cache-Control"), "public, max-age=1800");
  assert.equal(route(new URL("https://api.trough.dev/aurora/noaa")).upstream,
    "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json");
});

/** Answers with "v1", "v2"… so tests can tell copies apart; `failing` makes later calls throw. */
function versions() {
  let n = 0;
  const state = { failing: false, calls: 0 };
  state.fetchUpstream = async () => {
    state.calls += 1;
    if (state.failing) throw new Error("down");
    n += 1;
    return new Response(`v${n}`, { status: 200, headers: { "Content-Type": "text/csv" } });
  };
  return state;
}

test("an aurora file older than half an hour is served at once while a fresh copy is fetched", async () => {
  const cache = memoryCache();
  const source = versions();
  const pending = [];
  const deps = (now) => ({ cache, fetchUpstream: source.fetchUpstream, now, waitUntil: (p) => pending.push(p) });

  assert.equal(await (await handle(get("/aurora/gfz"), deps(NOW))).text(), "v1");
  await Promise.all(pending.splice(0));
  const stale = await handle(get("/aurora/gfz"), deps(NOW + 31 * 60_000));
  assert.equal(stale.headers.get("X-Cache"), "STALE");
  assert.equal(stale.headers.get("Cache-Control"), "public, max-age=1800");
  assert.equal(stale.headers.get("X-Fetched-At"), null);
  assert.equal(await stale.text(), "v1");
  await Promise.all(pending.splice(0));
  const fresh = await handle(get("/aurora/gfz"), deps(NOW + 32 * 60_000));
  assert.equal(fresh.headers.get("X-Cache"), "HIT");
  assert.equal(await fresh.text(), "v2");
  assert.equal(source.calls, 2);
});

test("a stale aurora file stays when the refresh fails, until it is six hours old", async () => {
  const cache = memoryCache();
  const source = versions();
  const pending = [];
  const deps = (now) => ({ cache, fetchUpstream: source.fetchUpstream, now, waitUntil: (p) => pending.push(p) });

  await handle(get("/aurora/gfz"), deps(NOW));
  await Promise.all(pending.splice(0));
  source.failing = true;
  const stale = await handle(get("/aurora/gfz"), deps(NOW + 5 * 3600_000));
  assert.equal(await stale.text(), "v1");
  await Promise.all(pending.splice(0));
  assert.equal((await handle(get("/aurora/gfz"), deps(NOW + 7 * 3600_000))).status, 502);
});

test("anything else is refused without reaching upstream", async () => {
  const { calls, fetchUpstream } = upstream(200, "{}");
  const deps = { cache: memoryCache(), fetchUpstream, now: NOW };
  for (const path of ["/", "/met/locationforecast/2.0/compact?lat=1&lon=1", "/met/../../etc", "/https://evil.example/"]) {
    assert.equal((await handle(get(path), deps)).status, 404, path);
  }
  for (const query of ["lat=91&lon=0", "lat=0&lon=181", "lat=abc&lon=0", "lon=0"]) {
    assert.equal((await handle(get(`/met/locationforecast/2.0/complete?${query}`), deps)).status, 400, query);
  }
  const post = new Request("https://api.trough.dev/aurora/gfz", { method: "POST" });
  assert.equal((await handle(post, deps)).status, 405);
  assert.equal(calls.length, 0);
});

test("upstream errors pass through and are never cached", async () => {
  const cache = memoryCache();
  const { fetchUpstream } = upstream(429, "slow down");
  const response = await handle(get("/met/locationforecast/2.0/complete?lat=1&lon=1"), { cache, fetchUpstream, now: NOW });
  assert.equal(response.status, 429);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(cache.entries.size, 0);
  const failing = { cache, fetchUpstream: async () => { throw new Error("down"); }, now: NOW };
  assert.equal((await handle(get("/aurora/noaa"), failing)).status, 502);
});

test("cache lifetime follows MET's Expires within bounds", () => {
  assert.equal(ttlFromExpires("Sat, 17 Oct 2026 20:10:00 GMT", NOW), 600);
  assert.equal(ttlFromExpires("Sat, 17 Oct 2026 19:00:00 GMT", NOW), 60);
  assert.equal(ttlFromExpires("Mon, 19 Oct 2026 20:00:00 GMT", NOW), 6 * 3600);
  assert.equal(ttlFromExpires(null, NOW), 60);
});
