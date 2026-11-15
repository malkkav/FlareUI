// White-with-alpha TGAs for art drawn from code, tinted in game (panelart.js, auraart.js).
'use strict';
const fs = require('fs');
const path = require('path');

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

module.exports = { tga, coverage };
