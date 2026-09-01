// Generate public/og.png — the social preview card.
//
// Written by hand rather than pulled from a rendering library: the card is a
// flat brand field, the isometric cube from icon.svg, and a wordmark drawn from
// a small built-in 5x7 font. That keeps the site's dependency list to astro +
// yaml and avoids shipping a headless browser into CI just to draw a rectangle.
//
// A missing og:image is better than a broken one, so this runs in prebuild and
// fails loudly rather than emitting a truncated file.
import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const W = 1200, H = 630;
const px = new Uint8Array(W * H * 3);

const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const BG = hex('#0a0c10');      // --fg-strong, the site's darkest ink
const TEAL = hex('#14b8a6');    // brand gradient start
const TEAL2 = hex('#0d9488');   // --accent
const WHITE = [255, 255, 255];
const MUTED = [139, 144, 156];  // --subtle

const set = (x, y, c, a = 1) => {
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  const i = (y * W + x) * 3;
  for (let k = 0; k < 3; k++) px[i + k] = Math.round(px[i + k] * (1 - a) + c[k] * a);
};
const rect = (x, y, w, h, c, a = 1) => {
  for (let dy = 0; dy < h; dy++) for (let dx = 0; dx < w; dx++) set(x + dx, y + dy, c, a);
};

// Background + a teal accent bar down the left edge.
rect(0, 0, W, H, BG);
for (let y = 0; y < H; y++) {
  const t = y / H;
  const c = [TEAL[0] + (TEAL2[0] - TEAL[0]) * t, TEAL[1] + (TEAL2[1] - TEAL[1]) * t, TEAL[2] + (TEAL2[2] - TEAL[2]) * t];
  rect(0, y, 14, 1, c);
}

// Isometric cube, same geometry as icon.svg scaled up. Barycentric fill so the
// three faces read as a cube rather than a blob.
const cube = (cx, cy, s) => {
  const P = (x, y) => [cx + (x - 16) * s, cy + (y - 16) * s];
  const tri = (a, b, c, col, alpha) => {
    const xs = [a[0], b[0], c[0]], ys = [a[1], b[1], c[1]];
    const x0 = Math.floor(Math.min(...xs)), x1 = Math.ceil(Math.max(...xs));
    const y0 = Math.floor(Math.min(...ys)), y1 = Math.ceil(Math.max(...ys));
    const d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1]);
    if (!d) return;
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const l1 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / d;
      const l2 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / d;
      const l3 = 1 - l1 - l2;
      if (l1 >= -0.002 && l2 >= -0.002 && l3 >= -0.002) set(x, y, col, alpha);
    }
  };
  const quad = (a, b, c, d, col, alpha) => { tri(a, b, c, col, alpha); tri(a, c, d, col, alpha); };
  const T = P(16, 7), R = P(24, 11.5), B = P(16, 16), L = P(8, 11.5);
  const BL = P(8, 20.5), BB = P(16, 25), BR = P(24, 20.5);
  quad(T, R, B, L, WHITE, 0.92);      // top face
  quad(L, B, BB, BL, WHITE, 0.30);    // left face
  quad(R, B, BB, BR, WHITE, 0.14);    // right face
};

// 5x7 bitmap font, only the glyphs this card needs.
const FONT = {
  m: ['00000','00000','11110','10101','10101','10101','10101'],
  i: ['00100','00000','01100','00100','00100','00100','01110'],
  n: ['00000','00000','10110','11001','10001','10001','10001'],
  a: ['00000','00000','01110','00001','01111','10001','01111'],
  l: ['01100','00100','00100','00100','00100','00100','01110'],
  c: ['00000','00000','01110','10001','10000','10001','01110'],
  o: ['00000','00000','01110','10001','10001','10001','01110'],
  t: ['00100','00100','11111','00100','00100','00100','00011'],
  e: ['00000','00000','01110','10001','11111','10000','01110'],
  r: ['00000','00000','10110','11001','10000','10000','10000'],
  s: ['00000','00000','01111','10000','01110','00001','11110'],
  d: ['00001','00001','01111','10001','10001','10001','01111'],
  h: ['10000','10000','10110','11001','10001','10001','10001'],
  g: ['00000','00000','01111','10001','01111','00001','01110'],
  f: ['00110','01001','01000','11100','01000','01000','01000'],
  u: ['00000','00000','10001','10001','10001','10011','01101'],
  v: ['00000','00000','10001','10001','10001','01010','00100'],
  p: ['00000','00000','11110','10001','11110','10000','10000'],
  b: ['10000','10000','11110','10001','10001','10001','11110'],
  y: ['00000','00000','10001','10001','01111','00001','01110'],
  '.': ['00000','00000','00000','00000','00000','00000','00100'],
  ',': ['00000','00000','00000','00000','00000','00100','01000'],
  '·': ['00000','00000','00000','00100','00000','00000','00000'],
  ' ': ['00000','00000','00000','00000','00000','00000','00000'],
};
const text = (str, x, y, scale, col) => {
  let cx = x;
  for (const ch of str.toLowerCase()) {
    const g = FONT[ch];
    if (!g) { cx += 6 * scale; continue; }
    for (let r = 0; r < 7; r++) for (let c = 0; c < 5; c++) {
      if (g[r][c] === '1') rect(cx + c * scale, y + r * scale, scale, scale, col);
    }
    cx += 6 * scale;
  }
  return cx;
};

// Keep every line inside the 1200px canvas: a glyph is 6*scale wide, so the
// longest strapline below is 30 chars * 6 * 4 = 720px from x=300.
cube(150, 250, 8.5);
text('minimal', 300, 175, 13, WHITE);
text('containers', 300, 280, 13, TEAL);
text('free hardened container images', 300, 410, 4, MUTED);
text('mit licensed · signed · sbom', 300, 455, 4, MUTED);

// PNG encode: filter byte 0 per scanline, one IDAT, CRC per chunk.
const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
};
const raw = Buffer.alloc(H * (W * 3 + 1));
for (let y = 0; y < H; y++) {
  raw[y * (W * 3 + 1)] = 0;
  Buffer.from(px.buffer, y * W * 3, W * 3).copy(raw, y * (W * 3 + 1) + 1);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4);
ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);
const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'og.png');
writeFileSync(out, png);
console.log(`og.png ${W}x${H} (${(png.length / 1024).toFixed(1)} kB)`);
