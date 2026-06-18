/**
 * Pure-Node 600x600 PNG cover generator (no native deps).
 *
 * Renders a professional default cover: region-tinted diagonal gradient, a
 * large monogram (initials), the full title/subtitle, a region label, and the
 * HimRaag wordmark. Used for songs, albums and artists that have no real
 * artwork. Deterministic per seed so re-runs are stable.
 */
'use strict';

const zlib = require('zlib');

// ── PNG encoding ─────────────────────────────────────────────────────────────
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
function encodePng(raster, W, H) {
  const rowLen = 1 + W * 3;
  const raw = Buffer.alloc(rowLen * H);
  for (let y = 0; y < H; y++) {
    raw[y * rowLen] = 0;
    raster.copy(raw, y * rowLen + 1, y * W * 3, (y + 1) * W * 3);
  }
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0);
  ihdr.writeUInt32BE(H, 4);
  ihdr[8] = 8; ihdr[9] = 2; // 8-bit RGB
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}

// ── 5x7 bitmap font (uppercase + digits + space) ─────────────────────────────
const FONT = {
  A: [' ### ', '#   #', '#   #', '#####', '#   #', '#   #', '#   #'],
  B: ['#### ', '#   #', '#   #', '#### ', '#   #', '#   #', '#### '],
  C: [' ####', '#    ', '#    ', '#    ', '#    ', '#    ', ' ####'],
  D: ['#### ', '#   #', '#   #', '#   #', '#   #', '#   #', '#### '],
  E: ['#####', '#    ', '#    ', '#### ', '#    ', '#    ', '#####'],
  F: ['#####', '#    ', '#    ', '#### ', '#    ', '#    ', '#    '],
  G: [' ####', '#    ', '#    ', '#  ##', '#   #', '#   #', ' ####'],
  H: ['#   #', '#   #', '#   #', '#####', '#   #', '#   #', '#   #'],
  I: ['#####', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '#####'],
  J: ['#####', '   # ', '   # ', '   # ', '   # ', '#  # ', ' ##  '],
  K: ['#   #', '#  # ', '# #  ', '##   ', '# #  ', '#  # ', '#   #'],
  L: ['#    ', '#    ', '#    ', '#    ', '#    ', '#    ', '#####'],
  M: ['#   #', '## ##', '# # #', '# # #', '#   #', '#   #', '#   #'],
  N: ['#   #', '##  #', '# # #', '# # #', '#  ##', '#   #', '#   #'],
  O: [' ### ', '#   #', '#   #', '#   #', '#   #', '#   #', ' ### '],
  P: ['#### ', '#   #', '#   #', '#### ', '#    ', '#    ', '#    '],
  Q: [' ### ', '#   #', '#   #', '#   #', '# # #', '#  # ', ' ## #'],
  R: ['#### ', '#   #', '#   #', '#### ', '# #  ', '#  # ', '#   #'],
  S: [' ####', '#    ', '#    ', ' ### ', '    #', '    #', '#### '],
  T: ['#####', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '  #  '],
  U: ['#   #', '#   #', '#   #', '#   #', '#   #', '#   #', ' ### '],
  V: ['#   #', '#   #', '#   #', '#   #', '#   #', ' # # ', '  #  '],
  W: ['#   #', '#   #', '#   #', '# # #', '# # #', '## ##', '#   #'],
  X: ['#   #', '#   #', ' # # ', '  #  ', ' # # ', '#   #', '#   #'],
  Y: ['#   #', '#   #', ' # # ', '  #  ', '  #  ', '  #  ', '  #  '],
  Z: ['#####', '    #', '   # ', '  #  ', ' #   ', '#    ', '#####'],
  0: [' ### ', '#   #', '#  ##', '# # #', '##  #', '#   #', ' ### '],
  1: ['  #  ', ' ##  ', '  #  ', '  #  ', '  #  ', '  #  ', '#####'],
  2: [' ### ', '#   #', '    #', '  ## ', ' #   ', '#    ', '#####'],
  3: ['#####', '    #', '   # ', '  ## ', '    #', '#   #', ' ### '],
  4: ['   # ', '  ## ', ' # # ', '#  # ', '#####', '   # ', '   # '],
  5: ['#####', '#    ', '#### ', '    #', '    #', '#   #', ' ### '],
  6: [' ### ', '#    ', '#    ', '#### ', '#   #', '#   #', ' ### '],
  7: ['#####', '    #', '   # ', '  #  ', ' #   ', ' #   ', ' #   '],
  8: [' ### ', '#   #', '#   #', ' ### ', '#   #', '#   #', ' ### '],
  9: [' ### ', '#   #', '#   #', ' ####', '    #', '    #', ' ### '],
  ' ': ['     ', '     ', '     ', '     ', '     ', '     ', '     '],
  '&': [' ##  ', '#  # ', '#  # ', ' ##  ', '#  ##', '#  # ', ' ## #'],
  '-': ['     ', '     ', '     ', '#####', '     ', '     ', '     '],
  '.': ['     ', '     ', '     ', '     ', '     ', '  ## ', '  ## '],
};
const GLYPH_W = 5, GLYPH_H = 7;

// ── Raster helpers ───────────────────────────────────────────────────────────
function setPx(r, W, H, x, y, c) {
  x = x | 0; y = y | 0;
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  const p = (y * W + x) * 3;
  r[p] = c[0]; r[p + 1] = c[1]; r[p + 2] = c[2];
}
function glyphFor(ch) {
  const up = ch.toUpperCase();
  return FONT[up] || FONT[' '];
}
function textWidth(text, scale) {
  return text.length * (GLYPH_W + 1) * scale - scale;
}
function drawText(r, W, H, x, y, text, scale, color) {
  let cx = x;
  for (const ch of text) {
    const g = glyphFor(ch);
    for (let gy = 0; gy < GLYPH_H; gy++) {
      for (let gx = 0; gx < GLYPH_W; gx++) {
        if (g[gy][gx] === '#') {
          for (let sy = 0; sy < scale; sy++)
            for (let sx = 0; sx < scale; sx++)
              setPx(r, W, H, cx + gx * scale + sx, y + gy * scale + sy, color);
        }
      }
    }
    cx += (GLYPH_W + 1) * scale;
  }
}
function drawCentered(r, W, H, cy, text, scale, color) {
  drawText(r, W, H, Math.round((W - textWidth(text, scale)) / 2), cy, text, scale, color);
}

// ── Palette + seed ───────────────────────────────────────────────────────────
const REGION_COLORS = {
  Garhwali: [38, 116, 84],
  Kumaoni: [40, 96, 150],
  Jaunsari: [176, 110, 52],
  Himachali: [92, 74, 188],
  Kinnauri: [168, 30, 110],
  Sirmauri: [180, 132, 36],
  Pahadi: [60, 90, 140],
  'Needs Review': [70, 76, 92],
};
function hash(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) h = ((h << 5) + h + str.charCodeAt(i)) >>> 0;
  return h;
}
function clamp(v) { return Math.max(0, Math.min(255, Math.round(v))); }
function mix(a, b, t) { return [clamp(a[0] + (b[0] - a[0]) * t), clamp(a[1] + (b[1] - a[1]) * t), clamp(a[2] + (b[2] - a[2]) * t)]; }

function initials(title) {
  const words = (title || '').replace(/[^A-Za-z0-9 ]/g, ' ').trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return '♪';
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}
function fit(text, max) {
  const t = (text || '').toUpperCase();
  return t.length <= max ? t : t.slice(0, max - 1) + '.';
}

/**
 * Build a 600x600 cover PNG.
 * @param {{title:string, subtitle?:string, region:string, seed:string}} opts
 */
function makeCover({ title, subtitle, region, seed }) {
  const W = 600, H = 600;
  const r = Buffer.alloc(W * H * 3);
  const base = REGION_COLORS[region] || REGION_COLORS.Pahadi;
  const h = hash(seed || title || 'x');
  // Seeded hue nudge for per-item variety.
  const nudged = [clamp(base[0] + ((h & 0x1f) - 16)), clamp(base[1] + (((h >> 5) & 0x1f) - 16)), clamp(base[2] + (((h >> 10) & 0x1f) - 16))];
  const top = mix(nudged, [255, 255, 255], 0.18);
  const bottom = mix(nudged, [0, 0, 0], 0.55);

  // Diagonal gradient.
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const t = (x + y) / (W + H);
      const c = mix(top, bottom, t);
      const p = (y * W + x) * 3;
      r[p] = c[0]; r[p + 1] = c[1]; r[p + 2] = c[2];
    }
  }
  // Soft vignette circle behind monogram.
  const ringC = mix(nudged, [255, 255, 255], 0.30);
  const cx = W / 2, cy = 268, R = 150;
  for (let y = cy - R - 4; y <= cy + R + 4; y++) {
    for (let x = cx - R - 4; x <= cx + R + 4; x++) {
      const d = Math.hypot(x - cx, y - cy);
      if (d >= R - 3 && d <= R) setPx(r, W, H, x, y, ringC);
    }
  }

  const ink = [255, 255, 255];
  const faint = mix(bottom, [255, 255, 255], 0.6);

  // Region label (top).
  drawCentered(r, W, H, 70, fit(region, 18), 4, faint);
  // Monogram (big, centered in ring).
  const mono = initials(title);
  const monoScale = 18;
  drawText(r, W, H, Math.round((W - textWidth(mono, monoScale)) / 2), cy - (GLYPH_H * monoScale) / 2, mono, monoScale, ink);
  // Title.
  drawCentered(r, W, H, 452, fit(title, 20), 5, ink);
  // Subtitle (artist).
  if (subtitle) drawCentered(r, W, H, 502, fit(subtitle, 24), 3, faint);
  // Wordmark.
  drawCentered(r, W, H, 556, 'HIMRAAG', 4, mix(ink, nudged, 0.25));

  return encodePng(r, W, H);
}

module.exports = { makeCover, REGION_COLORS };
