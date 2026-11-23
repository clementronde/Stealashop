// Relit l'historique local de la session et en sort les blocs @@UIEXPORT@@ (écrans) et @@ATLAS@@ (planches d'images).
// Usage : node extract.js <transcript.jsonl> <dossier de sortie>
const fs = require('fs');
const path = require('path');
const [, , transcript, outDir] = process.argv;
fs.mkdirSync(path.join(outDir, 'data'), { recursive: true });
fs.mkdirSync(path.join(outDir, 'atlas'), { recursive: true });

const texts = [];
for (const line of fs.readFileSync(transcript, 'utf8').split('\n')) {
  if (!line.includes('@@UIEXPORT@@') && !line.includes('@@ATLAS@@')) continue;
  let obj;
  try { obj = JSON.parse(line); } catch { continue; }
  const content = obj && obj.message && obj.message.content;
  if (!Array.isArray(content)) continue;
  for (const item of content) {
    if (item.type !== 'tool_result') continue;
    const parts = typeof item.content === 'string' ? [item.content] : (item.content || []).filter(c => c.type === 'text').map(c => c.text);
    const when = Date.parse(obj.timestamp || '') || 0;
    for (const p of parts) texts.push({ when, t: p });
  }
}

// réponses trop longues, que l'outil a enregistrées dans des fichiers à part (dossier tool-results de la session)
const resultsDir = transcript.replace(/\.jsonl$/, '') + path.sep + 'tool-results';
if (fs.existsSync(resultsDir)) {
  const files = fs.readdirSync(resultsDir).filter(f => f.endsWith('.txt')).map(f => path.join(resultsDir, f)).sort((a, b) => fs.statSync(a).mtimeMs - fs.statSync(b).mtimeMs);
  for (const f of files) { const t = fs.readFileSync(f, 'utf8'); if (t.includes('@@UIEXPORT@@') || t.includes('@@ATLAS@@')) texts.push({ when: fs.statSync(f).mtimeMs, t }); }
}

// du plus ancien au plus récent : le dernier relevé d'un écran l'emporte
texts.sort((a, b) => a.when - b.when);
const screens = {};
const atlases = {};
for (const { t } of texts) {
  for (const block of t.split('@@END@@')) {
    const ui = block.indexOf('@@UIEXPORT@@');
    const at = block.indexOf('@@ATLAS@@');
    if (ui >= 0) {
      const lines = block.slice(ui).split('\n').filter(l => l.length);
      const h = lines[0].split('\t');
      const [screen, part, total, size, order, count, keys] = [h[1], +h[2], +h[3], h[4], h[5], +h[6], (h[7] || '').split(' ').filter(Boolean)];
      if (!screen || !(count > 0) || !/^[0-9]+x[0-9]+$/.test(size || '')) continue; // faux bloc (texte qui cite la balise)
      const s = screens[screen] && screens[screen].size === size && screens[screen].count === count ? screens[screen] : (screens[screen] = { screen, size, order, count, total, keys, rows: {} });
      s.keys = keys; s.total = total;
      let dict = null;
      for (const l of lines.slice(1)) {
        if (l.startsWith('@@DICT@@')) { dict = {}; for (const kv of l.split('\t').slice(1)) { const k = kv.indexOf('='); if (k > 0) dict['§' + kv.slice(0, k)] = kv.slice(k + 1); } continue; }
        const f = l.split('\t');
        const idx = +f[0];
        if (!idx) continue;
        if (dict) {
          for (const i of [12, 14, 15, 17]) if (f[i] && f[i].startsWith('§') && dict[f[i]] !== undefined) f[i] = dict[f[i]];
          if (f[16] && f[16].startsWith('§')) { const a = f[16].indexOf('~'); const key = a < 0 ? f[16] : f[16].slice(0, a); if (dict[key] !== undefined) f[16] = dict[key] + (a < 0 ? '' : f[16].slice(a)); }
        }
        while (f.length < 18) f.push('');
        s.rows[idx] = f.join('\t');
      }
    } else if (at >= 0) {
      const lines = block.slice(at).split('\n').filter(l => l.length);
      const h = lines[0].split('\t');
      if (h[1]) atlases[h[1]] = lines.slice(1).map(l => { const f = l.split('\t'); return { key: f[0], x: +f[1], y: +f[2], w: +f[3], h: +f[4] }; });
    }
  }
}
for (const [name, s] of Object.entries(screens)) {
  const got = Object.keys(s.rows).length;
  fs.writeFileSync(path.join(outDir, 'data', name + '.json'), JSON.stringify(s));
  console.log(`${name}: ${got}/${s.count} lignes, ${s.keys.length} images, ${s.size}${got < s.count ? '  (INCOMPLET)' : ''}`);
}
for (const [name, a] of Object.entries(atlases)) {
  fs.writeFileSync(path.join(outDir, 'atlas', name + '.json'), JSON.stringify(a));
  console.log(`planche ${name}: ${a.length} images`);
}
