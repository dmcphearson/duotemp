import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  checkChallenge, checkToken, issueChallenge, issueToken, verifyAttestation, TOKEN_LIFETIME,
} from "../src/attest.mjs";
import { handle } from "../src/proxy.mjs";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/attestation.json", import.meta.url)));
const bytes = (base64) => Uint8Array.from(Buffer.from(base64, "base64"));
const NOW = Date.parse("2026-10-20T12:00:00Z");
const SECRET = "test-secret-not-used-anywhere-else";

function attestation(overrides = {}) {
  return {
    attestation: bytes(fixture.attestation),
    keyId: bytes(fixture.keyId),
    challenge: fixture.challenge,
    appId: fixture.appId,
    rootDer: bytes(fixture.root),
    now: NOW,
    ...overrides,
  };
}

test("a well-formed attestation chained to the root verifies", async () => {
  await verifyAttestation(attestation());
});

test("an attestation for another app is rejected", async () => {
  await assert.rejects(verifyAttestation(attestation({ appId: "OTHERTEAM.com.example.fork" })), /app ID/);
});

test("an attestation for another challenge is rejected", async () => {
  await assert.rejects(verifyAttestation(attestation({ challenge: "replayed" })), /nonce/);
});

test("an attestation for another key is rejected", async () => {
  await assert.rejects(verifyAttestation(attestation({ keyId: new Uint8Array(32) })), /key ID/);
});

test("a chain that doesn't end at the trusted root is rejected", async () => {
  const appleRoot = readFileSync(new URL("../src/apple-root.mjs", import.meta.url), "utf8").match(/"([A-Za-z0-9+/=]+)"/)[1];
  await assert.rejects(verifyAttestation(attestation({ rootDer: bytes(appleRoot) })), /signature/);
});

test("an expired certificate is rejected", async () => {
  await assert.rejects(verifyAttestation(attestation({ now: Date.parse("2200-01-01T00:00:00Z") })), /valid/);
});

test("garbage is rejected, not thrown as a crash", async () => {
  await assert.rejects(verifyAttestation(attestation({ attestation: new Uint8Array([1, 2, 3]) })), /attestation/);
});

test("challenges verify for five minutes and only with the secret", async () => {
  const challenge = await issueChallenge(SECRET, NOW);
  assert.equal(await checkChallenge(SECRET, challenge, NOW + 4 * 60_000), true);
  assert.equal(await checkChallenge(SECRET, challenge, NOW + 6 * 60_000), false);
  assert.equal(await checkChallenge("other-secret", challenge, NOW), false);
  assert.equal(await checkChallenge(SECRET, challenge.replace(/^./, "9"), NOW), false);
});

test("tokens verify until they expire and only with the secret", async () => {
  const { token, expires } = await issueToken(SECRET, NOW);
  assert.equal(expires, NOW + TOKEN_LIFETIME);
  assert.equal(await checkToken(SECRET, token, NOW + TOKEN_LIFETIME - 1), true);
  assert.equal(await checkToken(SECRET, token, NOW + TOKEN_LIFETIME), false);
  assert.equal(await checkToken("other-secret", token, NOW), false);
  assert.equal(await checkToken(SECRET, `${token}x`, NOW), false);
  assert.equal(await checkToken(SECRET, "", NOW), false);
});

// The full flow through the proxy, with the fixture's root and app ID standing in for Apple's.
function deps(mode, overrides = {}) {
  const logs = [];
  const counted = [];
  return {
    logs,
    counted,
    cache: { async match() {}, async put() {} },
    fetchUpstream: async () => new Response("{}", { status: 200, headers: { Expires: "Tue, 20 Oct 2026 12:30:00 GMT" } }),
    now: NOW,
    waitUntil: (p) => p,
    attest: { secret: SECRET, appId: fixture.appId, mode, rootDer: bytes(fixture.root), log: (line) => logs.push(line), count: (point) => counted.push(point) },
    ...overrides,
  };
}
const forecast = (token) => new Request("https://api.trough.dev/met/locationforecast/2.0/complete?lat=59.91&lon=10.75",
  token ? { headers: { "X-Duotemp-Token": token } } : {});

async function attestThroughProxy(d) {
  const challengeResponse = await handle(new Request("https://api.trough.dev/attest/challenge"), d);
  assert.equal(challengeResponse.status, 200);
  const { challenge } = await challengeResponse.json();
  assert.ok(await checkChallenge(SECRET, challenge, NOW));
  // The fixture was made for a fixed challenge, so post that one with a challenge check that accepts it.
  return handle(new Request("https://api.trough.dev/attest", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ keyId: fixture.keyId, attestation: fixture.attestation, challenge: fixture.challenge }),
  }), { ...d, attest: { ...d.attest, checkChallenge: async (c) => c === fixture.challenge } });
}

test("the proxy issues a token for a valid attestation", async () => {
  const d = deps("enforce");
  const response = await attestThroughProxy(d);
  assert.equal(response.status, 200);
  const { token, expires } = await response.json();
  assert.equal(expires, NOW + TOKEN_LIFETIME);
  assert.equal(await checkToken(SECRET, token, NOW), true);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
});

test("the proxy refuses an attestation for an unknown challenge", async () => {
  const d = deps("enforce");
  const response = await handle(new Request("https://api.trough.dev/attest", {
    method: "POST",
    body: JSON.stringify({ keyId: fixture.keyId, attestation: fixture.attestation, challenge: "made-up" }),
  }), d);
  assert.equal(response.status, 401);
});

test("log mode serves requests without a token and records them", async () => {
  const d = deps("log");
  assert.equal((await handle(forecast(), d)).status, 200);
  assert.equal((await handle(forecast("bad"), d)).status, 200);
  const { token } = await issueToken(SECRET, NOW);
  assert.equal((await handle(forecast(token), d)).status, 200);
  assert.deepEqual(d.logs, ["[duotemp-proxy] token missing", "[duotemp-proxy] token invalid", "[duotemp-proxy] token valid"]);
});

test("each token check is counted with its status and nothing from the request", async () => {
  const d = deps("enforce");
  await handle(forecast(), d);
  await handle(forecast("bad"), d);
  const { token } = await issueToken(SECRET, NOW);
  await handle(forecast(token), d);
  assert.deepEqual(d.counted, ["missing", "invalid", "valid"].map((status) => ({ blobs: [status], indexes: [status] })));
});

test("enforce mode refuses requests without a valid token", async () => {
  const d = deps("enforce");
  assert.equal((await handle(forecast(), d)).status, 401);
  assert.equal((await handle(forecast("bad"), d)).status, 401);
  const { token } = await issueToken(SECRET, NOW);
  assert.equal((await handle(forecast(token), d)).status, 200);
});

test("without a secret the attest endpoints are unavailable and requests still pass", async () => {
  const d = deps("enforce", {});
  d.attest = { ...d.attest, secret: undefined };
  assert.equal((await handle(new Request("https://api.trough.dev/attest/challenge"), d)).status, 503);
  assert.equal((await handle(forecast(), d)).status, 200);
});
