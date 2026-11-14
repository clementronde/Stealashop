--!nocheck
-- Vitrine-coffre de l'événement de la Fortune Tower (L-145), croquis A choisi par Clément le 2026-11-14.
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relançable : remplace le modèle et le point à l'identique.
-- 1) ENV_Event_FortuneVault dans ReplicatedStorage/Assets/Events : coffre-fort d'acier de 36 x 22 x 20 studs,
--    pivot en bas au centre, face avant vers -Z. Window = la porte blindée à volant (ses enfants disparaissent
--    avec elle à la casse) ; intérieur où l'on entre à pied (33,6 x 19,6 x 18,5 libres, porte de 16 x 13) ;
--    LootSpawn_01 à _08 sur les étagères d'acier (2 côtés x 2 niveaux x 2) ; HealthBarPoint au-dessus de la porte ;
--    OutlineHighlight. Aucun script.
-- 2) Point FortuneVaultSpawn (pièce invisible, sans collision, tag FortuneVaultSpawn) dans Map/Zone_6, devant la
--    façade de la Fortune Tower (x = 868) : le coffre occupe x 845..867, z -18..18, le couloir reste libre sur les côtés.
-- 3) Retire les croquis (Workspace/_CROQUIS_FortuneVault).
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local rgb = Color3.fromRGB

local events = RS:WaitForChild("Assets"):FindFirstChild("Events")
if not events then events = Instance.new("Folder"); events.Name = "Events"; events.Parent = RS.Assets end
local old = events:FindFirstChild("ENV_Event_FortuneVault"); if old then old:Destroy() end

local O = CFrame.identity
local m = Instance.new("Model"); m.Name = "ENV_Event_FortuneVault"
local function B(parent, nm, x0, y0, z0, x1, y1, z1, color, o)
	o = o or {}
	local p = Instance.new("Part"); p.Name = nm; p.Anchored = true
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = O * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) * (o.rot or CFrame.identity)
	p.Color = color; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then p.Shape = o.shape end
	if o.mat then p.Material = o.mat elseif o.smooth then p.Material = Enum.Material.SmoothPlastic else p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs" end
	if o.decor then p.CanCollide = false; p.CanTouch = false end
	p.Parent = parent or m
	return p
end
local function label(part, face, text, color)
	local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_" .. face.Name; g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 30; g.LightInfluence = 0
	local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true; t.Text = text; t.TextColor3 = color
	t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	local s = Instance.new("UIStroke"); s.Color = Color3.new(0, 0, 0); s.Thickness = 3; s.Parent = t
	t.Parent = g; g.Parent = part
end
local function att(part, nm, x, y, z)
	local a = Instance.new("Attachment"); a.Name = nm; a.Parent = part
	a.WorldCFrame = O * CFrame.new(x, y, z)
	return a
end
local CYL = Enum.PartType.Cylinder
local AXZ = CFrame.Angles(0, math.rad(90), 0)   -- axe du cylindre le long de z (face vers la rue)

local steel, dark, light, gold, hazard = rgb(118, 126, 136), rgb(66, 72, 82), rgb(176, 183, 192), rgb(212, 172, 60), rgb(245, 196, 20)

-- Coque : 36 de large (x), 22 de profondeur (z, face avant à z = -11), sol à 0,45, ouverture de 16 x 13
local floor = B(nil, "Floor", -18, 0, -11, 18, 0.45, 11, rgb(56, 60, 68), { smooth = true, mat = Enum.Material.Marble })
B(nil, "Wall_L", -18, 0.45, -11, -16.8, 19, 11, steel)
B(nil, "Wall_R", 16.8, 0.45, -11, 18, 19, 11, steel)
B(nil, "Wall_Back", -16.8, 0.45, 9.8, 16.8, 19, 11, steel)
B(nil, "Front_L", -16.8, 0.45, -11, -8, 19, -9.8, steel)
B(nil, "Front_R", 8, 0.45, -11, 16.8, 19, -9.8, steel)
B(nil, "Front_Top", -8, 13.45, -11, 8, 19, -9.8, steel)
B(nil, "Roof", -18.4, 19, -11.4, 18.4, 20.2, 11.4, dark)

-- Encadrement blindé, gonds, bandes de danger devant la porte
B(nil, "Jamb_L", -9.6, 0.45, -11.8, -8, 14.6, -9.8, dark)
B(nil, "Jamb_R", 8, 0.45, -11.8, 9.6, 14.6, -9.8, dark)
B(nil, "Lintel", -9.6, 13.45, -11.8, 9.6, 14.6, -9.8, dark)
for k = 0, 9 do
	local x = -9.6 + k * 2.13
	B(nil, "HazardStep_" .. k, x, 0, -14, x + 1.06, 0.06, -11.8, (k % 2 == 0) and hazard or rgb(30, 30, 34), { decor = true, smooth = true })
end
for k = 0, 5 do
	B(nil, "Hinge_" .. k, 9.6, 1.5 + k * 2.2, -12.2, 10.6, 2.5 + k * 2.2, -11, light, { decor = true, smooth = true })
end

-- Porte blindée = Window (collision tant qu'elle tient), avec volant, barres de verrou et boulons en enfants
local win = B(nil, "Window", -8, 0.45, -11.6, 8, 13.45, -10.2, light, { smooth = true, mat = Enum.Material.DiamondPlate })
local cy = 7
B(win, "WheelHub", -0.9, cy - 0.9, -12.6, 0.9, cy + 0.9, -11.6, gold, { decor = true, smooth = true, shape = CYL, rot = AXZ })
for k, a in { 0, 60, 120 } do
	local p = B(win, "WheelSpoke_" .. k, -3.6, cy - 0.25, -12.3, 3.6, cy + 0.25, -11.8, gold, { decor = true, smooth = true })
	p.CFrame = O * CFrame.new(0, cy, -12.05) * CFrame.Angles(0, 0, math.rad(a))
end
for k = 0, 7 do
	local a = math.rad(k * 45)
	local p = B(win, "WheelRim_" .. k, -1.45, -0.25, -0.25, 1.45, 0.25, 0.25, gold, { decor = true, smooth = true })
	p.CFrame = O * CFrame.new(3.5 * math.cos(a), cy + 3.5 * math.sin(a), -12.05) * CFrame.Angles(0, 0, a + math.pi / 2)
end
for k, y in { 2.5, 11.5 } do
	B(win, "LockBar_" .. k, -6.5, y - 0.4, -12, 6.5, y + 0.4, -11.6, dark, { decor = true, smooth = true })
end
for k = 0, 11 do
	local x = -7 + (k % 6) * 2.8
	local y = (k < 6) and 1.2 or 12.7
	B(win, "Bolt_" .. k, x - 0.35, y - 0.35, -11.9, x + 0.35, y + 0.35, -11.6, dark, { decor = true, smooth = true, shape = CYL, rot = AXZ })
end

-- Enseigne et bandeau doré
local sign = B(nil, "VaultSign", -11, 15.2, -11.35, 11, 18.4, -11, rgb(30, 32, 38), { decor = true, smooth = true })
label(sign, Enum.NormalId.Front, "FORTUNE VAULT", gold)
B(nil, "GoldBand", -18.5, 18.6, -11.6, 18.5, 19.1, 11.6, gold, { decor = true, smooth = true })

-- Intérieur : étagères d'acier à gauche et à droite (2 niveaux), casiers de coffres au fond, lingots, néons
local spawns = {}
for _, sd in { -1, 1 } do
	local xw, xi = sd * 16.8, sd * 13.6
	for _, y in { 0.45, 4.6 } do
		B(nil, string.format("RackBoard_%s_%d", sd < 0 and "L" or "R", y < 1 and 1 or 2), math.min(xw, xi), y, -7.5, math.max(xw, xi), y + 0.4, 7.5, dark, { smooth = true })
		for _, z in { -3.6, 3.6 } do table.insert(spawns, { (xw + xi) / 2, y + 0.4, z }) end
	end
	for k, z in { -7.5, 0, 7.5 } do B(nil, string.format("RackPost_%s_%d", sd < 0 and "L" or "R", k), xi - 0.2, 0.45, z - 0.2, xi + 0.2, 9, z + 0.2, dark, { smooth = true }) end
	B(nil, "RackTop_" .. (sd < 0 and "L" or "R"), math.min(xw, xi), 8.6, -7.5, math.max(xw, xi), 9, 7.5, dark, { smooth = true })
end
for ix = 0, 7 do for iy = 0, 4 do
	local x, y = -11.2 + ix * 3.2, 1.6 + iy * 3
	B(nil, string.format("Deposit_%d_%d", ix, iy), x - 1.4, y - 1.2, 9.5, x + 1.4, y + 1.2, 9.8, (ix + iy) % 2 == 0 and gold or rgb(190, 150, 50), { decor = true, smooth = true })
end end
for k = 0, 5 do
	local x, y = -1.8 + (k % 3) * 1.8, 0.45 + math.floor(k / 3) * 0.8
	B(nil, "GoldBar_" .. k, x - 0.8, y, 3, x + 0.8, y + 0.8, 4.4, rgb(236, 186, 40), { decor = true, smooth = true, mat = Enum.Material.Neon })
end
for k, z in { -5, 4 } do B(nil, "CeilingLight_" .. k, -10, 18.6, z - 0.4, 10, 18.9, z + 0.4, rgb(220, 235, 255), { decor = true, mat = Enum.Material.Neon }) end

-- Points du contrat (Contract/Models.FortuneVault)
for i, s in spawns do att(floor, string.format("LootSpawn_%02d", i), s[1], s[2], s[3]) end
att(floor, "HealthBarPoint", 0, 23, -11)
local h = Instance.new("Highlight"); h.Name = "OutlineHighlight"; h.FillTransparency = 1; h.OutlineColor = Color3.new(0, 0, 0); h.Parent = m
m.WorldPivot = O
m.PrimaryPart = floor
m.Parent = events

-- Point d'apparition devant la Fortune Tower, face avant (-Z du point) vers l'arche
local zone = workspace.Map:FindFirstChild("Zone_6")
local oldSpawn = zone:FindFirstChild("FortuneVaultSpawn"); if oldSpawn then oldSpawn:Destroy() end
local sp = Instance.new("Part"); sp.Name = "FortuneVaultSpawn"
sp.Size = Vector3.new(4, 0.2, 4); sp.CFrame = CFrame.new(856, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
sp.Anchored = true; sp.CanCollide = false; sp.CanTouch = false; sp.CanQuery = false; sp.Transparency = 1; sp.CastShadow = false
CS:AddTag(sp, "FortuneVaultSpawn")
sp.Parent = zone

-- Croquis retirés
local croquis = workspace:FindFirstChild("_CROQUIS_FortuneVault"); if croquis then croquis:Destroy() end

local parts, cyl = 0, 0
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") then parts += 1; if d:IsA("Part") and d.Shape == CYL then cyl += 1 end end
end
return string.format("ENV_Event_FortuneVault : %d pièces (%d cylindres), %d LootSpawn ; FortuneVaultSpawn posé à (856, 0, 0)", parts, cyl, #spawns)
