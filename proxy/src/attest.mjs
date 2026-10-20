// App Attest for the proxy: verifies that an attestation comes from duoTemp's App Store build on a real
// device (https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server),
// then issues a short-lived token the app and its widgets send with every request.
// Challenges and tokens are HMAC-signed with the ATTEST_SECRET Worker secret, so nothing is stored.

export const TOKEN_LIFETIME = 7 * 24 * 3600 * 1000;
const CHALLENGE_LIFETIME = 5 * 60 * 1000;
const NONCE_EXTENSION = "1.2.840.113635.100.8.2";
const AAGUIDS = ["appattestdevelop", "appattest\0\0\0\0\0\0\0"];

export class AttestError extends Error {}

/**
 * Throws AttestError unless `attestation` (the CBOR object from DCAppAttestService.attestKey) is valid
 * for `keyId`, `challenge` and `appId` ("TEAMID.bundle.id") and chains to `rootDer` at `now`.
 */
export async function verifyAttestation({ attestation, keyId, challenge, appId, rootDer, now }) {
  let object, credential, intermediate, root;
  try {
    object = decodeCBOR(attestation);
    if (object?.fmt !== "apple-appattest") throw new Error();
    const [credentialDer, intermediateDer] = object.attStmt.x5c;
    credential = parseCertificate(credentialDer);
    intermediate = parseCertificate(intermediateDer);
    root = parseCertificate(rootDer);
  } catch {
    throw new AttestError("malformed attestation");
  }

  for (const certificate of [credential, intermediate, root]) {
    if (now < certificate.notBefore || now > certificate.notAfter) {
      throw new AttestError("certificate not valid at this time");
    }
  }
  await verifySignature(credential, intermediate);
  await verifySignature(intermediate, root);

  const authData = object.authData;
  const nonce = await sha256(concat(authData, await sha256(new TextEncoder().encode(challenge))));
  const extension = credential.extensions.get(NONCE_EXTENSION);
  if (!extension || !equal(nonceFromExtension(extension), nonce)) {
    throw new AttestError("nonce mismatch");
  }
  if (!equal(await sha256(credential.publicPoint), keyId)) {
    throw new AttestError("key ID mismatch");
  }
  if (authData.length < 55 || !equal(authData.subarray(0, 32), await sha256(new TextEncoder().encode(appId)))) {
    throw new AttestError("app ID mismatch");
  }
  const counter = new DataView(authData.buffer, authData.byteOffset + 33, 4).getUint32(0);
  if (counter !== 0) {
    throw new AttestError("counter isn't zero");
  }
  if (!AAGUIDS.includes(new TextDecoder().decode(authData.subarray(37, 53)))) {
    throw new AttestError("unexpected App Attest environment");
  }
  const idLength = (authData[53] << 8) | authData[54];
  if (!equal(authData.subarray(55, 55 + idLength), keyId)) {
    throw new AttestError("credential ID doesn't match the key ID");
  }
}

/** A challenge for one attestation, valid for five minutes. */
export async function issueChallenge(secret, now) {
  return signed(secret, "challenge", String(now));
}

export async function checkChallenge(secret, challenge, now) {
  const issued = await verified(secret, "challenge", challenge);
  return issued !== null && now >= issued - 60_000 && now - issued < CHALLENGE_LIFETIME;
}

/** A token for the app and widgets, valid for TOKEN_LIFETIME. */
export async function issueToken(secret, now) {
  const expires = now + TOKEN_LIFETIME;
  return { token: await signed(secret, "token", String(expires)), expires };
}

export async function checkToken(secret, token, now) {
  const expires = await verified(secret, "token", token);
  return expires !== null && now < expires;
}

// MARK: - Signed values: "<value>.<base64url HMAC-SHA256 of purpose.value>"

async function hmacKey(secret) {
  return crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}

async function signed(secret, purpose, value) {
  const mac = await crypto.subtle.sign("HMAC", await hmacKey(secret), new TextEncoder().encode(`${purpose}.${value}`));
  return `${value}.${base64url(new Uint8Array(mac))}`;
}

/** The value as a number when the signature is valid, else null. Uses HMAC verify, which is constant time. */
async function verified(secret, purpose, text) {
  const match = /^(\d{1,16})\.([A-Za-z0-9_-]{43})$/.exec(text ?? "");
  if (!match) return null;
  const mac = fromBase64url(match[2]);
  const ok = await crypto.subtle.verify("HMAC", await hmacKey(secret), mac, new TextEncoder().encode(`${purpose}.${match[1]}`));
  return ok ? Number(match[1]) : null;
}

function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64url(text) {
  return Uint8Array.from(atob(text.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
}

// MARK: - Certificates

const CURVES = { "1.2.840.10045.3.1.7": ["P-256", 32], "1.3.132.0.34": ["P-384", 48] };
const HASHES = { "1.2.840.10045.4.3.2": "SHA-256", "1.2.840.10045.4.3.3": "SHA-384" };

/** Checks that `issuer` signed `certificate` and is named as its issuer. */
async function verifySignature(certificate, issuer) {
  const curve = CURVES[issuer.curve];
  const hash = HASHES[certificate.signatureAlgorithm];
  if (!curve || !hash || !equal(certificate.issuer, issuer.subject)) {
    throw new AttestError("certificate signature doesn't chain");
  }
  const key = await crypto.subtle.importKey("spki", issuer.spki, { name: "ECDSA", namedCurve: curve[0] }, false, ["verify"]);
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash }, key, rawSignature(certificate.signature, curve[1]), certificate.tbs);
  if (!ok) throw new AttestError("certificate signature doesn't chain");
}

/** DER ECDSA-Sig-Value (SEQUENCE of two INTEGERs) to the r || s form WebCrypto expects. */
function rawSignature(der, size) {
  const [r, s] = children(der, read(der, 0));
  const fixed = (integer) => {
    let value = der.subarray(integer.content, integer.end);
    while (value.length > size && value[0] === 0) value = value.subarray(1);
    const out = new Uint8Array(size);
    out.set(value, size - value.length);
    return out;
  };
  return concat(fixed(r), fixed(s));
}

/** The fields of an X.509 certificate the checks need. */
function parseCertificate(der) {
  const [tbsNode, algorithmNode, signatureNode] = children(der, read(der, 0));
  let fields = children(der, tbsNode);
  if (fields[0].tag === 0xa0) fields = fields.slice(1);
  const [, , issuer, validity, subject, spki, ...rest] = fields;
  const [notBefore, notAfter] = children(der, validity).map((node) => time(der, node));
  const [keyAlgorithm, keyBits] = children(der, spki);
  const [, curveNode] = children(der, keyAlgorithm);

  const extensions = new Map();
  const extensionsNode = rest.find((node) => node.tag === 0xa3);
  if (extensionsNode) {
    for (const extension of children(der, children(der, extensionsNode)[0])) {
      const parts = children(der, extension);
      const value = parts[parts.length - 1];
      extensions.set(oid(der, parts[0]), der.subarray(value.content, value.end));
    }
  }
  return {
    tbs: der.subarray(tbsNode.start, tbsNode.end),
    signatureAlgorithm: oid(der, children(der, algorithmNode)[0]),
    signature: der.subarray(signatureNode.content + 1, signatureNode.end),
    issuer: der.subarray(issuer.start, issuer.end),
    subject: der.subarray(subject.start, subject.end),
    notBefore,
    notAfter,
    spki: der.subarray(spki.start, spki.end),
    curve: oid(der, curveNode),
    publicPoint: der.subarray(keyBits.content + 1, keyBits.end),
    extensions,
  };
}

/** Apple's nonce extension: SEQUENCE { [1] EXPLICIT OCTET STRING }. */
function nonceFromExtension(value) {
  const [tagged] = children(value, read(value, 0));
  const [octets] = children(value, tagged);
  return value.subarray(octets.content, octets.end);
}

// MARK: - DER

/** One TLV at `offset`: its tag, where it starts, where its content starts and where it ends. */
function read(bytes, offset) {
  const tag = bytes[offset];
  let length = bytes[offset + 1];
  let content = offset + 2;
  if (length & 0x80) {
    const count = length & 0x7f;
    if (count === 0 || count > 4) throw new Error("bad DER length");
    length = 0;
    for (let i = 0; i < count; i++) length = length * 256 + bytes[content + i];
    content += count;
  }
  const end = content + length;
  if (tag === undefined || end > bytes.length) throw new Error("truncated DER");
  return { tag, start: offset, content, end };
}

function children(bytes, node) {
  const nodes = [];
  for (let offset = node.content; offset < node.end;) {
    const child = read(bytes, offset);
    nodes.push(child);
    offset = child.end;
  }
  return nodes;
}

function oid(bytes, node) {
  const body = bytes.subarray(node.content, node.end);
  const parts = [Math.floor(body[0] / 40), body[0] % 40];
  let value = 0;
  for (const byte of body.subarray(1)) {
    value = value * 128 + (byte & 0x7f);
    if (!(byte & 0x80)) {
      parts.push(value);
      value = 0;
    }
  }
  return parts.join(".");
}

/** UTCTime (YYMMDDHHMMSSZ) or GeneralizedTime (YYYYMMDDHHMMSSZ) as milliseconds. */
function time(bytes, node) {
  let text = new TextDecoder().decode(bytes.subarray(node.content, node.end));
  if (node.tag === 0x17) text = (Number(text.slice(0, 2)) < 50 ? "20" : "19") + text;
  const [, y, mo, d, h, mi, s] = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(text);
  return Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s));
}

// MARK: - CBOR (the subset attestation objects use)

function decodeCBOR(bytes) {
  let offset = 0;
  const length = (info) => {
    if (info < 24) return info;
    const size = { 24: 1, 25: 2, 26: 4, 27: 8 }[info];
    if (!size) throw new Error("unsupported CBOR length");
    let value = 0;
    for (let i = 0; i < size; i++) value = value * 256 + bytes[offset++];
    return value;
  };
  const item = () => {
    if (offset >= bytes.length) throw new Error("truncated CBOR");
    const initial = bytes[offset++];
    const major = initial >> 5;
    const value = length(initial & 0x1f);
    switch (major) {
      case 0: return value;
      case 1: return -1 - value;
      case 2: case 3: {
        if (offset + value > bytes.length) throw new Error("truncated CBOR");
        const slice = bytes.subarray(offset, offset + value);
        offset += value;
        return major === 2 ? slice : new TextDecoder().decode(slice);
      }
      case 4: return Array.from({ length: value }, item);
      case 5: {
        const map = {};
        for (let i = 0; i < value; i++) map[item()] = item();
        return map;
      }
      case 6: return item();
      default: throw new Error("unsupported CBOR type");
    }
  };
  return item();
}

// MARK: - Bytes

async function sha256(bytes) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

function concat(...parts) {
  const out = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

function equal(a, b) {
  return a.length === b.length && a.every((byte, i) => byte === b[i]);
}
