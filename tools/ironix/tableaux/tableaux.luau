--!nocheck
-- Tableaux de valeurs de Steal a Shop (check-up a417, P3), lus dans les vraies sources (Config, Net/Definitions,
-- Contract/Tags). tools/ironix/tableaux.sh place ce fichier à la fin du fichier assemblé, après SOURCES et OPTIONS.
-- Il ne modifie rien et sort du markdown à coller dans le doc partagé (sections 4, 7, 9.4, 2.1).
-- Le faux Roblox et charge() sont dans ../commun/charge.luau, placé avant ce fichier.

-- 69000000 → « 69 000 000 » ; 0.42 → « 0.42 ».
local function n(value)
	if value == nil then
		return ""
	end
	if type(value) ~= "number" then
		return tostring(value)
	end
	if value ~= math.floor(value) or math.abs(value) >= 1e15 then
		return (string.gsub(string.format("%.6g", value), "%.?0+e", "e"))
	end
	local text = string.format("%d", math.abs(value))
	local out = ""
	while #text > 3 do
		out = " " .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return (if value < 0 then "-" else "") .. text .. out
end

local function cell(value)
	local text = if type(value) == "number" then n(value) else tostring(value == nil and "" or value)
	return (string.gsub(text, "|", "\\|"))
end

local function tableau(titre, colonnes, lignes)
	print(`### {titre}`)
	print("")
	print("| " .. table.concat(colonnes, " | ") .. " |")
	local sep = {}
	for i = 1, #colonnes do
		sep[i] = "---"
	end
	print("| " .. table.concat(sep, " | ") .. " |")
	for _, ligne in lignes do
		local cells = {}
		for i = 1, #colonnes do
			cells[i] = cell(ligne[i])
		end
		print("| " .. table.concat(cells, " | ") .. " |")
	end
	print("")
end

local function zones(z)
	if z == nil then
		return ""
	end
	return if z[1] == z[2] then tostring(z[1]) else `{z[1]} à {z[2]}`
end

local voulu = {}
for nom in string.gmatch(OPTIONS.Tableaux, "[^,%s]+") do
	voulu[string.lower(nom)] = true
end
local function veut(nom)
	return next(voulu) == nil or voulu[nom] == true
end

print(`<!-- Produit par tools/ironix/tableaux.sh depuis {OPTIONS.Base} ; ne pas retoucher à la main, relancer le script. -->`)
print("")

if veut("zones") then
	local Zones = charge("Config/Zones")
	local lignes = {}
	for _, z in Zones.List or Zones do
		if type(z) == "table" and z.Index then
			table.insert(lignes, { z.Index, z.Theme, z.City or "", table.concat(z.Stores, ", "), z.SpeedRequired, table.concat(z.Kit, " + "), z.AdvisedDamage, z.WindowHP, math.floor(z.AdvisedSpeed * 10 + 0.5) / 10, z.GuardSpeed, z.ReturnDistance })
		end
	end
	tableau("Zones (Config/Zones)", { "Zone", "Thème", "Ville", "Magasins", "Speed du panneau", "Kit", "Dégâts conseillés", "PV vitrine", "Marche conseillée", "Vigile", "Distance retour" }, lignes)
end

if veut("outils") then
	local Tools = charge("Config/Tools")
	local lignes = {}
	for _, t in Tools.List do
		table.insert(lignes, { t.Order, t.Id, t.DisplayName, t.Power, t.Price, zones(t.TargetZones), t.HitAnimation, t.Asset or "", t.RequiresRebirth or "" })
	end
	tableau("Outils (Config/Tools ; outils de renaissance seulement si Features.RebirthTools)", { "Rang", "Id", "Nom", "Puissance", "Prix ($)", "Zones", "Frappe", "Modèle", "Renaissances" }, lignes)
end

local function cosmetiques(titre, liste)
	local lignes = {}
	for _, c in liste do
		table.insert(lignes, { c.Order, c.Id, c.DisplayName, "×" .. n(c.Multiplier), c.Price, zones(c.TargetZones), c.Texture })
	end
	tableau(titre, { "Rang", "Id", "Nom", "Multiplicateur", "Prix ($)", "Zones", "Effet" }, lignes)
end

if veut("auras") then
	local Cosmetics = charge("Config/Cosmetics")
	cosmetiques("Auras en boutique (Config/Cosmetics.Auras)", Cosmetics.Auras)
end

if veut("trainees") then
	local Cosmetics = charge("Config/Cosmetics")
	cosmetiques("Traînées (Config/Cosmetics.Trails)", Cosmetics.Trails)
end

if veut("raretes") then
	local Rarities = charge("Config/Rarities")
	local lignes = {}
	for _, r in Rarities.List do
		table.insert(lignes, { r.Order, r.Id, r.DisplayName, r.ColorName, r.Color and r.Color.Hex or "", r.Income, r.OpenDelay, Rarities.GrabTime(r.Id), r.Halo, Rarities.FirstZone[r.Id] or "" })
	end
	tableau("Raretés (Config/Rarities)", { "Rang", "Id", "Nom", "Couleur", "Hex", "Revenu de base ($/s)", "Ouverture (s)", "Prise (s)", "Halo", "Première zone" }, lignes)
	local colonnes = { "Zone" }
	for _, r in Rarities.List do
		table.insert(colonnes, r.DisplayName)
	end
	local chances = {}
	for zone = 1, 6 do
		local odds = Rarities.ZoneOdds[zone] or {}
		local ligne = { zone }
		for _, r in Rarities.List do
			table.insert(ligne, if odds[r.Id] then n(odds[r.Id]) .. " %" else "")
		end
		table.insert(chances, ligne)
	end
	tableau("Rareté des colis par zone, en % (Config/Rarities.ZoneOdds)", colonnes, chances)
end

if veut("remotes") then
	local Definitions = charge("Net/Definitions")
	local lignes = {}
	for _, r in Definitions.List do
		local args = {}
		for _, a in r.Args do
			local borne = ""
			if a.Min or a.Max then
				borne = ` {n(a.Min or "")}..{n(a.Max or "")}`
			end
			table.insert(args, `{a.Name}: {a.Kind}{if a.Optional then "?" else ""}{borne}`)
		end
		local sens = if r.Direction == "ClientToServer" then "client → serveur" else "serveur → client"
		table.insert(lignes, { r.Name, sens, if r.Reliable then "oui" else "non", table.concat(args, ", "), r.RatePerSecond or "", r.Budget or "" })
	end
	tableau(`Remotes ({#Definitions.List}, Net/Definitions)`, { "Nom", "Sens", "Fiable", "Arguments", "Appels/s", "Budget" }, lignes)
end

if veut("interrupteurs") then
	local Features = charge("Config/Features")
	-- Ordre et commentaire de fin de ligne pris dans la source.
	local lignes, vus = {}, {}
	for nom, reste in string.gmatch(SOURCES["Config/Features"], "\n\t([%a_][%w_]*) = ([^\n]*)") do
		if Features[nom] ~= nil and not vus[nom] then
			vus[nom] = true
			local note = string.match(reste, "%-%-%s*(.*)$") or ""
			if #note > 140 then
				note = string.sub(note, 1, 137) .. "..."
			end
			table.insert(lignes, { nom, tostring(Features[nom]), note })
		end
	end
	for nom, valeur in Features do
		if not vus[nom] then
			table.insert(lignes, { nom, tostring(valeur), "" })
		end
	end
	tableau(`Interrupteurs ({#lignes}, Config/Features)`, { "Nom", "Valeur", "Note" }, lignes)
end

if veut("tags") then
	local Tags = charge("Contract/Tags")
	local lignes = {}
	for _, t in Tags.List do
		table.insert(lignes, { t.Tag, t.Count or "", t.PerZone or "", if t.NeedsZone then "oui" else "", t.For })
	end
	tableau("Tags du contrat (Contract/Tags)", { "Tag", "Nombre", "Par zone", "Attribut Zone", "Posé sur" }, lignes)
end
