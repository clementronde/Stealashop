// Passe Figma après html_to_figma (à coller dans use_figma en remplaçant __DOCS__ et __EXPECT__).
// Chaque calque porte son numéro Studio (i=) ; chaque aide (__stroke, __img, __tile, __t) porte le numéro et le nom
// de son cadre (o=, lbl=). Si la conversion a fondu l'aide dans le cadre, le calque fondu reprend le nom du cadre.
// À la fin : chaque écran (⟦root=1;px;py⟧) est posé à sa place, l'ancienne copie du même nom est supprimée, et le
// nombre de cadres est comparé au nombre d'éléments relevés dans Studio.
const DOC_IDS = __DOCS__, EXPECT = __EXPECT__, PAGE_ID = "214:369";
const page = await figma.getNodeByIdAsync(PAGE_ID);
await figma.setCurrentPageAsync(page);
function parse(name) {
  const i = name.indexOf("⟦");
  if (i < 0) return { base: name, meta: {}, raw: "" };
  const j = name.lastIndexOf("⟧");
  const meta = {};
  for (const kv of name.slice(i + 1, j).split(";")) { const k = kv.indexOf("="); meta[k < 0 ? kv : kv.slice(0, k)] = k < 0 ? "" : kv.slice(k + 1); }
  return { base: name.slice(0, i), meta, raw: name.slice(i + 1, j) };
}
const isMark = f => f.type === "SOLID" && f.color.r > 0.99 && f.color.g < 0.01 && f.color.b > 0.99 && (f.opacity === undefined ? 1 : f.opacity) < 0.01;
const hex = h => ({ r: parseInt(h.slice(0, 2), 16) / 255, g: parseInt(h.slice(2, 4), 16) / 255, b: parseInt(h.slice(4, 6), 16) / 255 });
const imgFill = n => (n && "fills" in n && n.fills !== figma.mixed ? n.fills.find(f => f.type === "IMAGE") : null);
const findImg = n => imgFill(n) || ("findOne" in n ? imgFill(n.findOne(c => !!imgFill(c))) : null);
const hasTa = n => n && n.name && n.name.includes("⟦") && parse(n.name).meta.ta !== undefined;
const ownerOf = (n, meta) => { const p = n.parent; if (!p || !("name" in p)) return null; if (meta.o === undefined) return p; return parse(p.name).meta.i === meta.o ? p : null; };
const asOwner = (n, meta) => { n.name = decodeURIComponent(meta.lbl || "Frame") + "⟦i=" + meta.o + (meta.h === "1" ? ";h=1" : "") + "⟧"; };
const report = [];
for (const DOC_ID of DOC_IDS) {
  const doc = await figma.getNodeByIdAsync(DOC_ID);
  if (!doc) { report.push({ doc: DOC_ID, error: "document introuvable" }); continue; }
  const roots = doc.findAll(n => n.name.includes("⟦root=1") && !("findOne" in n && n.findOne(c => c.name.includes("⟦root=1"))))
    .map(r => Object.assign({ r }, parse(r.name)));
  const fontSet = new Map();
  for (const t of doc.findAllWithCriteria({ types: ["TEXT"] })) {
    if (t.fontName !== figma.mixed) fontSet.set(t.fontName.family + "|" + t.fontName.style, t.fontName);
    else for (const s of t.getStyledTextSegments(["fontName"])) fontSet.set(s.fontName.family + "|" + s.fontName.style, s.fontName);
  }
  for (const f of fontSet.values()) { try { await figma.loadFontAsync(f); } catch (e) {} }
  const depth = n => { let d = 0; for (let p = n; p && p !== doc; p = p.parent) d++; return d; };
  const all = doc.findAll(() => true).map(n => ({ n, d: depth(n) })).sort((a, b) => b.d - a.d).map(o => o.n);
  const stats = { strokes: 0, strokeMerged: 0, images: 0, imgMerged: 0, imgMissing: 0, tiles: 0, texts: 0, textMerged: 0, textMissing: 0, hidden: 0, nodes: 0 };
  for (const n of all) {
    if (n.removed) continue;
    let { base, meta } = parse(n.name);
    if (base.startsWith("__stroke")) {
      const owner = ownerOf(n, meta);
      const align = { o: "OUTSIDE", i: "INSIDE", c: "CENTER" }[meta.sa] || "INSIDE";
      if (owner && "strokes" in owner) {
        owner.strokes = n.strokes;
        owner.strokeWeight = +meta.sw > 0 ? +meta.sw : n.strokeWeight;
        owner.strokeAlign = align;
        n.remove(); stats.strokes++; continue;
      }
      if ("strokes" in n) { if (+meta.sw > 0) n.strokeWeight = +meta.sw; n.strokeAlign = align; }
      asOwner(n, meta); stats.strokeMerged++;
      ({ base, meta } = parse(n.name));
    } else if (base.startsWith("__img") || base.startsWith("Image (__img") || base.startsWith("__tile")) {
      const tile = base.startsWith("__tile");
      const owner = ownerOf(n, meta);
      const img = findImg(n);
      let paint = null;
      if (img) {
        if (tile) {
          paint = { type: "IMAGE", imageHash: img.imageHash, scaleMode: "FILL", opacity: +meta.op >= 0 ? +meta.op : 1 };
          try { const size = await figma.getImageByHash(img.imageHash).getSizeAsync(); if (+meta.tw > 0) paint = { type: "IMAGE", imageHash: img.imageHash, scaleMode: "TILE", scalingFactor: +meta.tw / size.width, opacity: paint.opacity }; } catch (e) {}
        } else {
          paint = { type: "IMAGE", imageHash: img.imageHash, opacity: +meta.op >= 0 ? +meta.op : 1, scaleMode: meta.fit === "F" ? "FIT" : meta.fit === "C" ? "FILL" : "CROP" };
          if (paint.scaleMode === "CROP") paint.imageTransform = [[1, 0, 0], [0, 1, 0]];
        }
      } else stats.imgMissing++;
      if (owner && "fills" in owner) {
        if (paint) owner.fills = [...owner.fills.filter(f => !isMark(f)), paint];
        tile ? stats.tiles++ : stats.images++;
        n.remove(); continue;
      }
      if (paint && "fills" in n) n.fills = [...n.fills.filter(f => !isMark(f) && f.type !== "IMAGE"), paint];
      asOwner(n, meta); stats.imgMerged++;
      ({ base, meta } = parse(n.name));
    } else if (n.type === "TEXT") {
      let holder = null;
      for (let a = n.parent, i = 0; a && a !== doc && i < 5; a = a.parent, i++) { if (hasTa(a)) { holder = a; break; } }
      if (!holder) { stats.textMissing++; continue; }
      let label = holder, pads = true;
      const hp = parse(holder.name);
      if (hp.base.startsWith("__t")) {
        if (hasTa(holder.parent) && parse(holder.parent.name).meta.i === hp.meta.o) label = holder.parent;
        else {
          const rest = hp.raw.split(";").filter(kv => !kv.startsWith("lbl=") && !kv.startsWith("o=")).join(";");
          holder.name = decodeURIComponent(hp.meta.lbl || "Text") + "⟦i=" + hp.meta.o + ";" + rest + "⟧";
          pads = false; stats.textMerged++;
        }
      }
      const pm = parse(label.name).meta;
      const t = n;
      const wrappers = [];
      for (let a = t.parent; a && a !== label; a = a.parent) wrappers.push(a);
      if ("layoutMode" in label && label.layoutMode !== "NONE") label.layoutMode = "NONE";
      label.appendChild(t);
      for (const w of wrappers) if (!w.removed && "children" in w && w.children.length === 0) w.remove();
      let [xa, ya, pl, pt, pr, pb, tbx, tby, sc] = (pm.ta || "C,C,0,0,0,0,0,0,0").split(",");
      if (!pads) { pl = pt = pr = pb = 0; }
      const W = Math.max(1, label.width - +pl - +pr), H = Math.max(1, label.height - +pt - +pb);
      if (t.fontName !== figma.mixed) {
        t.lineHeight = { unit: "PERCENT", value: 120 };
        if (+sc === 1 && pm.wr === "1") {
          const target = (+tby > 0 ? +tby : H) + 2;
          t.textAutoResize = "HEIGHT"; t.resize(W, t.height);
          let lo = 1, hi = 100;
          for (let k = 0; k < 9; k++) { const mid = (lo + hi) / 2; t.fontSize = mid; if (t.height <= target) lo = mid; else hi = mid; }
          t.fontSize = Math.max(1, Math.floor(lo * 10) / 10);
        } else if (+tbx > 0) {
          t.textAutoResize = "WIDTH_AND_HEIGHT";
          if (t.width > 0) t.fontSize = Math.max(1, Math.round(t.fontSize * (+tbx / t.width) * 10) / 10);
        }
      }
      t.textAutoResize = "NONE";
      t.resize(W, H);
      t.x = +pl; t.y = +pt;
      t.textAlignHorizontal = { L: "LEFT", C: "CENTER", R: "RIGHT" }[xa] || "CENTER";
      t.textAlignVertical = { T: "TOP", C: "CENTER", B: "BOTTOM" }[ya] || "CENTER";
      if (pm.ts) {
        const [c, px, a, factor] = pm.ts.split(",");
        const fs = t.fontSize !== figma.mixed ? t.fontSize : 0;
        t.strokes = [{ type: "SOLID", color: hex(c), opacity: +a }];
        t.strokeWeight = Math.max(0.5, +factor > 0 && fs > 0 ? Math.round(+factor * fs * 10) / 10 : +px);
        t.strokeAlign = "OUTSIDE";
      }
      if (pm.tg) {
        const [rot, stops] = pm.tg.split("|");
        const th = (+rot) * Math.PI / 180, a = Math.cos(th), b = Math.sin(th);
        t.fills = [{ type: "GRADIENT_LINEAR", gradientTransform: [[a, b, (1 - a - b) / 2], [-b, a, (1 + b - a) / 2]], gradientStops: stops.split("!").map(s => { const [tt, hx, al] = s.split("_"); return { position: +tt, color: Object.assign(hex(hx), { a: +al }) }; }) }];
      }
      t.name = t.characters.slice(0, 40);
      stats.texts++;
      continue;
    }
    if ("fills" in n && n.fills !== figma.mixed && n.fills.some(isMark)) n.fills = n.fills.filter(f => !isMark(f));
    if (n.name.includes("⟦")) n.name = base;
    if (meta.h === "1") { n.visible = false; stats.hidden++; }
    stats.nodes++;
  }
  const placed = [], mismatch = [];
  for (const { r, base, meta } of roots) {
    page.appendChild(r);
    r.x = +meta.px || 0; r.y = +meta.py || 0; r.name = base;
    if ("clipsContent" in r) r.clipsContent = meta.noclip !== "1";
    for (const old of page.children.filter(c => c.name === base && c !== r && c.type === "FRAME")) old.remove();
    const frames = r.findAllWithCriteria({ types: ["FRAME"] }).length;
    if (EXPECT[base] !== undefined && frames !== EXPECT[base]) mismatch.push(base + " " + frames + "/" + EXPECT[base]);
    placed.push(base);
  }
  doc.remove();
  report.push(Object.assign({ doc: DOC_ID, placed: placed.length, mismatch }, stats));
}
return report;
