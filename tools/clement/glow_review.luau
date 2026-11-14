--[[
	glow_review.luau (Clément, 2026-11-12, étendu à tout le jeu le 2026-11-13) : direction « moins
	lumineux », en Edit. Chaque valeur changée garde l'ancienne dans un attribut AncienGlow_<propriété>
	(les tags ajoutés : AncienGlow_Tag_<tag>). MODE = "revert" remet tout comme avant.
	Relançable : une valeur déjà sauvegardée n'est pas écrasée. Aucun script laissé dans la place.

	1. Lighting : exposition 0 ; Bloom 0,25 / 18 / 2,6 ; saturation 0,12, contraste 0,1, teinte
	   blanche ; Atmosphere 0,2, voile 0,2, éblouissement 0 ; SunRays 0,02.
	2. Map (zones et hub) : les néons de décor passent en SmoothPlastic le jour, avec le tag
	   NightLight (SkyController les remet en néon la nuit). Gardés en néon : plafonniers
	   (CeilingLight*), écrans (Screen), présentoirs de la boutique d'auras (AuraSwatch, Orb, Star,
	   Handle), murs et arches du contrat (ZoneGate, NightWall), et ce qui a déjà le tag NightLight.
	3. Boutiques (Map et gabarits PLOT_Shop, PLOT_Shop_Rayons) : plaques CollectPad en vert plein
	   (76, 214, 72), néons du RarestPedestal en couleur pleine le jour.
	4. Tapis (gabarits PLOT_Treadmill_* et tapis posés) au repos : particules à LightEmission 0,5 au
	   plus et Rate divisé par 2, lumières à 2 au plus. En course, c'est Config/TreadmillFX (Ironix).
]]

local MODE = "apply" -- "apply" ou "revert"

local CS = game:GetService("CollectionService")
local L = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local P = "AncienGlow_"
local rgb = Color3.fromRGB

local plots = RS.Assets:FindFirstChild("Plots")
local roots: { Instance } = { L, workspace.Map }
if plots then table.insert(roots, plots) end

local function save(obj: Instance, prop: string)
	if obj:GetAttribute(P .. prop) ~= nil then return end
	local v = (obj :: any)[prop]
	if typeof(v) == "EnumItem" then v = "Enum:" .. v.Name end
	obj:SetAttribute(P .. prop, v)
end
local function set(obj: Instance, prop: string, value: any)
	save(obj, prop)
	local o: any = obj
	o[prop] = value
end
local function addTag(obj: Instance, tag: string)
	if CS:HasTag(obj, tag) then return end
	obj:SetAttribute(P .. "Tag_" .. tag, true)
	CS:AddTag(obj, tag)
end
local function restore(d: Instance): number
	local n = 0
	for k, v in d:GetAttributes() do
		if k:sub(1, #P) ~= P then continue end
		local prop = k:sub(#P + 1)
		if prop:sub(1, 4) == "Tag_" then
			CS:RemoveTag(d, prop:sub(5))
		elseif type(v) == "string" and v:sub(1, 5) == "Enum:" then
			local o: any = d
			o[prop] = (o[prop].EnumType :: any)[v:sub(6)]
		else
			local o: any = d
			o[prop] = v
		end
		d:SetAttribute(k, nil)
		n += 1
	end
	return n
end

if MODE == "revert" then
	local n = 0
	for _, root in roots do
		n += restore(root)
		for _, d in root:GetDescendants() do n += restore(d) end
	end
	return "revert : " .. n .. " réglages remis"
end

local report = {}

-- 1. Lighting ------------------------------------------------------------------------------------
set(L, "ExposureCompensation", 0)
local bloom = L:FindFirstChildOfClass("BloomEffect")
if bloom then set(bloom, "Intensity", 0.25); set(bloom, "Size", 18); set(bloom, "Threshold", 2.6) end
local cc = L:FindFirstChildOfClass("ColorCorrectionEffect")
if cc then set(cc, "Brightness", 0); set(cc, "Contrast", 0.1); set(cc, "Saturation", 0.12); set(cc, "TintColor", rgb(255, 255, 255)) end
local atm = L:FindFirstChildOfClass("Atmosphere")
if atm then set(atm, "Density", 0.2); set(atm, "Haze", 0.2); set(atm, "Glare", 0) end
local rays = L:FindFirstChildOfClass("SunRaysEffect")
if rays then set(rays, "Intensity", 0.02) end
table.insert(report, "Lighting : fait")

-- 2. et 3. Néons de la map et boutiques -----------------------------------------------------------
local KEEP_NEON = { Screen = true, AuraSwatch = true, Orb = true, Star = true, Handle = true }
local function inContractWall(d: Instance): boolean
	local p = d.Parent
	while p and p ~= workspace do
		if CS:HasTag(p, "ZoneGate") or CS:HasTag(p, "NightWall") then return true end
		p = p.Parent
	end
	return CS:HasTag(d, "ZoneGate") or CS:HasTag(d, "NightWall")
end

-- Clément, 2026-11-14 : dans les zones du couloir, les bâtiments et le décor gardent leurs vrais néons. Seules les
-- grandes surfaces lumineuses restent en néon la nuit seulement : fenêtres de Tokyo (Zone_3, Windows) et anneaux
-- de New York (Zone_6, Ring). Les magasins PNJ (STORE_*) suivent toujours la règle.
local function corridorDecorKept(d: Instance): boolean
	local zone, store = nil, false
	local p = d.Parent
	while p and p ~= workspace do
		if p.Name:match("^STORE_") then store = true end
		if p.Parent == workspace.Map and p.Name:match("^Zone_%d$") then zone = tonumber(p.Name:match("%d")) end
		p = p.Parent
	end
	if not zone or store then return false end
	local base = d.Name:gsub("_?%d+$", "")
	return not ((zone == 3 and base == "Windows") or (zone == 6 and base == "Ring"))
end

local plainCount, plateCount, keptBack = 0, 0, 0
local function treatPart(d: BasePart)
	if corridorDecorKept(d) then return end
	if d.Name == "Plate" and d.Parent and d.Parent.Name:match("^CollectPad_") then
		set(d, "Material", Enum.Material.SmoothPlastic)
		set(d, "Color", rgb(76, 214, 72))
		plateCount += 1
		return
	end
	if d.Material ~= Enum.Material.Neon or d.Transparency >= 0.95 then return end
	local base = d.Name:gsub("_?%d+$", "")
	local parentName = if d.Parent then d.Parent.Name else ""
	if d.Name:match("^CeilingLight") or parentName == "CeilingLights" or KEEP_NEON[base] or KEEP_NEON[d.Name] or inContractWall(d) then return end
	if CS:HasTag(d, "NightLight") and d:GetAttribute(P .. "Tag_NightLight") == nil then return end
	set(d, "Material", Enum.Material.SmoothPlastic)
	addTag(d, "NightLight")
	plainCount += 1
end

-- Les tapis gardent leurs néons (identité de chaque palier) : seule leur partie 4 change.
local function inTreadmill(d: Instance): boolean
	local p = d.Parent
	while p and p ~= game do
		if p.Name == "Treadmill" or p.Name:match("^PLOT_Treadmill") or CS:HasTag(p, "Treadmill") then return true end
		p = p.Parent
	end
	return false
end

for _, root in { workspace.Map, plots :: Instance } do
	if root == nil then continue end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not inTreadmill(d) then
			treatPart(d)
		end
	end
end
-- écrans et présentoirs déjà passés par un premier essai (zone 1) : remis en néon
for _, d in workspace.Map:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute(P .. "Material") ~= nil then
		local base = d.Name:gsub("_?%d+$", "")
		if KEEP_NEON[base] or KEEP_NEON[d.Name] then restore(d); keptBack += 1 end
	end
end
table.insert(report, string.format("Map et gabarits : %d néons en couleur pleine le jour (néon la nuit), %d plaques en vert plein, %d écrans remis en néon", plainCount, plateCount, keptBack))

-- 4. Tapis au repos --------------------------------------------------------------------------------
local treadmills: { Instance } = {}
if plots then
	for _, m in plots:GetChildren() do
		if m.Name:match("^PLOT_Treadmill") then table.insert(treadmills, m) end
	end
end
for _, m in CS:GetTagged("Treadmill") do
	if m:IsDescendantOf(workspace) then table.insert(treadmills, m) end
end
local pe, li = 0, 0
for _, m in treadmills do
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			if d.LightEmission > 0.5 then set(d, "LightEmission", 0.5) end
			if d.Rate > 0 and d:GetAttribute(P .. "Rate") == nil then set(d, "Rate", d.Rate * 0.5) end
			pe += 1
		elseif d:IsA("Light") and d.Brightness > 2 then
			set(d, "Brightness", 2); li += 1
		end
	end
end
table.insert(report, string.format("Tapis (%d modèles) : %d émetteurs adoucis, %d lumières ramenées à 2", #treadmills, pe, li))

return table.concat(report, "\n")
