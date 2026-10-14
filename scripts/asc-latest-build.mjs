// How long the newest TestFlight build of an app has left before it expires (TestFlight
// builds expire 90 days after upload). Prints one line of JSON:
//   {"app_id": "...", "latest": {"version": "...", "uploaded": "...", "expires": "...", "days_left": 41.2} | null,
//    "needed": true|false}
// where "needed" means no valid build has at least --min-days left.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=AuthKey_….p8 ASC_APP_ID=… node scripts/asc-latest-build.mjs [--min-days 30]
//
// ASC_KEY_P8_BASE64 may stand in for ASC_KEY_PATH (CI). Read-only: one GET to the
// App Store Connect API, signed with the team's API key (ES256 JWT, Node's own crypto).
import { createPrivateKey, sign } from "node:crypto";
import { readFileSync } from "node:fs";

const env = (name) => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is not set`);
  return value;
};
const minDaysArg = process.argv.indexOf("--min-days");
const minDays = minDaysArg === -1 ? 30 : Number(process.argv[minDaysArg + 1]);
if (!Number.isFinite(minDays) || minDays < 0) throw new Error("--min-days takes a number of days");

const keyId = env("ASC_KEY_ID");
const issuer = env("ASC_ISSUER_ID");
const appId = env("ASC_APP_ID");
const pem = process.env.ASC_KEY_P8_BASE64
  ? Buffer.from(process.env.ASC_KEY_P8_BASE64, "base64").toString("utf8")
  : readFileSync(env("ASC_KEY_PATH"), "utf8");

const b64url = (data) => Buffer.from(data).toString("base64url");
const now = Math.floor(Date.now() / 1000);
const unsigned = [
  b64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" })),
  b64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 15 * 60, aud: "appstoreconnect-v1" })),
].join(".");
// JWS wants the raw r||s signature, not DER.
const signature = sign("sha256", Buffer.from(unsigned), {
  key: createPrivateKey(pem),
  dsaEncoding: "ieee-p1363",
});
const token = `${unsigned}.${b64url(signature)}`;

const url = new URL("https://api.appstoreconnect.apple.com/v1/builds");
url.searchParams.set("filter[app]", appId);
url.searchParams.set("sort", "-uploadedDate");
url.searchParams.set("limit", "10");
url.searchParams.set("fields[builds]", "version,uploadedDate,expirationDate,expired,processingState");
const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
if (!response.ok) {
  throw new Error(`App Store Connect answered ${response.status}: ${(await response.text()).slice(0, 300)}`);
}
const { data } = await response.json();

const valid = data
  .map((build) => build.attributes)
  .filter((a) => !a.expired && a.processingState === "VALID" && a.expirationDate)
  .sort((a, b) => Date.parse(b.expirationDate) - Date.parse(a.expirationDate));
const best = valid[0];
const latest = best && {
  version: best.version,
  uploaded: best.uploadedDate,
  expires: best.expirationDate,
  days_left: Math.round(((Date.parse(best.expirationDate) - Date.now()) / 86_400_000) * 10) / 10,
};
console.log(JSON.stringify({ app_id: appId, latest: latest ?? null, needed: !latest || latest.days_left < minDays }));
