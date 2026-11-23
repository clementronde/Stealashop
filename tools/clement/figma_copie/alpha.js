// Découpe les images d'une planche photographiée sur fond noir et sur fond blanc, et retrouve leur transparence :
// noir = a·C, blanc = a·C + (1 − a)·255  ->  a = 1 − (blanc − noir) / 255, C = noir / a.
// Usage : node alpha.js <atlas.json> <capture_noir.jpg> <capture_blanc.jpg> <dossier images>
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const FF = path.join(process.env.LOCALAPPDATA, 'Microsoft', 'WinGet', 'Links', 'ffmpeg.exe');
const [, , atlasFile, blackFile, whiteFile, outDir] = process.argv;
fs.mkdirSync(outDir, { recursive: true });

function probe(file) {
  const out = execFileSync(path.join(path.dirname(FF), 'ffprobe.exe'), ['-v', 'error', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', file]).toString().trim();
  const [w, h] = out.split(',').map(Number);
  return { w, h };
}
function raw(file) { return execFileSync(FF, ['-v', 'error', '-i', file, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], { maxBuffer: 1 << 28 }); }

const atlas = JSON.parse(fs.readFileSync(atlasFile, 'utf8'));
const { w: W } = probe(blackFile);
const B = raw(blackFile), Wt = raw(whiteFile);
for (const e of atlas) {
  const buf = Buffer.alloc(e.w * e.h * 4);
  for (let y = 0; y < e.h; y++) {
    for (let x = 0; x < e.w; x++) {
      const i = ((e.y + y) * W + (e.x + x)) * 3;
      const o = (y * e.w + x) * 4;
      let a = 0;
      for (let c = 0; c < 3; c++) a += 1 - (Wt[i + c] - B[i + c]) / 255;
      a = Math.min(1, Math.max(0, a / 3));
      if (a < 0.03) a = 0;
      for (let c = 0; c < 3; c++) buf[o + c] = a > 0 ? Math.min(255, Math.round(B[i + c] / a)) : 0;
      buf[o + 3] = Math.round(a * 255);
    }
  }
  const name = e.key.replace(/[@,]/g, '_');
  const rawPath = path.join(outDir, name + '.rgba');
  fs.writeFileSync(rawPath, buf);
  execFileSync(FF, ['-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${e.w}x${e.h}`, '-i', rawPath, path.join(outDir, name + '.png')]);
  fs.unlinkSync(rawPath);
  console.log(`${e.key} -> ${name}.png (${e.w}x${e.h})`);
}
