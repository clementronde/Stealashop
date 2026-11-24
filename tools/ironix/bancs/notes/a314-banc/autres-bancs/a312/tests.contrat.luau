--!nocheck
-- Banc a312, partie « contrat » : Contract/UI d'avant (dedf84f, UI_AVANT) et du dépôt (UI_APRES), chargés tels quels.
-- C1 : chaque écran et billboard du contrat : la liste des éléments attendus (chemin, classe, Template, facultatif, note),
--      prise sur toutes ses entrées, est la même avant et après (union) ; l'écran reste exigé ou facultatif pareil
--      (exigé si une de ses entrées l'est).
-- C2 : après : BB_Item, UI_Index_v3, UI_Rewards, UI_Settings n'ont qu'une entrée ; aucun écran n'a deux entrées, sauf
--      UI_HUD (entrées à part voulues, toutes facultatives : bancs a85 K1f et a190) ; UI_HUD garde son 1er élément Cash et
--      son dernier SkillTreeButton.
-- C3 : après : aucun élément facultatif n'est attendu deux fois dans le même écran (la cause des avertissements comptés
--      deux fois) ; avant : la liste des doublons, et leur nombre.
local CHECKS, FAILS = 0, 0
local function check(ok, label)
	CHECKS += 1
	if ok then
		if VERBOSE then
			print("  ok  " .. label)
		end
	else
		FAILS += 1
		print("  ÉCHEC  " .. label)
	end
end

local function load(source, label)
	local fn, err = loadstring(source, "=" .. label)
	assert(fn, err)
	return fn()
end
local before = load(UI_AVANT, "UI_avant")
local after = load(UI_APRES, "UI_apres")

local function sig(e)
	return table.concat({ e.Path, tostring(e.Class), tostring(e.Template == true), tostring(e.Optional == true), tostring(e.Note) }, "|")
end
-- groups[kind][name] = { entries, required, set = { [sig] = count }, n }
local function groups(UI)
	local out = {}
	for _, kind in { "Screens", "Billboards" } do
		local g = {}
		for _, s in UI[kind] do
			local grp = g[s.Name]
			if grp == nil then
				grp = { entries = 0, required = false, set = {}, n = 0, class = s.Class, list = {} }
				g[s.Name] = grp
			end
			grp.entries += 1
			grp.required = grp.required or not s.Optional
			table.insert(grp.list, s)
			for _, e in s.Elements do
				local k = sig(e)
				grp.set[k] = (grp.set[k] or 0) + 1
				grp.n += 1
			end
		end
		out[kind] = g
	end
	return out
end
local gb, ga = groups(before), groups(after)

section = function(t)
	print("--- " .. t)
end

section("C1 : mêmes éléments attendus (union), même exigence, avant et après")
for _, kind in { "Screens", "Billboards" } do
	local names = {}
	for name in gb[kind] do
		names[name] = true
	end
	for name in ga[kind] do
		names[name] = true
	end
	for name in names do
		local b, a = gb[kind][name], ga[kind][name]
		local same = b ~= nil and a ~= nil and b.required == a.required and b.class == a.class
		local missing, extra = {}, {}
		if same then
			for k in b.set do
				if a.set[k] == nil then
					table.insert(missing, k)
				end
			end
			for k in a.set do
				-- a314 (copie) : noms facultatifs de la vente depuis l'écran Display (SellButton, Confirm…), voulus.
				local a314 = kind == "Screens"
					and name == "UI_Displayed"
					and (string.sub(k, 1, 8) == "Confirm|" or string.sub(k, 1, 8) == "Confirm." or string.sub(k, 1, 24) == "List.Template.SellButton")
					and string.find(k, "|false|", 1, true) ~= nil
				if b.set[k] == nil and not a314 then
					table.insert(extra, k)
				end
			end
		end
		check(same and #missing == 0 and #extra == 0, `{kind}.{name} : mêmes éléments ({#missing} perdu(s) {table.concat(missing, " ; ")}, {#extra} ajouté(s) {table.concat(extra, " ; ")}), {if a and a.required then "exigé" else "facultatif"}`)
	end
end
for _, name in { "BB_Item", "UI_Index_v3", "UI_Rewards", "UI_Settings" } do
	local kind = if name == "BB_Item" then "Billboards" else "Screens"
	local b, a = gb[kind][name], ga[kind][name]
	local distinct = 0
	for _ in a.set do
		distinct += 1
	end
	print(`  {name} : avant {b.entries} entrée(s), {b.n} élément(s) attendus ; après {a.entries} entrée(s), {a.n} élément(s), {distinct} distincts`)
end
-- Exemples précis (statut gardé) : BB_Item.Mutation exigé (venu de l'entrée facultative, contrôlé quand BB_Item est là),
-- Weight facultatif ; UI_Rewards.WeeklyChest facultatif ; UI_Index_v3.Rewards.ClaimButton.ClaimAlert exigé.
local function find(kind, name, path)
	for _, s in after[kind] do
		if s.Name == name then
			for _, e in s.Elements do
				if e.Path == path then
					return e
				end
			end
		end
	end
	return nil
end
local m = find("Billboards", "BB_Item", "Mutation")
check(m and not m.Optional and m.Class == "TextLabel", "BB_Item.Mutation : TextLabel, exigé (comme avant : entrée facultative, contrôlée quand BB_Item est là)")
local w = find("Billboards", "BB_Item", "Weight")
check(w and w.Optional, "BB_Item.Weight : facultatif")
local wc = find("Screens", "UI_Rewards", "WeeklyChest")
check(wc and wc.Optional, "UI_Rewards.WeeklyChest : facultatif")
local ta = find("Screens", "UI_Rewards", "Tabs.DailyTab.TabAlert")
check(ta and not ta.Optional, "UI_Rewards.Tabs.DailyTab.TabAlert : exigé")
local ca = find("Screens", "UI_Index_v3", "Rewards.ClaimButton.ClaimAlert")
check(ca and not ca.Optional, "UI_Index_v3.Rewards.ClaimButton.ClaimAlert : exigé")
local rg = find("Screens", "UI_Index_v3", "Rewards.ClaimButton.ReadyGradient")
check(rg and rg.Optional and rg.Class == "UIGradient", "UI_Index_v3.Rewards.ClaimButton.ReadyGradient : UIGradient facultatif")
local cb = find("Screens", "UI_Settings", "CodeBox")
check(cb and cb.Optional and cb.Class == "TextBox", "UI_Settings.CodeBox : TextBox facultatif")

section("C2 : une seule entrée par écran (sauf les entrées à part voulues d'UI_HUD)")
for _, kind in { "Screens", "Billboards" } do
	for name, a in ga[kind] do
		if name == "UI_HUD" then
			local optionalSides = true
			for i, s in a.list do
				if i > 1 and not s.Optional then
					optionalSides = false
				end
			end
			local main = a.list[1].Elements
			check(optionalSides and not a.list[1].Optional, `UI_HUD : {a.entries} entrées, la 1re exigée, les autres facultatives (comme avant : {gb[kind][name].entries})`)
			check(main[1].Path == "Cash" and main[#main].Path == "SkillTreeButton", `UI_HUD : 1er élément {main[1].Path}, dernier {main[#main].Path}`)
		else
			check(a.entries == 1, `{kind}.{name} : {a.entries} entrée(s) (avant : {gb[kind][name] and gb[kind][name].entries})`)
		end
	end
end

section("C3 : aucun élément attendu deux fois dans un même écran")
local function dupes(g)
	local list, warn = {}, 0
	for _, kind in { "Screens", "Billboards" } do
		for name, grp in g[kind] do
			-- même chemin attendu deux fois (toutes entrées confondues), quel que soit le reste
			local byPath = {}
			for _, s in grp.list do
				for _, e in s.Elements do
					byPath[e.Path] = byPath[e.Path] or {}
					table.insert(byPath[e.Path], e)
				end
			end
			for path, es in byPath do
				if #es > 1 then
					local opt = es[1].Optional == true
					if opt then
						warn += #es - 1
					end
					table.insert(list, `{name}.{path} ×{#es}{if opt then " (facultatif)" else " (exigé)"}`)
				end
			end
		end
	end
	table.sort(list)
	return list, warn
end
local db, wb = dupes(gb)
local da, wa = dupes(ga)
print(`  avant : {#db} chemin(s) attendus plusieurs fois, {wb} avertissement(s) en trop au plus (si tous manquent) :`)
for _, line in db do
	print("    " .. line)
end
check(#db > 0, `l'ancien contrat a bien des doublons ({#db})`)
check(#da == 0, `après : aucun chemin attendu deux fois ({#da} : {table.concat(da, " ; ")})`)

print(`banc a312 contrat : {CHECKS} vérification(s), {FAILS} échec(s)`)
