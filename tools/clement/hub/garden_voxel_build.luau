-- Décor voxel du jardin du hub (Clément, 2026-11-24 : « j'aimais bien le rendu voxel », « tu peux joindre les modèles faits
-- par Claude Design »). Reconstruit en Parts à tenons (Plastic + Studs), boîte par boîte, les modèles de Claude Design :
-- pack 1 (sans la fontaine ni le petit rocher), pack 2 (trophée, jardinière en marbre, champignons) et les 3 rochers
-- low-poly passés en voxels (silhouette de vrai caillou, dessus clair, bas sombre, mousse). Rien n'est téléversé.
-- À lancer dans Studio (MCP execute_luau, mode Edit) APRÈS tools/clement/hub/garden_voxel_data.luau (données générées par
-- tools/clement/hub/garden_voxel_convert depuis les GLB : StealAShop-Art/Env/Garden/VoxelGardenPack_2026-11-24,
-- VoxelGardenPack2_2026-11-24 et LowPolyRocks_2026-11-24). Ensuite : hub_jardin_deco.luau pose la déco dans le hub.
-- Range un modèle par objet dans ServerStorage/Assets/Env/Garden (refait à chaque lancement) :
--  - pivot au centre-bas, avant vers -Z ; tailles finales (ÉCHELLE ci-dessous, Clément trouvait le pack 1 trop petit) ;
--  - parties qui bougent au vent : Model `Sway_*` (pivot à son centre-bas), sans collision ni requête ; le modèle porte le
--    tag WindSway et l'attribut SwayAngle (degrés), pour le code d'Ironix (L-321 ; référence
--    docs/claude/references/jardin/GardenVFX.lua) ; ModelStreamingMode Atomic ;
--  - collisions seulement sur ce qui doit arrêter un joueur (rochers, tronc, lampadaire, banc, clôture, trophée,
--    jardinière) ; le reste en décor (ni collision, ni toucher, ni requête). Aucun script.
local rgb = Color3.fromHex
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local DATA = _G.ClaudeGardenVoxel
assert(DATA, "envoyer garden_voxel_data.luau d'abord")

local SCALE = {
	ENV_Nature_Bush_Berry = 1.5, ENV_Nature_Bush_Cone = 1.5, ENV_Nature_Bush_Flower = 1.5, ENV_Nature_Bush_Hedge = 1.5,
	ENV_Nature_Bush_Round = 1.5, ENV_Nature_Bush_TallGrass = 1.5, ENV_Nature_Flower_Daisy = 1.4, ENV_Nature_Flower_Tulip = 1.4,
	ENV_Nature_Flower_Sunflower = 1.2, ENV_Nature_Mushroom = 1.6, ENV_Nature_Tree_Oak = 1.4, ENV_Prop_LampPost = 1.4,
	ENV_Prop_Fence = 1.2, ENV_Prop_Bench = 1, ENV_Prop_Planter_Marble = 1.25, ENV_Prop_Statue_Trophy = 1.15,
	ENV_Nature_Mushroom_Cluster = 1.25, ENV_Nature_Rock_Boulder = 1, ENV_Nature_Rock_Cluster = 1.2,
	ENV_Nature_Rock_SteppingStones = 1.2,
}
local SWAY_ANGLE = { ENV_Nature_Bush_TallGrass = 6, ENV_Nature_Flower_Tulip = 4, ENV_Nature_Flower_Daisy = 4,
	ENV_Nature_Flower_Sunflower = 3, ENV_Nature_Tree_Oak = 1.5 }
-- rochers un peu plus foncés que dans les GLB (presque blancs sous la lumière du hub)
local ROCK = { Rock = "959CA7", RockTop = "AEB4BE", RockDark = "7A818C" }
-- pièces pleines (le reste en décor)
local SOLID = {
	ENV_Nature_Rock_Boulder = true, ENV_Nature_Rock_Cluster = true, ENV_Prop_Bench = true, ENV_Prop_Fence = true,
	ENV_Prop_Statue_Trophy = true, ENV_Prop_Planter_Marble = { Marble = true, Gold = true, Base = true },
	ENV_Nature_Tree_Oak = { Trunk = true }, ENV_Prop_LampPost = { Post = true },
}

local env = SS:FindFirstChild("Assets") and SS.Assets:FindFirstChild("Env")
assert(env, "ServerStorage/Assets/Env introuvable")
local old = env:FindFirstChild("Garden"); if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "Garden"
folder:SetAttribute("Note", "Décor voxel du jardin du hub (garden_voxel_build.luau) : modèles de Claude Design refaits en Parts à tenons. Pivot au centre-bas, avant vers -Z.")

local report, total = {}, 0
local names = {}
for name in DATA do table.insert(names, name) end
table.sort(names)
for _, name in names do
	local rows = DATA[name]
	local k = SCALE[name] or 1
	local m = Instance.new("Model"); m.Name = name
	local groups = {}
	local function groupOf(path)
		if path == "" then return m end
		local g = groups[path]
		if g then return g end
		local parent = m
		local acc = ""
		for seg in string.gmatch(path, "[^/]+") do
			acc = acc == "" and seg or acc .. "/" .. seg
			local found = groups[acc]
			if not found then
				found = Instance.new("Model"); found.Name = seg; found.Parent = parent
				groups[acc] = found
			end
			parent = found
		end
		return parent
	end
	local solid = SOLID[name]
	local nParts = 0
	for _, r in rows do
		local grp, pname = r[1], r[2]
		-- touffes livrées comme pièces Sway_* directement sous la racine (haie, hautes herbes) : groupe Sway_* à leur nom
		if grp == "" and pname:sub(1, 5) == "Sway_" then grp, pname = pname, "Tuft" end
		local cx, cy, cz, sx, sy, sz, col = r[3] * k, r[4] * k, r[5] * k, r[6] * k, r[7] * k, r[8] * k, r[9]
		local p = Instance.new("Part"); p.Name = pname; p.Anchored = true
		p.Size = Vector3.new(math.max(sx, 0.05), math.max(sy, 0.05), math.max(sz, 0.05))
		if r[10] then
			p.CFrame = CFrame.new(cx, cy, cz, r[10], r[11], r[12], r[13], r[14], r[15], r[16], r[17], r[18])
		else
			p.CFrame = CFrame.new(cx, cy, cz)
		end
		if name:match("^ENV_Nature_Rock") and ROCK[pname] then col = ROCK[pname] end
		p.Color = rgb(col); p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		local isSolid = grp:sub(1, 5) ~= "Sway_" and (solid == true or (type(solid) == "table" and solid[pname] == true))
		p.CanCollide = isSolid; p.CanQuery = isSolid; p.CanTouch = false
		p.CastShadow = isSolid or math.min(sx, sy, sz) >= 0.6
		p.Parent = groupOf(grp)
		nParts += 1
	end
	-- pivots : modèle à l'origine (centre-bas), groupes Sway_ à leur centre-bas
	m.WorldPivot = CFrame.new()
	local nSway = 0
	for path, g in groups do
		local cf, size = g:GetBoundingBox()
		g.WorldPivot = CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z)
		if g.Name:sub(1, 5) == "Sway_" then nSway += 1 end
	end
	if nSway > 0 then
		CS:AddTag(m, "WindSway")
		m:SetAttribute("SwayAngle", SWAY_ANGLE[name] or 3)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	local _, size = m:GetBoundingBox()
	m:SetAttribute("Source", "Claude Design, refait en voxels")
	m.Parent = folder
	total += nParts
	table.insert(report, string.format("%s : %d pièces, %.1f × %.1f × %.1f%s", name, nParts, size.X, size.Z, size.Y,
		nSway > 0 and (" , " .. nSway .. " Sway_") or ""))
end
folder.Parent = env
return string.format("%d modèles, %d pièces dans ServerStorage/Assets/Env/Garden\n%s", #names, total, table.concat(report, "\n"))
