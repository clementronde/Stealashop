--[[
	fitting_room_build.luau (Clément, 2026-11-24, L-312) : la cabine d'essayage FittingRoom de la boutique du joueur.
	Code de Cantin (a411, L-113) : un Model nommé FittingRoom n'importe où dans la parcelle ; le joueur doit être à
	Config/Disguise.Cabin.Range (14) studs au plus de son pivot ; l'invite « Fitting Room » se pose sur sa PREMIÈRE
	pièce (FindFirstChildWhichIsA("BasePart", true)) : PromptPart est donc créée en premier.

	Place : coin du fond à droite du rez-de-chaussée (x 23 à 30,6 ; z 0,3 à 6,1), entre la place 08 (x 24, z −3), le
	mur droit et la vitre du fond ; l'ouverture (rideau) regarde l'allée centrale (−x). Pivot : au sol, au milieu
	de l'ouverture (x 23,3 ; z 3,2).
	Style musée de la boutique : cabine en bois sombre, liserés dorés, rideau de velours rouge à demi tiré sur une
	tringle dorée, miroir au fond, enseigne dorée « FITTING ROOM » au-dessus de l'ouverture, petite lampe.
	Aucun script. Murs pleins (on n'y entre pas), rideau, enseigne et lampe sans collision.
	À lancer en Edit : gabarit PLOT_Shop et 6 boutiques du hub. Sauvegarde : MapBackups/2026-11-24_FittingRoom.
]]

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local WOOD = Color3.fromRGB(86, 54, 38)
local WOOD_DARK = Color3.fromRGB(62, 38, 27)
local GOLD = Color3.fromRGB(214, 170, 72)
local VELVET = Color3.fromRGB(170, 20, 40)
local MIRROR = Color3.fromRGB(196, 222, 236)
local MARBLE = Color3.fromRGB(244, 241, 235)

-- repère local de la cabine : origine au sol (y 0,3) au milieu de l'ouverture, +X vers le fond de la cabine (mur
-- droit de la boutique), +Z vers le fond de la boutique.
local ORIGIN = CFrame.new(23.3, 0.3, 3.2)
local W, D, H = 7, 5.2, 9 -- profondeur (x), largeur (z), hauteur ; corniche comprise : x 23 à 30,6, z 0,3 à 6,1
-- (la colonne du coin commence en x 30,7 et z 6,2 ; la place 08 s'arrête en z 0)

local function build(shop: Model, pv: CFrame): string
	local old = shop:FindFirstChild("FittingRoom")
	if old then old:Destroy() end
	local M = Instance.new("Model")
	M.Name = "FittingRoom"
	local base = pv * ORIGIN

	local function part(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: Color3, mat: Enum.Material, solid: boolean, parent: Instance?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = solid
		p.CanQuery = solid
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = base * CFrame.new(x, y, z)
		p.Color = color
		p.Material = mat
		p.Parent = parent or M
		return p
	end

	-- 1. pièce de l'invite (la première) : invisible, au milieu de l'ouverture, à hauteur de poitrine
	local prompt = part("PromptPart", 0.2, 3, 0, 0.2, 2, 2, WOOD, Enum.Material.SmoothPlastic, false)
	prompt.Transparency = 1

	-- 2. socle, murs, toit
	part("Base", W / 2, 0.15, 0, W, 0.3, D, MARBLE, Enum.Material.Marble, true)
	part("Wall_Back", W - 0.2, H / 2 + 0.3, 0, 0.4, H, D, WOOD, Enum.Material.Wood, true)
	part("Wall_L", W / 2, H / 2 + 0.3, -D / 2 + 0.2, W, H, 0.4, WOOD, Enum.Material.Wood, true)
	part("Wall_R", W / 2, H / 2 + 0.3, D / 2 - 0.2, W, H, 0.4, WOOD, Enum.Material.Wood, true)
	part("Roof", W / 2, H + 0.45, 0, W + 0.4, 0.3, D + 0.4, WOOD_DARK, Enum.Material.Wood, true)
	part("Cornice", W / 2, H + 0.75, 0, W + 0.6, 0.3, D + 0.6, GOLD, Enum.Material.Metal, false)
	-- montants de l'ouverture et liserés dorés
	part("Post_L", 0.25, H / 2 + 0.3, -D / 2 + 0.25, 0.5, H, 0.5, WOOD_DARK, Enum.Material.Wood, true)
	part("Post_R", 0.25, H / 2 + 0.3, D / 2 - 0.25, 0.5, H, 0.5, WOOD_DARK, Enum.Material.Wood, true)
	part("Trim_Low_L", W / 2, 1.1, -D / 2 - 0.02, W, 0.12, 0.42, GOLD, Enum.Material.Metal, false)
	part("Trim_Low_R", W / 2, 1.1, D / 2 + 0.02, W, 0.12, 0.42, GOLD, Enum.Material.Metal, false)
	part("Trim_High_L", W / 2, H - 0.4, -D / 2 - 0.02, W, 0.12, 0.42, GOLD, Enum.Material.Metal, false)
	part("Trim_High_R", W / 2, H - 0.4, D / 2 + 0.02, W, 0.12, 0.42, GOLD, Enum.Material.Metal, false)
	part("Lintel", 0.25, H - 0.35, 0, 0.5, 1.3, D - 1, WOOD_DARK, Enum.Material.Wood, true)

	-- 3. miroir au fond, avec cadre doré, et patère
	part("MirrorFrame", W - 0.45, 4.6, 0, 0.1, 6.2, 2.8, GOLD, Enum.Material.Metal, false)
	local mirror = part("Mirror", W - 0.52, 4.6, 0, 0.06, 5.8, 2.4, MIRROR, Enum.Material.Glass, false)
	mirror.Reflectance = 0.35
	part("Hook", W - 0.6, 6.5, -D / 2 + 1, 0.4, 0.15, 0.15, GOLD, Enum.Material.Metal, false)
	part("Stool", W - 1.6, 1.0, D / 2 - 1.3, 1.4, 1.4, 1.4, VELVET, Enum.Material.Fabric, false)

	-- 4. tringle et rideau à demi tiré (plis sur le côté gauche de l'ouverture)
	local rod = part("CurtainRod", 0.55, H - 1.15, 0, 0.18, 0.18, D - 1, GOLD, Enum.Material.Metal, false)
	rod.Shape = Enum.PartType.Cylinder
	rod.CFrame = base * CFrame.new(0.55, H - 1.15, 0) * CFrame.Angles(0, math.rad(90), 0)
	local curtain = Instance.new("Model")
	curtain.Name = "Curtain"
	curtain.Parent = M
	local folds = 6
	for i = 1, folds do
		local z = -D / 2 + 0.75 + (i - 1) * 0.42
		local x = 0.55 + (if i % 2 == 0 then 0.18 else -0.05)
		part(string.format("Fold_%02d", i), x, (H - 1.3) / 2 + 0.4, z, 0.22, H - 1.4, 0.5, if i % 2 == 0 then VELVET else Color3.fromRGB(140, 14, 32), Enum.Material.Fabric, false, curtain)
	end
	part("Tieback", 0.75, 3.8, -D / 2 + 1.8, 0.35, 0.25, 1.6, GOLD, Enum.Material.Metal, false, curtain)

	-- 5. enseigne dorée au-dessus de l'ouverture
	local sign = part("Sign", -0.08, H - 0.35, 0, 0.12, 1.0, D - 1.4, GOLD, Enum.Material.Metal, false)
	local g = Instance.new("SurfaceGui")
	g.Name = "SignGui"
	g.Face = Enum.NormalId.Left
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0.6
	g.Parent = sign
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.Text = "FITTING ROOM"
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = Color3.fromRGB(40, 28, 12)
	t.Parent = g

	-- 6. petite lampe sur le toit
	local lamp = part("Lamp", W / 2, H + 1.3, 0, 0.8, 0.8, 0.8, Color3.fromRGB(255, 226, 160), Enum.Material.Neon, false)
	lamp.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Brightness = 0.8
	light.Range = 10
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Shadows = false
	light.Parent = lamp

	M.WorldPivot = base
	M.Parent = shop
	return shop.Name .. " ok"
end

local plots = RS.Assets.Plots
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-24_FittingRoom") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-24_FittingRoom"
	plots.PLOT_Shop:Clone().Parent = f
	f.Parent = backups
end
local out = { build(plots.PLOT_Shop, CFrame.identity) }
for _, s in workspace.Map.Hub.Shops:GetChildren() do
	if s:IsA("Model") then table.insert(out, build(s, s:GetPivot())) end
end
print("[fitting_room_build] " .. table.concat(out, ", "))
return table.concat(out, ", ")
