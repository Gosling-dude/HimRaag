/**
 * HISTORICAL / SUPERSEDED — 2026-07-03 fix for the old package `com.himraag.app`.
 *
 * The production package is now `com.sumitchauhan.himraag` (migrated
 * 2026-08-12; see the Firebase Android app "HimRaag (Play)",
 * 1:39471021909:android:ce23c0c346997c9bf7b9dc). The PACKAGE/CERTS constants
 * below are left exactly as they were run historically — do not re-run this
 * script as-is, it would register the wrong (old, already-superseded)
 * fingerprints against the wrong package. The current upload key's SHA-1/
 * SHA-256 were registered against the new app directly via
 * `firebase apps:android:sha:create`, not via this script.
 *
 * Original description follows, kept for reference:
 *
 * Fix Google Sign-In config for com.himraag.app (ApiException: 10).
 *
 * Root cause: no SHA certificates registered on the Firebase Android app, so
 * google-services.json ships with an empty oauth_client[] and Google Sign-In
 * fails with DEVELOPER_ERROR (10).
 *
 * This script uses the Firebase Management API + Identity Toolkit Admin API
 * (service account from .env/) to:
 *   1. register debug + release SHA-1/SHA-256 fingerprints
 *   2. ensure the Google sign-in provider is enabled
 *   3. re-download google-services.json with populated oauth_client entries
 *
 * Usage: node scripts/fix_signin_config.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { GoogleAuth } = require('google-auth-library');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const PROJECT_ID = 'himraag-prod';
const PACKAGE = 'com.himraag.app';
const OUT = path.resolve(__dirname, '..', 'android', 'app', 'google-services.json');

// keystore fingerprints (colons stripped below). SHA hashes are public identifiers, not secrets.
const CERTS = [
  { label: 'debug SHA-1', type: 'SHA_1', hash: '10:02:F8:83:9C:32:BD:9F:B0:20:89:8C:40:8C:87:52:A1:27:A2:B3' },
  { label: 'debug SHA-256', type: 'SHA_256', hash: 'BF:E3:4F:7F:6E:AF:7C:BB:DD:3F:47:A3:CF:1F:01:75:61:9C:E9:3E:9F:ED:12:A9:AD:87:7F:61:66:26:EF:ED' },
  { label: 'release SHA-1', type: 'SHA_1', hash: 'C0:EB:64:DD:8A:CD:32:48:8C:B0:3A:47:CF:EC:EA:A0:EA:E9:34:05' },
  { label: 'release SHA-256', type: 'SHA_256', hash: '68:67:C2:7A:1C:FB:46:11:D3:F9:BB:98:DE:25:5E:42:A8:47:99:79:5B:A2:39:75:09:94:B0:2A:34:F4:91:78' },
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const auth = new GoogleAuth({
    keyFile: firebaseServiceAccountPath(),
    scopes: [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/firebase',
    ],
  });
  const client = await auth.getClient();
  const req = async (opts) => {
    try {
      const res = await client.request(opts);
      return { status: res.status, data: res.data };
    } catch (e) {
      return { status: e.response ? e.response.status : 0, data: e.response ? e.response.data : String(e) };
    }
  };

  const base = `https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}`;

  // 1. locate the android app
  const apps = await req({ url: `${base}/androidApps` });
  if (apps.status !== 200) throw new Error(`androidApps list failed: ${JSON.stringify(apps.data)}`);
  const app = (apps.data.apps || []).find((a) => a.packageName === PACKAGE);
  if (!app) throw new Error(`No Firebase Android app with package ${PACKAGE}`);
  console.log(`Android app: ${app.appId} (${app.packageName})`);

  // 2. register missing SHA certs
  const shaList = await req({ url: `https://firebase.googleapis.com/v1beta1/${app.name}/sha` });
  const existing = new Set(((shaList.data && shaList.data.certificates) || []).map((c) => c.shaHash.toLowerCase()));
  console.log(`Existing SHA certs: ${existing.size}`);
  for (const c of CERTS) {
    const hash = c.hash.replace(/:/g, '').toLowerCase();
    if (existing.has(hash)) {
      console.log(`  = ${c.label}: already registered`);
      continue;
    }
    const add = await req({
      url: `https://firebase.googleapis.com/v1beta1/${app.name}/sha`,
      method: 'POST',
      data: { shaHash: hash, certType: c.type },
    });
    console.log(`  ${add.status === 200 ? '+' : '!'} ${c.label}: ${add.status === 200 ? 'registered' : JSON.stringify(add.data)}`);
  }

  // 3. ensure Google provider is enabled in Firebase Auth
  const idpUrl = `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/defaultSupportedIdpConfigs/google.com`;
  const idp = await req({ url: idpUrl });
  if (idp.status === 200 && idp.data.enabled) {
    console.log('Google provider: already enabled');
  } else if (idp.status === 200) {
    const upd = await req({ url: `${idpUrl}?updateMask=enabled`, method: 'PATCH', data: { enabled: true } });
    console.log(`Google provider: enable via PATCH -> ${upd.status}${upd.status !== 200 ? ' ' + JSON.stringify(upd.data) : ''}`);
  } else {
    const crt = await req({
      url: `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/defaultSupportedIdpConfigs?idpId=google.com`,
      method: 'POST',
      data: { enabled: true },
    });
    console.log(`Google provider: create -> ${crt.status}${crt.status !== 200 ? ' ' + JSON.stringify(crt.data) : ''}`);
  }

  // 4. poll for a config that contains oauth clients (provisioning can lag)
  let cfg = null;
  for (let i = 0; i < 12; i++) {
    const res = await req({ url: `https://firebase.googleapis.com/v1beta1/${app.name}/config` });
    if (res.status !== 200) throw new Error(`getConfig failed: ${JSON.stringify(res.data)}`);
    cfg = JSON.parse(Buffer.from(res.data.configFileContents, 'base64').toString('utf8'));
    const clients = ((cfg.client || [])[0] || {}).oauth_client || [];
    const hasWeb = clients.some((c) => c.client_type === 3);
    const hasAndroid = clients.some((c) => c.client_type === 1);
    console.log(`config poll ${i + 1}: oauth_client=${clients.length} (android=${hasAndroid}, web=${hasWeb})`);
    if (hasWeb) break;
    await sleep(10000);
  }

  fs.writeFileSync(OUT, JSON.stringify(cfg, null, 2));
  console.log(`Wrote ${OUT}`);
  const clients = ((cfg.client || [])[0] || {}).oauth_client || [];
  console.log(`Final oauth_client entries: ${clients.length}`);
  clients.forEach((c) => console.log(`  type=${c.client_type} id=${c.client_id}`));
}

main().catch((e) => { console.error(e); process.exit(1); });
