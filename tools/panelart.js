// Draws the settings window's own art (11-10 panel rework) as white-with-alpha TGAs, tinted in game:
//   Media/Panel/Circle.tga        a smooth disc (switch track caps, knobs, slider, round buttons)
//   Media/Panel/Cursor.tga        the previews' pointer
//   Media/Panel/Icons/<key>.tga   the left list's module icons, 1.8-unit strokes on a 24-unit grid
// Run: node tools/panelart.js
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..', 'Media', 'Panel');

function tga(file, size, alphaAt) {
  const header = Buffer.alloc(18);
  header[2] = 2;                       // uncompressed true colour
  header.writeUInt16LE(size, 12);
  header.writeUInt16LE(size, 14);
  header[16] = 32;
  header[17] = 0x28;                   // 8 alpha bits, top-left origin
  const px = Buffer.alloc(size * size * 4);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const i = (y * size + x) * 4;
    px[i] = px[i + 1] = px[i + 2] = 255;
    px[i + 3] = Math.round(Math.max(0, Math.min(1, alphaAt(x, y))) * 255);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.concat([header, px]));
}

// 4 x 4 samples per pixel
function coverage(size, scale, inside) {
  return (x, y) => {
    let n = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
      if (inside((x + (sx + 0.5) / 4) / scale, (y + (sy + 0.5) / 4) / scale)) n++;
    }
    return n / 16;
  };
}

// the disc: 64 px, 1 px clear at the edge so tinting never shows a square
tga(path.join(ROOT, 'Circle.tga'), 64, coverage(64, 1, (x, y) => Math.hypot(x - 32, y - 32) <= 31));

// icon shapes on the mock-up's 24-unit grid
const W = 0.95;   // half the stroke
const seg = (ax, ay, bx, by) => (x, y) => {
  const dx = bx - ax, dy = by - ay, l = dx * dx + dy * dy;
  const t = l ? Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / l)) : 0;
  return Math.hypot(x - ax - t * dx, y - ay - t * dy) <= W;
};
const poly = (pts, closed) => { const s = []; for (let i = 0; i < pts.length - 1; i++) s.push(seg(...pts[i], ...pts[i + 1])); if (closed) s.push(seg(...pts[pts.length - 1], ...pts[0])); return s; };
const ring = (cx, cy, r) => (x, y) => Math.abs(Math.hypot(x - cx, y - cy) - r) <= W;
const ellipse = (cx, cy, rx, ry) => (x, y) => { const d = Math.hypot((x - cx) / rx, (y - cy) / ry); return Math.abs(d - 1) * Math.min(rx, ry) <= W; };
const rrect = (x0, y0, w, h, r) => (x, y) => {
  const cx = x0 + w / 2, cy = y0 + h / 2;
  const qx = Math.abs(x - cx) - (w / 2 - r), qy = Math.abs(y - cy) - (h / 2 - r);
  const d = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
  return Math.abs(d) <= W;
};
const BOX = rrect(4, 4, 16, 16, 3), DIAL = ring(12, 12, 8), ROUND = ring(12, 12, 9);
const MAP = poly([[4, 7], [9, 5], [15, 7], [20, 5], [20, 17], [15, 19], [9, 17], [4, 19]], true);
const ICONS = {
  about: [ROUND, seg(12, 11, 12, 17), seg(12, 7.5, 12, 8)],
  adv: [ROUND, ring(12, 10, 3), ...poly([[7, 17], [8.2, 15.4], [10, 14.3], [12, 14], [14, 14.3], [15.8, 15.4], [17, 17]])],
  // the globe's meridian stays inside its circle
  language: [ROUND, seg(3, 12, 21, 12), (x, y) => Math.hypot(x - 12, y - 12) <= 9 && ellipse(12, 12, 4, 9)(x, y)],
  ab: [BOX, seg(8, 9, 8, 15), seg(12, 9, 12, 15), seg(16, 9, 16, 15)],
  uf: [BOX, seg(8, 10, 16, 10), seg(8, 14, 13, 14)],
  rb: [BOX, seg(7, 10, 17, 10), seg(7, 14, 14, 14)],
  au: [BOX, ...poly([[9, 12], [11, 14], [15, 10]])],
  dm: [BOX, seg(9, 15, 9, 12), seg(12, 15, 12, 9), seg(15, 15, 15, 10)],
  mm: [...MAP, seg(12, 9, 12, 15)],
  qt: [...MAP, seg(9, 11, 15, 11)],
  ch: [DIAL, seg(8, 11, 16, 11), seg(8, 14, 13, 14)],
  tt: [DIAL, seg(12, 9, 12, 13), seg(12, 15, 12, 15.5)],
  rm: [DIAL, seg(12, 4, 12, 8), seg(12, 16, 12, 20), seg(4, 12, 8, 12), seg(16, 12, 20, 12)],
  qol: [DIAL, ...poly([[9, 12], [11, 14], [15, 10]])],
};
// the dropdowns' arrow: a down chevron (Media/Panel/Chevron.tga)
tga(path.join(ROOT, 'Chevron.tga'), 32, coverage(32, 32 / 24, (x, y) => poly([[6, 9.5], [12, 15.5], [18, 9.5]]).some((s) => s(x, y))));

// the previews' pointer: a filled arrow (Media/Panel/Cursor.tga), tip at the top left
const inPoly = (pts) => (x, y) => {
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
};
tga(path.join(ROOT, 'Cursor.tga'), 32, coverage(32, 32 / 24, inPoly([[3, 1.5], [3, 19.5], [7.6, 15.4], [10.6, 22], [13.6, 20.7], [10.7, 14.3], [16.6, 14.3]])));

for (const [key, shapes] of Object.entries(ICONS)) {
  tga(path.join(ROOT, 'Icons', key + '.tga'), 32, coverage(32, 32 / 24, (x, y) => shapes.some((s) => s(x, y))));
}
console.log('panel art: Circle.tga, Chevron.tga, Cursor.tga + ' + Object.keys(ICONS).length + ' icons');
