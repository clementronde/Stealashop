-- Statues du n° 1 des classements de la semaine (Clément, 2026-11-24 : « je veux à gauche de celui de gauche le plot
-- avec le skin du numéro 1, et à droite le skin du numéro 1 du classement de droite »). Noms proposés à Ironix (L-331).
-- À lancer dans Studio (MCP execute_luau, mode Edit) après hub_leaderboards_semaine.luau (les panneaux au fond du hub,
-- sur le mur ouest) et avant hub_jardin_deco.luau (qui retire ce qui pousse sur le mur à leur place).
-- Relancer refait les deux statues à l'identique. Aucun script (le LocalScript Animate du mannequin est retiré).
-- Map/Hub/Zones/ENV_Hub_LeaderboardStatue (×2), tag LeaderboardStatue, attribut Stat = WeeklyIncome ou WeeklySteals
-- (les mêmes valeurs que les panneaux) :
--  - Pedestal : socle voxel à tenons (pied sombre, bloc à la couleur du panneau voisin, dessus doré), plein ;
--  - Pedestal/Body/Plate : SurfaceGui sur la face avant, Title (« #1 MONEY/S » ou « #1 STEALS », fixe) et PlayerName
--    (« ??? » : le code y écrit le nom du n° 1) ;
--  - Rig : mannequin R15 doré (Humanoid, Animator, HumanoidRootPart ancré, Humanoid sans nom ni barre de vie, machine à
--    états coupée), 3,5 fois la taille d'un perso, debout sur le socle, face à la place. Le code lui applique l'avatar du
--    n° 1 (Players:GetHumanoidDescriptionFromUserId puis Humanoid:ApplyDescription, côté serveur) ; sans n° 1, il reste
--    doré.
local CS = game:GetService("CollectionService")
local rgb = Color3.fromRGB
local zones = workspace.Map.Hub.Zones

-- pied du socle sur le haut du mur ouest (plat à 39,2 de z 31 à 59 et de -56 à -31), à 2 studs du bord des panneaux
-- (z 1 à 35 et -35 à -1) : argent à gauche du panneau de gauche, vols à droite du panneau de droite (vus de la place)
local SPOTS = {
	WeeklyIncome = { x = -281, y = 39.2, z = 44.5, accent = rgb(240, 138, 30), title = "#1 MONEY/S" },
	WeeklySteals = { x = -281, y = 39.2, z = -44.5, accent = rgb(224, 64, 64), title = "#1 STEALS" },
}
local RIG_SCALE = 3.5
local GOLD, GOLD_D, DARK = rgb(255, 196, 52), rgb(226, 152, 24), rgb(58, 62, 72)

for _, m in zones:GetChildren() do if m.Name == "ENV_Hub_LeaderboardStatue" then m:Destroy() end end

local function part(parent, name, cf, size, color, solid)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CFrame = cf; p.Size = size; p.Color = color
	p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solid; p.CanQuery = solid; p.CanTouch = false
	p.Parent = parent
	return p
end

-- police du titre des panneaux (même habillage)
local font = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
for _, b in zones:GetChildren() do
	if b.Name == "ENV_Hub_Leaderboard" then
		local t = b:FindFirstChild("Title", true)
		if t and t:IsA("TextLabel") then font = t.FontFace; break end
	end
end
local function label(parent, name, text, pos, size)
	local l = Instance.new("TextLabel"); l.Name = name; l.Text = text
	l.Position = pos; l.Size = size; l.BackgroundTransparency = 1
	l.FontFace = font; l.TextColor3 = rgb(255, 255, 255); l.TextScaled = true; l.TextWrapped = true
	local s = Instance.new("UIStroke"); s.Color = rgb(27, 31, 39); s.Thickness = 6; s.Parent = l
	l.Parent = parent
	return l
end

local out = {}
for _, stat in { "WeeklyIncome", "WeeklySteals" } do
	local sp = SPOTS[stat]
	local m = Instance.new("Model"); m.Name = "ENV_Hub_LeaderboardStatue"
	m:SetAttribute("Stat", stat)
	CS:AddTag(m, "LeaderboardStatue")
	-- repère : avant (-Z local) vers +X, la place
	local f = CFrame.lookAt(Vector3.new(sp.x, sp.y, sp.z), Vector3.new(sp.x + 1, sp.y, sp.z))
	local ped = Instance.new("Model"); ped.Name = "Pedestal"; ped.Parent = m
	part(ped, "Foot", f * CFrame.new(0, 0.8, 0), Vector3.new(13, 1.6, 11), DARK, true)
	local body = part(ped, "Body", f * CFrame.new(0, 1.6 + 2.6, 0), Vector3.new(11, 5.2, 9), sp.accent, true)
	part(ped, "Trim", f * CFrame.new(0, 1.6 + 5.2 - 0.25, 0), Vector3.new(11.4, 0.5, 9.4), GOLD_D, true)
	local top = part(ped, "Top", f * CFrame.new(0, 1.6 + 5.2 + 0.5, 0), Vector3.new(12, 1, 10), GOLD, true)
	local topY = 1.6 + 5.2 + 1
	-- plaque sur la face avant du bloc
	local g = Instance.new("SurfaceGui"); g.Name = "Plate"; g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40; g.LightInfluence = 0
	g.MaxDistance = 450; g.Parent = body
	label(g, "Title", sp.title, UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.88, 0.36))
	label(g, "PlayerName", "???", UDim2.fromScale(0.06, 0.52), UDim2.fromScale(0.88, 0.36))
	-- mannequin R15 doré
	local rig = game.Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Name = "Rig"
	for _, d in rig:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	-- statue sans visage : la tête par défaut porte le visage dans sa texture (TextureID), parfois un Decal
	local face = rig:FindFirstChild("Head") and rig.Head:FindFirstChildOfClass("Decal"); if face then face:Destroy() end
	if rig.Head:IsA("MeshPart") then rig.Head.TextureID = "" end
	local bc = rig:FindFirstChildOfClass("BodyColors")
	if bc then
		for _, k in { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do bc[k] = GOLD end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.EvaluateStateMachine = false
	if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = GOLD; d.CanCollide = false; d.CanTouch = false; d.CanQuery = false
			d.Anchored = (d.Name == "HumanoidRootPart")
			-- Foil : l'or brille et les formes ressortent (tout doré en Plastic, le mannequin se lit comme un bloc)
			if d.Name ~= "HumanoidRootPart" then d.Material = Enum.Material.Foil end
		end
	end
	rig.Parent = m
	rig:ScaleTo(RIG_SCALE)
	-- face à la place, pieds sur le dessus du socle
	rig:PivotTo(f)
	local rcf, rs = rig:GetBoundingBox()
	local low = math.huge -- bas des pieds (la boîte du mannequin descend plus bas qu'eux)
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then low = math.min(low, d.Position.Y - d.Size.Y / 2) end
	end
	rig:PivotTo(rig:GetPivot() + Vector3.new(f.X - rcf.X, f.Y + topY - low, f.Z - rcf.Z))
	m.WorldPivot = f
	m.Parent = zones
	local _, ms = m:GetBoundingBox()
	table.insert(out, string.format("%s : socle 13 × 11 × %.1f, mannequin ×%.1f (%.1f de haut), statue %.1f de haut, en (%.0f ; %.1f ; %.1f)",
		stat, topY, RIG_SCALE, rs.Y, ms.Y, sp.x, sp.y, sp.z))
end
return table.concat(out, "\n")
