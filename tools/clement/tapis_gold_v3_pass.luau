--!nocheck
-- Gold v3 (retour de Clement du 26/11 sur le v2 : « mieux, mais pas assez : manque d'effet, de coherence, de texture »).
-- A lancer en Edit APRES tools/clement/tapis_gold_v2_parts.luau : copie Previews/TREADMILLS/PLOT_Treadmill_Gold_v2 en
-- PLOT_Treadmill_Gold_v3 et lui applique :
-- 1. Une seule palette (reference 5, ange dore) : or, ivoire, blanc, et UN seul accent lumineux (blanc chaud). Le bleu
--    nuit du v2 disparait (piliers, torches, damier).
-- 2. Des materiaux Roblox choisis : Foil pour l'or lisse (moulures, bandes, console), Marble pour l'ivoire (piliers,
--    colonnes, plumes), Neon pour l'accent. Les dessus a tenons (socle, longerons, linteau) restent en Plastic + Studs,
--    notre DA ; un or a tenons cuit dans Blender (MaterialVariant) pourra les remplacer plus tard.
-- 3. Les memes moulures partout (socle large + bandeau + chapiteau) : portique, console, longerons, torches.
-- Points d'attache du chef VFX (Frame/PostTop_L, _R, ArchTop, FloorCenter, Belt/RunBurstPoint) et noms lus par le code
-- inchanges. Aucun script. Relancable.

local folder = game:GetService("ServerStorage").Previews.TREADMILLS
local src = folder:FindFirstChild("PLOT_Treadmill_Gold_v2")
assert(src, "lance d'abord tapis_gold_v2_parts.luau")
local old = folder:FindFirstChild("PLOT_Treadmill_Gold_v3")
if old then old:Destroy() end
local m = src:Clone()
m.Name = "PLOT_Treadmill_Gold_v3"
m.Parent = folder

local GOLD_LIGHT, GOLD, GOLD_DEEP = Color3.fromHex("F6C33A"), Color3.fromHex("E9A91C"), Color3.fromHex("B97A0E")
local IVORY, WHITE = Color3.fromHex("EFE4CC"), Color3.fromHex("F8F4EA")
local ACCENT = Color3.fromHex("FFEBB0") -- le seul accent lumineux

local function hex(c)
	return c:ToHex():upper()
end
local OLD_GOLD, OLD_GOLD2, OLD_GOLD3, OLD_NAVY, OLD_IVORY = "FFC21A", "C98A0B", "E8A812", "33406B", "F5F1E6"

-- 1 et 2 : palette et materiaux
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "Belt" and d.Name ~= "BeltEnds" and d.Name ~= "ConsoleScreen" then
		local h = hex(d.Color)
		local studs = d.MaterialVariant == "Studs"
		if d.Material == Enum.Material.Neon then
			d.Color = ACCENT
		elseif h == OLD_NAVY or h == OLD_IVORY then
			d.Color = if d.Parent.Name == "Wings" then WHITE else IVORY
			d.Material = Enum.Material.Marble
			d.MaterialVariant = ""
		elseif h == OLD_GOLD or h == OLD_GOLD2 or h == OLD_GOLD3 then
			if studs then
				d.Color = if h == OLD_GOLD2 then GOLD else GOLD_LIGHT -- dessus a tenons : or clair, Plastic + Studs
			else
				d.Material = Enum.Material.Foil
				d.MaterialVariant = ""
				d.Color = if h == OLD_GOLD2 then GOLD_DEEP else GOLD
			end
		end
	end
end
m.GoldGlow.Color = ACCENT
for _, b in m.ConsoleButtons:GetChildren() do
	b.Color = ACCENT
end

-- 3 : moulures communes (socle large, bandeau, chapiteau), en or Foil
local trim = m.Trim
local function mold(name, x0, x1, y0, y1, z0, z1, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(math.abs(x1 - x0), y1 - y0, math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = color or GOLD_DEEP
	p.Material = Enum.Material.Foil
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = trim
	return p
end
local PZ0, PZ1 = -4.7, -3.2
for side = -1, 1, 2 do
	local lo, hi = math.min(side * 3.0, side * 4.5), math.max(side * 3.0, side * 4.5)
	-- chapiteau sous le linteau et bandeau au-dessus du socle, comme la console et les torches
	mold("PillarCapital" .. side, lo - 0.18, hi + 0.18, 7.2, 7.6, PZ0 - 0.18, PZ1 + 0.18)
	mold("PillarCollar" .. side, lo - 0.1, hi + 0.1, 0.9, 1.15, PZ0 - 0.1, PZ1 + 0.1, GOLD)
	-- cadre dore autour des runes, sur la face qui regarde le coureur
	local cx = (lo + hi) / 2
	mold("RuneFrame" .. side, cx - 0.42, cx + 0.42, 1.2, 7.15, PZ1 - 0.02, PZ1 + 0.03, GOLD)
	-- longerons : meme moulure aux deux bouts
	for _, z in { -3.2, 5.1 } do
		local x0, x1 = math.min(side * 2.62, side * 3.9), math.max(side * 2.62, side * 3.9)
		mold("RailEnd" .. side .. "_" .. z, x0, x1, 0.6, 1.55, z - 0.22, z + 0.22)
	end
	-- torches : collier sous le chapiteau, comme les piliers
	local x, z = side * 4.75, 4.4
	mold("TorchCollar" .. side, x - 0.62, x + 0.62, 3.5, 3.7, z - 0.62, z + 0.62, GOLD)
end
-- console : socle et chapiteau de la meme famille
mold("ConsoleBase", -2.45, 2.45, 3.45, 3.62, -4.0, -2.9)
mold("ConsolePostBase", -0.7, 0.7, 0.62, 0.95, -3.95, -2.95, GOLD)
local n = 0
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		n += 1
	end
end
local _, s = m:GetBoundingBox()
local r = string.format("PLOT_Treadmill_Gold_v3 : %d pieces visibles, %.1f x %.1f x %.1f", n, s.X, s.Y, s.Z)
print("[gold v3] " .. r)
return r
