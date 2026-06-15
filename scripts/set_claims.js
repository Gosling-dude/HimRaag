/**
 * Grant/revoke HimRaag dashboard access via Firebase Auth custom claims.
 *
 * The Flutter Web admin app gates access on these claims:
 *   - { admin: true }      → full admin dashboard
 *   - { role: 'artist' }   → artist dashboard (own profile + submissions)
 *
 * The Firestore security rules enforce the same claims server-side.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json \
 *     node scripts/set_claims.js --email user@example.com --role admin
 *   ... --role artist            (grant artist role)
 *   ... --role none              (revoke all claims)
 *
 * The target user must already exist in Firebase Auth. After running, the user
 * must sign out/in (or refresh their ID token) for the claim to take effect.
 */

'use strict';

const fs = require('fs');
const { PROJECT_ID } = require('./lib/constants');

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

async function main() {
  const email = arg('--email');
  const role = arg('--role');
  if (!email || !['admin', 'artist', 'none'].includes(role)) {
    console.error('Usage: node scripts/set_claims.js --email <email> --role <admin|artist|none>');
    process.exit(1);
  }
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!saPath) {
    console.error('ERROR: set GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON.');
    process.exit(1);
  }

  const { initializeApp, cert } = require('firebase-admin/app');
  const { getAuth } = require('firebase-admin/auth');
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const auth = getAuth();

  const user = await auth.getUserByEmail(email);
  let claims;
  if (role === 'admin') claims = { admin: true };
  else if (role === 'artist') claims = { role: 'artist' };
  else claims = null; // revoke

  await auth.setCustomUserClaims(user.uid, claims);
  console.log(`✅ Set claims for ${email} (uid=${user.uid}): ${JSON.stringify(claims)}`);
  console.log('   The user must sign out and back in for the claim to take effect.');
}

main().catch((err) => {
  console.error('Failed:', err.message);
  process.exit(1);
});
