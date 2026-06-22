/**
 * Pure-Node premium cover generator (no native deps). v2.
 *
 * Renders 600x600 covers by drawing at 3x and box-downsampling for clean
 * anti-aliased edges. Two styles:
 *   makeSongCover  — dusk sky gradient + layered Himalayan ridges + sun/moon +
 *                    title/artist + HimRaag wordmark (thematic album art).
 *   makeArtistCover— radial brand gradient + large centered monogram (a clean,
 *                    premium default avatar shown in a circle).
 *
 * Deterministic per `seed` so re-runs are stable but each item differs.
 */
'use strict';

const zlib = require('zlib');

// ── PNG encoding ─────────────────────────────────────────────────────────────
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c; }
  return t;
})();
function crc32(buf) { let c = ~0; for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8); return ~c >>> 0; }
function pngChunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const tb = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([tb, data])), 0);
  return Buffer.concat([len, tb, data, crc]);
}
function encodePng(rgb, W, H) {
  const rowLen = 1 + W * 3;
  const raw = Buffer.alloc(rowLen * H);
  for (let y = 0; y < H; y++) { raw[y * rowLen] = 0; rgb.copy(raw, y * rowLen + 1, y * W * 3, (y + 1) * W * 3); }
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([sig, pngChunk('IHDR', ihdr), pngChunk('IDAT', zlib.deflateSync(raw, { level: 9 })), pngChunk('IEND', Buffer.alloc(0))]);
}

// ── 5x7 bitmap font ──────────────────────────────────────────────────────────
const FONT = {
  A: [' ### ', '#   #', '#   #', '#####', '#   #', '#   #', '#   #'], B: ['#### ', '#   #', '#   #', '#### ', '#   #', '#   #', '#### '],
  C: [' ####', '#    ', '#    ', '#    ', '#    ', '#    ', ' ####'], D: ['#### ', '#   #', '#   #', '#   #', '#   #', '#   #', '#### '],
  E: ['#####', '#    ', '#    ', '#### ', '#    ', '#    ', '#####'], F: ['#####', '#    ', '#    ', '#### ', '#    ', '#    ', '#    '],
  G: [' ####', '#    ', '#    ', '#  ##', '#   #', '#   #', ' ####'], H: ['#   #', '#   #', '#   #', '#####', '#   #', '#   #', '#   #'],
  I: ['#####', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '#####'], J: ['#####', '   # ', '   # ', '   # ', '   # ', '#  # ', ' ##  '],
  K: ['#   #', '#  # ', '# #  ', '##   ', '# #  ', '#  # ', '#   #'], L: ['#    ', '#    ', '#    ', '#    ', '#    ', '#    ', '#####'],
  M: ['#   #', '## ##', '# # #', '# # #', '#   #', '#   #', '#   #'], N: ['#   #', '##  #', '# # #', '# # #', '#  ##', '#   #', '#   #'],
  O: [' ### ', '#   #', '#   #', '#   #', '#   #', '#   #', ' ### '], P: ['#### ', '#   #', '#   #', '#### ', '#    ', '#    ', '#    '],
  Q: [' ### ', '#   #', '#   #', '#   #', '# # #', '#  # ', ' ## #'], R: ['#### ', '#   #', '#   #', '#### ', '# #  ', '#  # ', '#   #'],
  S: [' ####', '#    ', '#    ', ' ### ', '    #', '    #', '#### '], T: ['#####', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '  #  '],
  U: ['#   #', '#   #', '#   #', '#   #', '#   #', '#   #', ' ### '], V: ['#   #', '#   #', '#   #', '#   #', '#   #', ' # # ', '  #  '],
  W: ['#   #', '#   #', '#   #', '# # #', '# # #', '## ##', '#   #'], X: ['#   #', '#   #', ' # # ', '  #  ', ' # # ', '#   #', '#   #'],
  Y: ['#   #', '#   #', ' # # ', '  #  ', '  #  ', '  #  ', '  #  '], Z: ['#####', '    #', '   # ', '  #  ', ' #   ', '#    ', '#####'],
  0: [' ### ', '#   #', '#  ##', '# # #', '##  #', '#   #', ' ### '], 1: ['  #  ', ' ##  ', '  #  ', '  #  ', '  #  ', '  #  ', '#####'],
  2: [' ### ', '#   #', '    #', '  ## ', ' #   ', '#    ', '#####'], 3: ['#####', '    #', '   # ', '  ## ', '    #', '#   #', ' ### '],
  4: ['   # ', '  ## ', ' # # ', '#  # ', '#####', '   # ', '   # '], 5: ['#####', '#    ', '#### ', '    #', '    #', '#   #', ' ### '],
  6: [' ### ', '#    ', '#    ', '#### ', '#   #', '#   #', ' ### '], 7: ['#####', '    #', '   # ', '  #  ', ' #   ', ' #   ', ' #   '],
  8: [' ### ', '#   #', '#   #', ' ### ', '#   #', '#   #', ' ### '], 9: [' ### ', '#   #', '#   #', ' ####', '    #', '    #', ' ### '],
  ' ': ['     ', '     ', '     ', '     ', '     ', '     ', '     '], '-': ['     ', '     ', '     ', '#####', '     ', '     ', '     '],
  '.': ['     ', '     ', '     ', '     ', '     ', '  ## ', '  ## '], ',': ['     ', '     ', '     ', '     ', '     ', '  ## ', ' ##  '],
  '&': [' ##  ', '#  # ', '#  # ', ' ##  ', '#  ##', '#  # ', ' ## #'], "'": ['  #  ', '  #  ', '  #  ', '     ', '     ', '     ', '     '],
};
const GW = 5, GH = 7;

// ── Palette ──────────────────────────────────────────────────────────────────
const BRAND_PURPLE = [42, 24, 80];
const ACCENT = [232, 160, 32];
const REGION_COLORS = {
  Garhwali: [34, 120, 92], Kumaoni: [36, 100, 158], Jaunsari: [150, 84, 176],
  Himachali: [176, 56, 72], Kinnauri: [0, 122, 112], Sirmauri: [120, 80, 58],
  Pahadi: [70, 86, 150], 'Needs Review': [70, 76, 92],
};
function hash(s) { let h = 5381; for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) >>> 0; return h; }
function rngFrom(seed) { let x = hash(seed) || 1; return () => { x ^= x << 13; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return x / 0xffffffff; }; }
function cl(v) { return Math.max(0, Math.min(255, Math.round(v))); }
function mix(a, b, t) { return [cl(a[0] + (b[0] - a[0]) * t), cl(a[1] + (b[1] - a[1]) * t), cl(a[2] + (b[2] - a[2]) * t)]; }

function initials(title) {
  const w = (title || '').replace(/[^A-Za-z0-9 ]/g, ' ').trim().split(/\s+/).filter(Boolean);
  if (!w.length) return 'HR';
  if (w.length === 1) return w[0].slice(0, 2).toUpperCase();
  return (w[0][0] + w[1][0]).toUpperCase();
}
function fit(t, max) { t = (t || '').toUpperCase(); return t.length <= max ? t : t.slice(0, max - 1) + '.'; }

// ── Supersampled canvas ──────────────────────────────────────────────────────
const OUT = 600, SS = 3, W = OUT * SS, H = OUT * SS;
function canvas() { return Buffer.alloc(W * H * 3); }
function px(buf, x, y, c, a = 1) {
  x |= 0; y |= 0; if (x < 0 || y < 0 || x >= W || y >= H) return;
  const p = (y * W + x) * 3;
  if (a >= 1) { buf[p] = c[0]; buf[p + 1] = c[1]; buf[p + 2] = c[2]; }
  else { buf[p] = cl(buf[p] * (1 - a) + c[0] * a); buf[p + 1] = cl(buf[p + 1] * (1 - a) + c[1] * a); buf[p + 2] = cl(buf[p + 2] * (1 - a) + c[2] * a); }
}
function fillCircle(buf, cx, cy, r, c, a = 1) {
  for (let y = Math.floor(cy - r); y <= cy + r; y++)
    for (let x = Math.floor(cx - r); x <= cx + r; x++)
      if ((x - cx) ** 2 + (y - cy) ** 2 <= r * r) px(buf, x, y, c, a);
}
function strokeCircle(buf, cx, cy, r, width, c, a = 1) {
  for (let y = Math.floor(cy - r - width); y <= cy + r + width; y++)
    for (let x = Math.floor(cx - r - width); x <= cx + r + width; x++)
      if (Math.abs(Math.hypot(x - cx, y - cy) - r) <= width) px(buf, x, y, c, a);
}
function textWidth(t, s) { return t.length * (GW + 1) * s - s; }
function drawText(buf, x, y, text, s, color, a = 1) {
  let cx = x;
  for (const ch of text) {
    const g = FONT[ch.toUpperCase()] || FONT[' '];
    for (let gy = 0; gy < GH; gy++) for (let gx = 0; gx < GW; gx++)
      if (g[gy][gx] === '#') for (let sy = 0; sy < s; sy++) for (let sx = 0; sx < s; sx++) px(buf, cx + gx * s + sx, y + gy * s + sy, color, a);
    cx += (GW + 1) * s;
  }
}
function centerText(buf, cy, text, s, color, a = 1) { drawText(buf, Math.round((W - textWidth(text, s)) / 2), cy, text, s, color, a); }
// Pick the largest scale (multiple of SS) that fits within maxFrac of width.
function centerTextFit(buf, cy, text, maxScale, minScale, color, a, maxFrac) {
  const maxW = W * maxFrac;
  let s = maxScale;
  while (s > minScale && textWidth(text, s) > maxW) s -= SS;
  // Vertically nudge so larger/smaller text keeps a stable baseline.
  drawText(buf, Math.round((W - textWidth(text, s)) / 2), cy, text, s, color, a);
  return s;
}

function downsample(buf) {
  const out = Buffer.alloc(OUT * OUT * 3);
  const n = SS * SS;
  for (let y = 0; y < OUT; y++) for (let x = 0; x < OUT; x++) {
    let r = 0, g = 0, b = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const p = ((y * SS + sy) * W + (x * SS + sx)) * 3; r += buf[p]; g += buf[p + 1]; b += buf[p + 2];
    }
    const o = (y * OUT + x) * 3; out[o] = (r / n) | 0; out[o + 1] = (g / n) | 0; out[o + 2] = (b / n) | 0;
  }
  return out;
}

// ── Song / album cover: dusk sky + Himalayan ridges ──────────────────────────
function makeSongCover({ title, subtitle, region, seed }) {
  const buf = canvas();
  const rng = rngFrom(seed || title || 'x');
  const base = REGION_COLORS[region] || REGION_COLORS.Pahadi;
  const skyTop = mix(BRAND_PURPLE, base, 0.25 + rng() * 0.1);
  const horizon = mix(base, ACCENT, 0.35 + rng() * 0.15);
  // Sky gradient (top -> horizon at ~62% height).
  const horizonY = H * 0.62;
  for (let y = 0; y < H; y++) {
    const t = Math.min(1, y / horizonY);
    const c = mix(skyTop, horizon, t * t);
    for (let x = 0; x < W; x++) { const p = (y * W + x) * 3; buf[p] = c[0]; buf[p + 1] = c[1]; buf[p + 2] = c[2]; }
  }
  // Sun / moon.
  const sunX = W * (0.26 + rng() * 0.48), sunY = H * (0.26 + rng() * 0.12), sunR = W * 0.085;
  fillCircle(buf, sunX, sunY, sunR * 1.7, mix(ACCENT, horizon, 0.3), 0.18);
  fillCircle(buf, sunX, sunY, sunR * 1.3, mix(ACCENT, [255, 255, 255], 0.2), 0.22);
  fillCircle(buf, sunX, sunY, sunR, mix(ACCENT, [255, 240, 200], 0.3), 1);
  // Stars in upper sky.
  for (let i = 0; i < 40; i++) { const sx = rng() * W, sy = rng() * H * 0.4; px(buf, sx, sy, [255, 255, 255], 0.5 * rng()); px(buf, sx + 1, sy, [255, 255, 255], 0.3 * rng()); }
  // Layered ridges (back light -> front dark).
  const layers = [
    { yBase: 0.60, amp: 0.16, col: mix(base, BRAND_PURPLE, 0.25) },
    { yBase: 0.70, amp: 0.20, col: mix(base, [0, 0, 0], 0.35) },
    { yBase: 0.82, amp: 0.16, col: mix(base, [0, 0, 0], 0.62) },
  ];
  for (const L of layers) {
    const pts = 5 + (rng() * 3 | 0);
    const ctrl = Array.from({ length: pts + 1 }, () => L.yBase + (rng() - 0.5) * L.amp);
    for (let x = 0; x < W; x++) {
      const fx = (x / W) * pts; const i = Math.floor(fx); const f = fx - i;
      const ridge = (ctrl[i] * (1 - f) + ctrl[i + 1] * f) * H;
      for (let y = Math.floor(ridge); y < H; y++) px(buf, x, y, L.col, 1);
    }
  }
  // Bottom scrim for text legibility.
  for (let y = Math.floor(H * 0.72); y < H; y++) {
    const a = (y - H * 0.72) / (H * 0.28) * 0.65;
    for (let x = 0; x < W; x++) px(buf, x, y, [8, 6, 18], a);
  }
  const ink = [248, 246, 255], faint = [205, 196, 226];
  // Region pill label (top-left).
  drawText(buf, Math.round(W * 0.06), Math.round(H * 0.06), fit(region, 16), 4 * SS, faint, 0.9);
  // Title + subtitle (bottom), auto-fit so long titles never clip.
  centerTextFit(buf, Math.round(H * 0.80), fit(title, 22), 6 * SS, 3 * SS, ink, 1, 0.88);
  if (subtitle) centerTextFit(buf, Math.round(H * 0.875), fit(subtitle, 30), 3 * SS, 2 * SS, faint, 0.95, 0.86);
  centerText(buf, Math.round(H * 0.93), 'HIMRAAG', 3 * SS, mix(ACCENT, ink, 0.2), 0.9);
  return encodePng(downsample(buf), OUT, OUT);
}

// ── Artist avatar: radial brand gradient + monogram ──────────────────────────
function makeArtistCover({ title, region, seed }) {
  const buf = canvas();
  const rng = rngFrom(seed || title || 'x');
  const base = REGION_COLORS[region] || REGION_COLORS.Pahadi;
  const inner = mix(base, [255, 255, 255], 0.22);
  const outer = mix(mix(base, BRAND_PURPLE, 0.5), [0, 0, 0], 0.35);
  const cx = W / 2, cy = H / 2, maxD = Math.hypot(cx, cy);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const d = Math.hypot(x - cx, y - cy) / maxD;
    const c = mix(inner, outer, Math.pow(d, 1.3));
    const p = (y * W + x) * 3; buf[p] = c[0]; buf[p + 1] = c[1]; buf[p + 2] = c[2];
  }
  // Subtle inner vignette for depth.
  fillCircle(buf, cx, cy, W * 0.5, [0, 0, 0], 0.0);
  // Thin accent ring.
  strokeCircle(buf, cx, cy, W * 0.40, SS * 1.2, mix(ACCENT, [255, 255, 255], 0.25), 0.6);
  // Monogram (moderate, centered) on a soft dark chip for contrast.
  fillCircle(buf, cx, cy - H * 0.03, W * 0.205, mix(outer, [0, 0, 0], 0.25), 0.28);
  const mono = initials(title);
  const s = 17 * SS;
  drawText(buf, Math.round((W - textWidth(mono, s)) / 2), Math.round(cy - H * 0.03 - (GH * s) / 2), mono, s, [252, 250, 255], 1);
  centerText(buf, Math.round(H * 0.72), fit(region, 16), 3 * SS, mix([255, 255, 255], outer, 0.2), 0.85);
  return encodePng(downsample(buf), OUT, OUT);
}

// Back-compat alias used by older callers.
function makeCover(opts) { return makeSongCover(opts); }

module.exports = { makeSongCover, makeArtistCover, makeCover, REGION_COLORS };
