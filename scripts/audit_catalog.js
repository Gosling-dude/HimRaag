'use strict';
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const { PROJECT_ID } = require('./lib/constants');
const { firebaseServiceAccountPath } = require('./lib/credentials');

function reachable(u){ return u && /^https?:\/\//.test(u); }

async function main() {
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath,'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();
  const out = { songs: [], artists: [], albums: [] };
  for (const c of Object.keys(out)) {
    const snap = await db.collection(c).get();
    snap.forEach(d => out[c].push({ id: d.id, ...d.data() }));
  }
  fs.writeFileSync('scripts/seed_data/_audit_dump.json', JSON.stringify(out, null, 2));

  let md = '# HimRaag Catalog Audit\n\n';
  md += `_Generated ${new Date().toISOString()} from live Firestore (${PROJECT_ID})._\n\n`;
  md += `## Totals\n\n- **Songs:** ${out.songs.length}\n- **Albums:** ${out.albums.length}\n- **Artists:** ${out.artists.length}\n\n`;

  // coverage
  const songArt = out.songs.filter(s => reachable(s.artworkUrl)).length;
  const songAud = out.songs.filter(s => reachable(s.audioUrl)).length;
  const artImg = out.artists.filter(a => reachable(a.imageUrl)).length;
  const albCov = out.albums.filter(a => reachable(a.coverUrl || a.artworkUrl)).length;
  md += `## Coverage\n\n`;
  md += `- Songs with artworkUrl: ${songArt}/${out.songs.length}\n`;
  md += `- Songs with audioUrl: ${songAud}/${out.songs.length}\n`;
  md += `- Artists with imageUrl: ${artImg}/${out.artists.length}\n`;
  md += `- Albums with cover: ${albCov}/${out.albums.length}\n\n`;

  md += `## Songs\n\n`;
  md += '| Title | Artist | Album | Artwork | Audio | approvalStatus | isApproved | reviewRequired |\n';
  md += '|---|---|---|---|---|---|---|---|\n';
  for (const s of out.songs) {
    md += `| ${s.title||''} | ${s.artistName||s.artist||''} | ${s.albumName||s.album||''} `
       + `| ${reachable(s.artworkUrl)?'✅':'❌'} | ${reachable(s.audioUrl)?'✅':'❌'} `
       + `| ${s.approvalStatus??''} | ${s.isApproved??''} | ${s.reviewRequired??''} |\n`;
  }
  md += `\n## Artists\n\n| Name | Region | imageUrl | bio? |\n|---|---|---|---|\n`;
  for (const a of out.artists) md += `| ${a.name||''} | ${a.region||''} | ${reachable(a.imageUrl)?'✅':'❌'} | ${a.bio?'✅':'❌'} |\n`;
  md += `\n## Albums\n\n| Title | Artist | cover? |\n|---|---|---|\n`;
  for (const a of out.albums) md += `| ${a.title||a.name||''} | ${a.artistName||a.artist||''} | ${reachable(a.coverUrl||a.artworkUrl)?'✅':'❌'} |\n`;

  fs.writeFileSync('CATALOG_AUDIT.md', md);
  console.log('Wrote CATALOG_AUDIT.md and scripts/seed_data/_audit_dump.json');
  console.log(`songs=${out.songs.length} artists=${out.artists.length} albums=${out.albums.length}`);
  console.log(`coverage songArt=${songArt} artImg=${artImg} albCov=${albCov}`);
}
main().then(()=>process.exit(0)).catch(e=>{console.error(e);process.exit(1);});
