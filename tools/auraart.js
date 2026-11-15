// Draws aura art as white-with-alpha TGAs, tinted in game: the totems' In Range marching ants (Totems.lua)
//   Media/Auras/AntsRing.tga     12 dashes round a circle, turned in game (the round totem buttons)
//   Media/Auras/AntsSquare.tga   16 frames (4 x 4, 64 px each) of dashes one step further round a
//                                square, played as a flipbook in game (the square action buttons)
// Run: node tools/auraart.js
const path = require('path');
const { tga, coverage } = require('./tga');
const ROOT = path.join(__dirname, '..', 'Media', 'Auras');

// The ring, 128 px: a 5 px line 58 px out, 12 dashes each a little longer than its gap
const DASHES = 12, R = 58, HALF = 2.5, ON = 0.58;
tga(path.join(ROOT, 'AntsRing.tga'), 128, coverage(128, 1, (x, y) => {
  const dx = x - 64, dy = y - 64;
  if (Math.abs(Math.hypot(dx, dy) - R) > HALF) return false;
  const turn = (Math.atan2(dy, dx) / (2 * Math.PI) + 1) % 1;
  return (turn * DASHES) % 1 < ON;
}));

// The square, per 64 px frame: a 3 px line 3 px in from the edge, 16 dashes round it. Each frame moves
// the dashes a sixteenth of a dash-and-gap clockwise, so the last frame runs into the first.
const FRAME = 64, GRID = 4, FRAMES = GRID * GRID;
const H = FRAME / 2 - 3.5;          // half the square's side, to the line's middle
const LINE = 1.5;                   // half the line's width
const PERIOD = (8 * H) / 16;        // one dash and its gap along the outline
tga(path.join(ROOT, 'AntsSquare.tga'), FRAME * GRID, coverage(FRAME * GRID, 1, (X, Y) => {
  const frame = Math.floor(Y / FRAME) * GRID + Math.floor(X / FRAME);
  const x = (X % FRAME) - FRAME / 2, y = (Y % FRAME) - FRAME / 2;
  const ax = Math.abs(x), ay = Math.abs(y);
  if (Math.abs(Math.max(ax, ay) - H) > LINE) return false;
  // how far round the outline, clockwise from the top left corner (y runs down)
  const cx = Math.max(-H, Math.min(H, x)), cy = Math.max(-H, Math.min(H, y));
  let t;
  if (ay >= ax) t = y < 0 ? cx + H : 4 * H + (H - cx);       // top, bottom
  else t = x > 0 ? 2 * H + (cy + H) : 6 * H + (H - cy);      // right, left
  const along = (((t - (frame / FRAMES) * PERIOD) % PERIOD) + PERIOD) % PERIOD;
  return along < PERIOD * ON;
}));
console.log('aura art: AntsRing.tga, AntsSquare.tga');
