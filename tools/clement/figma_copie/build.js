// Construit une page HTML avec un ou plusieurs écrans relevés dans Studio, prête pour html_to_figma.
// Noms des calques : aria-label. Ce que la conversion ne garde pas est noté en fin de nom, entre ⟦ ⟧, et appliqué
// après l'import par la passe Figma (passe.js) :
//   root=1;px;py[;noclip=1] racine d'un écran et sa place sur la page Figma ; i=n numéro Studio du calque ; h=1 caché
//   ta=xa,ya,pl,pt,pr,pb,tbx,tby,sc (texte : alignements, marges, boîte réelle du texte dans Studio, adapté) ; wr=1 à la ligne
//   ts=hex,px,alpha,facteur (contour du texte) ; tg=… (dégradé du texte) ; v3d=1 (aperçu 3D)
//   aides, avec o=n;lbl=nom du cadre propriétaire : __stroke⟦…;sa=o|i|c;sw=px⟧ contour ; __img⟦…;fit=F|C|S;op⟧ image ;
//   __tile⟦…;tw;th;op⟧ mosaïque ; __t⟦o;lbl;ta…⟧ texte. La conversion fond parfois une aide dans son cadre (un cadre dont
//   le seul enfant est son contour, un texte qui remplit son cadre) : la passe le reconnaît à o= et rend le nom au cadre.
// Chaque cadre sans style reçoit un fond presque invisible (#FF00FF à 0,3 %), sinon la conversion le supprime ; la passe
// l'enlève. Chaque image n'est écrite qu'une fois, dans une classe CSS. Les écrans sont empilés en position absolue
// (une marge ajouterait un cadre autour de chacun).
// Usage : [NOCLIP=UI_HUD] node build.js <sortie.html> <dossier images> <écran.json>@px,py [<écran.json>@px,py …]
// NOCLIP : écrans dont des éléments sortent du cadre exprès ; sans coupe, sinon la conversion supprime ces éléments.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const FF = path.join(process.env.LOCALAPPDATA, 'Microsoft', 'WinGet', 'Links', 'ffmpeg.exe');
const [, , outFile, imgDir, ...specs] = process.argv;
// écrans dont des éléments sortent volontairement du cadre (ex. TopLeftRow du HUD, dans la barre du haut de Roblox) :
// pas de coupe, sinon la conversion supprime ces éléments
const NOCLIP = (process.env.NOCLIP || '').split(',').filter(Boolean);

const FONTS = { Montserrat: 'Montserrat', FredokaOne: 'Fredoka One', Fredoka: 'Fredoka', LuckiestGuy: 'Luckiest Guy', GothamSSm: 'Montserrat', Gotham: 'Montserrat', BuilderSans: 'Montserrat', SourceSansPro: 'Source Sans Pro', LegacyArial: 'Arial', Arial: 'Arial', Roboto: 'Roboto', RobotoMono: 'Roboto Mono', Bangers: 'Bangers', Nunito: 'Nunito', Oswald: 'Oswald', PermanentMarker: 'Permanent Marker', Ubuntu: 'Ubuntu', TitilliumWeb: 'Titillium Web', Michroma: 'Michroma', Sarpanch: 'Sarpanch', SpecialElite: 'Special Elite', Merriweather: 'Merriweather', DenkOne: 'Denk One', Kalam: 'Kalam', GrenzeGotisch: 'Grenze Gotisch', Creepster: 'Creepster', IndieFlower: 'Indie Flower', JosefinSans: 'Josefin Sans', AmaticSC: 'Amatic SC', Bodoni: 'Bodoni Moda', HighwayGothic: 'Montserrat', Arimo: 'Arimo', Inconsolata: 'Inconsolata' };
const MARK = 'background:rgba(255,0,255,0.003)';

const unesc = s => s.replace(/\\(\\|t|n)/g, (_, c) => (c === 't' ? '\t' : c === 'n' ? '\n' : '\\'));
const html = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const hexRgb = h => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
const rgba = (rgb, a) => `rgba(${rgb[0]},${rgb[1]},${rgb[2]},${Math.round(a * 1000) / 1000})`;
function seq(str) { return str ? str.split(',').map(p => { const [t, v] = p.split(':'); return [+t, v]; }) : []; }
function colorAt(stops, t) {
  if (!stops.length) return [255, 255, 255];
  if (t <= stops[0][0]) return hexRgb(stops[0][1]);
  for (let i = 0; i < stops.length - 1; i++) {
    const [ta, ca] = stops[i], [tb, cb] = stops[i + 1];
    if (t <= tb) { const f = (t - ta) / Math.max(1e-6, tb - ta); const A = hexRgb(ca), B = hexRgb(cb); return A.map((v, k) => Math.round(v + (B[k] - v) * f)); }
  }
  return hexRgb(stops[stops.length - 1][1]);
}
function numAt(stops, t) {
  if (!stops.length) return 0;
  if (t <= stops[0][0]) return +stops[0][1];
  for (let i = 0; i < stops.length - 1; i++) {
    const [ta, va] = stops[i], [tb, vb] = stops[i + 1];
    if (t <= tb) { const f = (t - ta) / Math.max(1e-6, tb - ta); return +va + (+vb - +va) * f; }
  }
  return +stops[stops.length - 1][1];
}
function gradientStops(grad, baseRgb, baseAlpha) {
  const [rot, off, cstr, tstr] = grad.split(';');
  const cs = seq(cstr), ts = seq(tstr);
  const r = (+rot) * Math.PI / 180;
  const [ox, oy] = (off || '0,0').split(',').map(Number);
  const shift = ox * Math.cos(r) + oy * Math.sin(r);
  const times = [...new Set([...cs.map(s => s[0]), ...ts.map(s => s[0]), 0, 1])].sort((a, b) => a - b);
  return { rot: +rot, stops: times.map(t => { const src = Math.min(1, Math.max(0, t - shift)); return [t, colorAt(cs, src).map((v, k) => Math.round(v * baseRgb[k] / 255)), baseAlpha * (1 - numAt(ts, src))]; }) };
}
const cssGradient = g => `linear-gradient(${90 + g.rot}deg, ${g.stops.map(s => `${rgba(s[1], s[2])} ${Math.round(s[0] * 1000) / 10}%`).join(', ')})`;
const packGradient = g => g.rot + '|' + g.stops.map(s => `${s[0]}_${s[1].map(v => v.toString(16).padStart(2, '0')).join('')}_${Math.round(s[2] * 100) / 100}`).join('!');

// une classe CSS par image (et par teinte), écrite une seule fois dans <style>
const classes = {};
const styleRules = [];
function imageClass(key, tintHex) {
  const name = key.replace(/[@,]/g, '_');
  const file = path.join(imgDir, name + '.png');
  if (!fs.existsSync(file)) return null;
  const ck = name + '|' + (tintHex || '').toLowerCase();
  if (classes[ck]) return classes[ck];
  let buf = fs.readFileSync(file);
  if (tintHex && tintHex.toLowerCase() !== 'ffffff') {
    const [tr, tg, tb] = hexRgb(tintHex);
    const tmp = path.join(imgDir, '_tint', `${name}_${tintHex}.png`);
    fs.mkdirSync(path.dirname(tmp), { recursive: true });
    if (!fs.existsSync(tmp)) execFileSync(FF, ['-v', 'error', '-y', '-i', file, '-vf', `format=rgba,colorchannelmixer=rr=${(tr / 255).toFixed(4)}:gg=${(tg / 255).toFixed(4)}:bb=${(tb / 255).toFixed(4)}`, tmp]);
    buf = fs.readFileSync(tmp);
  }
  const cls = 'm' + styleRules.length;
  styleRules.push(`.${cls}{background-image:url(data:image/png;base64,${buf.toString('base64')})}`);
  return (classes[ck] = cls);
}

const missing = new Set();
let totalRows = 0;
function renderScreen(data, px, py) {
  const rows = Object.values(data.rows).map(l => l.split('\t'));
  totalRows += rows.length;
  const nodes = {};
  for (const f of rows) nodes[+f[0]] = { f, kids: [] };
  const roots = [];
  for (const f of rows) { const p = +f[1]; if (p && nodes[p]) nodes[p].kids.push(nodes[+f[0]]); else roots.push(nodes[+f[0]]); }

  function render(node) {
    const [idx, , rawName, cls, x, y, w, h, rot, vis, clip, z, bg, corner, stroke, grad, text, img] = node.f;
    const meta = ['i=' + idx];
    const own = 'o=' + idx + ';lbl=' + encodeURIComponent(unesc(rawName)) + (vis === '0' ? ';h=1' : '');
    if (vis === '0') meta.push('h=1');
    const st = ['position:absolute', `left:${x}px`, `top:${y}px`, `width:${w}px`, `height:${h}px`, `z-index:${z}`, 'box-sizing:border-box'];
    if (rot) st.push(`transform:rotate(${rot}deg)`);
    if (clip === '1') st.push('overflow:hidden');
    let baseRgb = [255, 255, 255], baseA = 0;
    if (bg) { const [hx, a] = bg.split(','); baseRgb = hexRgb(hx); baseA = +a; }
    const isText = cls === 'T' || cls === 'B' || cls === 'X';
    let styled = false;
    if (grad && baseA > 0) { st.push(`background:${cssGradient(gradientStops(grad, baseRgb, baseA))}`); styled = true; }
    else if (baseA > 0) { st.push(`background:${rgba(baseRgb, baseA)}`); styled = true; }
    if (corner) st.push(`border-radius:${corner}px`);
    if (cls === 'V') { st.push('background:rgba(20,20,30,0.25)'); styled = true; meta.push('v3d=1'); }
    if (!styled) st.push(MARK);
    let inner = '';
    if (stroke) {
      const [hx, spx, pos, a] = stroke.split(',');
      inner += `<div aria-label="__stroke⟦${html(own)};sa=${pos};sw=${spx}⟧" style="position:absolute;left:0;top:0;width:100%;height:100%;box-sizing:border-box;border:${Math.max(1, Math.round(+spx))}px solid ${rgba(hexRgb(hx), +a)}${corner ? `;border-radius:${corner}px` : ''}"></div>`;
    }
    if (isText && text) {
      const [props, tstroke, rawText] = text.split('~');
      const content = unesc(rawText || '');
      if (content.length) {
        const [fam, weight, italic, size, hx, a, xa, ya, wrap, pads, scaled, tb] = props.split(',');
        const [pl, pt, pr, pb] = (pads || '0;0;0;0').split(';').map(Number);
        const [tbx, tby] = (tb || '0x0').split('x').map(Number);
        const lines = content.split('\n').length;
        const fontSize = Math.max(1, (scaled === 's' ? (tby || +size) / lines / 1.25 : +size));
        meta.push(`ta=${xa},${ya},${pl || 0},${pt || 0},${pr || 0},${pb || 0},${tbx},${tby},${scaled === 's' ? 1 : 0}`);
        if (tstroke) {
          const [shx, th, mode, sa] = tstroke.split(',');
          meta.push(`ts=${shx},${Math.round((mode === 's' ? +th * fontSize : +th) * 10) / 10},${sa},${mode === 's' ? +th : 0}`);
        }
        if (grad) meta.push('tg=' + packGradient(gradientStops(grad, [255, 255, 255], 1)));
        if (wrap === 'w') meta.push('wr=1');
        const tlabel = '__t⟦' + ['o=' + idx, 'lbl=' + encodeURIComponent(unesc(rawName)), ...meta.filter(m => !m.startsWith('i='))].join(';') + '⟧';
        const al = { L: 'flex-start', C: 'center', R: 'flex-end' }[xa] || 'center';
        const va = { T: 'flex-start', C: 'center', B: 'flex-end' }[ya] || 'center';
        inner += `<div aria-label="${html(tlabel)}" style="position:absolute;left:${pl || 0}px;top:${pt || 0}px;right:${pr || 0}px;bottom:${pb || 0}px;display:flex;align-items:${va};justify-content:${al}">` +
          `<span style="font-family:'${FONTS[fam] || 'Montserrat'}';font-weight:${weight};${italic ? 'font-style:italic;' : ''}font-size:${Math.round(fontSize * 10) / 10}px;line-height:1.15;color:${rgba(hexRgb(hx), +a)};white-space:${wrap && lines > 1 ? 'pre-wrap' : 'pre'};text-align:${{ L: 'left', C: 'center', R: 'right' }[xa] || 'center'}">${html(content)}</span></div>`;
      }
    }
    if ((cls === 'I' || cls === 'J') && img) {
      const [key, tint, a, scale, tw, th] = img.split(',');
      const ic = imageClass(key, tint);
      if (!ic) missing.add(key);
      else if (scale === 'T' && +tw > 0 && +th > 0) {
        inner += `<div aria-label="__tile⟦${html(own)};tw=${tw};th=${th};op=${a}⟧" class="${ic}" style="position:absolute;left:0;top:0;width:100%;height:100%;opacity:${a};background-repeat:repeat;background-size:${tw}px ${th}px"></div>`;
      } else {
        const size = { F: 'contain', C: 'cover' }[scale] || '100% 100%';
        inner += `<div aria-label="__img⟦${html(own)};fit=${scale || 'S'};op=${a}⟧" class="${ic}" style="position:absolute;left:0;top:0;width:100%;height:100%;opacity:${a};background-repeat:no-repeat;background-position:center;background-size:${size}"></div>`;
      }
    }
    const kids = node.kids.slice().sort((p, q) => (+p.f[11]) - (+q.f[11])).map(render).join('');
    const label = unesc(rawName) + (meta.length ? '⟦' + meta.join(';') + '⟧' : '');
    return `<div aria-label="${html(label)}" style="${st.join(';')}">${inner}${kids}</div>`;
  }

  const [W, H] = data.size.split('x').map(Number);
  const body = roots.sort((a, b) => (+a.f[11]) - (+b.f[11])).map(render).join('');
  const noclip = NOCLIP.includes(data.screen);
  return { W, H, html: top => `<div aria-label="${data.screen}⟦root=1;px=${px};py=${py}${noclip ? ';noclip=1' : ''}⟧" style="position:absolute;left:0;top:${top}px;width:${W}px;height:${H}px;${noclip ? '' : 'overflow:hidden;'}${MARK}">${body}</div>` };
}

const parts = specs.map(s => {
  const at = s.lastIndexOf('@');
  const file = at > 0 ? s.slice(0, at) : s;
  const [px, py] = at > 0 ? s.slice(at + 1).split(',').map(Number) : [0, 0];
  return renderScreen(JSON.parse(fs.readFileSync(file, 'utf8')), px, py);
});
const W = Math.max(...parts.map(p => p.W));
let top = 200;
const stacked = parts.map(p => { const h = p.html(top); top += p.H + 200; return h; });
const doc = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;width:${W}px;height:${top}px;background:transparent}body{position:relative}${styleRules.join('')}</style></head><body>` +
  stacked.join('') + `</body></html>`;
fs.writeFileSync(outFile, doc);
console.log(`${path.basename(outFile)} : ${parts.length} écran(s), ${totalRows} éléments, ${styleRules.length} images, ${(doc.length / 1024).toFixed(0)} Ko${missing.size ? ', images manquantes : ' + [...missing].join(' ') : ''}`);
