// Builds a fake App Attest attestation for the tests: a root, an intermediate and a credential
// certificate shaped like Apple's, made with openssl, wrapped in the same CBOR structure the device
// sends. Run from proxy/: node test/fixtures/make-attestation.mjs > test/fixtures/attestation.json
import { execFileSync } from "node:child_process";
import { createHash, createPublicKey } from "node:crypto";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const APP_ID = "TEAMID1234.com.example.duotemp";
const CHALLENGE = "test-challenge";
const dir = mkdtempSync(join(tmpdir(), "attest-"));
const at = (name) => join(dir, name);
const openssl = (...args) => execFileSync("openssl", args, { stdio: ["ignore", "pipe", "pipe"] });
const sha256 = (data) => createHash("sha256").update(data).digest();

function certificate(name, curve, subject, issuer, extensions) {
  openssl("ecparam", "-name", curve, "-genkey", "-noout", "-out", at(`${name}.key`));
  openssl("req", "-new", "-key", at(`${name}.key`), "-subj", subject, "-out", at(`${name}.csr`));
  writeFileSync(at(`${name}.ext`), extensions);
  const signer = issuer ? ["-CA", at(`${issuer}.pem`), "-CAkey", at(`${issuer}.key`), "-CAcreateserial"] : ["-signkey", at(`${name}.key`)];
  openssl("x509", "-req", "-in", at(`${name}.csr`), ...signer, "-sha384", "-days", "36500",
    "-extfile", at(`${name}.ext`), "-out", at(`${name}.pem`));
  return openssl("x509", "-in", at(`${name}.pem`), "-outform", "DER");
}

// The credential key, its ID (SHA-256 of the uncompressed public point) and authenticator data.
openssl("ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", at("cred.key"));
const spki = createPublicKey(readFileSync(at("cred.key"))).export({ type: "spki", format: "der" });
const keyId = sha256(spki.subarray(spki.length - 65));
const authData = Buffer.concat([
  sha256(APP_ID),
  Buffer.from([0x40]),
  Buffer.alloc(4),
  Buffer.from("appattestdevelop"),
  Buffer.from([0x00, 0x20]),
  keyId,
  Buffer.from([0xa0]),
]);
const nonce = sha256(Buffer.concat([authData, sha256(CHALLENGE)]));

const root = certificate("root", "secp384r1", "/CN=Test App Attestation Root CA", null,
  "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign\n");
const intermediate = certificate("intermediate", "secp384r1", "/CN=Test App Attestation CA 1", "root",
  "basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign\n");
// The credential certificate carries the nonce in Apple's extension: SEQUENCE { [1] OCTET STRING }.
const nonceExtension = Buffer.concat([Buffer.from([0x30, 0x24, 0xa1, 0x22, 0x04, 0x20]), nonce]).toString("hex");
openssl("req", "-new", "-key", at("cred.key"), "-subj", `/CN=${keyId.toString("hex")}`, "-out", at("cred.csr"));
writeFileSync(at("cred.ext"), `1.2.840.113635.100.8.2=DER:${nonceExtension.match(/../g).join(":")}\n`);
openssl("x509", "-req", "-in", at("cred.csr"), "-CA", at("intermediate.pem"), "-CAkey", at("intermediate.key"),
  "-CAcreateserial", "-sha256", "-days", "36500", "-extfile", at("cred.ext"), "-out", at("cred.pem"));
const credential = openssl("x509", "-in", at("cred.pem"), "-outform", "DER");

// Minimal CBOR encoder for the attestation object's maps, arrays, text and byte strings.
function cbor(value) {
  const head = (major, length) => length < 24 ? Buffer.from([(major << 5) | length])
    : length < 256 ? Buffer.from([(major << 5) | 24, length])
    : Buffer.from([(major << 5) | 25, length >> 8, length & 0xff]);
  if (Buffer.isBuffer(value)) return Buffer.concat([head(2, value.length), value]);
  if (typeof value === "string") return Buffer.concat([head(3, Buffer.byteLength(value)), Buffer.from(value)]);
  if (Array.isArray(value)) return Buffer.concat([head(4, value.length), ...value.map(cbor)]);
  const entries = Object.entries(value);
  return Buffer.concat([head(5, entries.length), ...entries.flatMap(([k, v]) => [cbor(k), cbor(v)])]);
}

const attestation = cbor({
  fmt: "apple-appattest",
  attStmt: { x5c: [credential, intermediate], receipt: Buffer.from("receipt") },
  authData,
});

process.stdout.write(JSON.stringify({
  appId: APP_ID,
  challenge: CHALLENGE,
  keyId: keyId.toString("base64"),
  attestation: attestation.toString("base64"),
  root: root.toString("base64"),
}, null, 2) + "\n");
