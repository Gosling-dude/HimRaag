/**
 * Pure-Node PNG generator for placeholder artwork (no native deps).
 *
 * The imported MP3s carry no embedded artwork, so each track gets a
 * deterministic solid-colour 600×600 cover (colour derived from a seed hash,
 * tinted per region) plus a darker footer band. Real raster PNG → renders in
 * the Flutter app (cached_network_image) and is reachable as a public R2 URL.
 * Tracks are flagged reviewRequired so the owner can replace artwork later.
 */
'use strict';

const zlib = require('zlib');

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return ~c >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
}

const REGION_COLORS = {
  Garhwali: [46, 139, 87], // sea green
  Kumaoni: [70, 130, 180], // steel blue
  Jaunsari: [205, 133, 63], // peru
  Himachali: [123, 104, 238], // medium slate blue
  Kinnauri: [199, 21, 133], // medium violet red
  Sirmauri: [218, 165, 32], // goldenrod
  'Needs Review': [96, 96, 112], // slate grey
};

function hash(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) h = ((h << 5) + h + str.charCodeAt(i)) >>> 0;
  return h;
}

/** Build a 600×600 RGB PNG buffer for a song (solid tint + footer band). */
function makeArtworkPng(seed, region) {
  const W = 600;
  const H = 600;
  const base = REGION_COLORS[region] || REGION_COLORS['Needs Review'];
  // Nudge the base colour by the seed so each track differs slightly.
  const h = hash(seed);
  const tint = [
    Math.max(20, Math.min(235, base[0] + ((h & 0x3f) - 32))),
    Math.max(20, Math.min(235, base[1] + (((h >> 6) & 0x3f) - 32))),
    Math.max(20, Math.min(235, base[2] + (((h >> 12) & 0x3f) - 32))),
  ];
  const footer = tint.map((v) => Math.round(v * 0.45)); // darker band
  const FOOTER_FROM = H - 90;

  const rowLen = 1 + W * 3;
  const raw = Buffer.alloc(rowLen * H);
  for (let y = 0; y < H; y++) {
    const off = y * rowLen;
    raw[off] = 0; // filter: none
    const col = y >= FOOTER_FROM ? footer : tint;
    for (let x = 0; x < W; x++) {
      const p = off + 1 + x * 3;
      raw[p] = col[0];
      raw[p + 1] = col[1];
      raw[p + 2] = col[2];
    }
  }

  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0);
  ihdr.writeUInt32BE(H, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // colour type RGB
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

module.exports = { makeArtworkPng, REGION_COLORS };
