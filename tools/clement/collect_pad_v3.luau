--[[
	collect_pad_v3.luau (Clément, 2026-11-23) : plaques d'argent CollectPad_xx refaites « comme dans les exemples »
	(StealAShop-Art/References/Analyses_Jeux/Concurrent_*), validées sur le prototype de
	Workspace/_APERCU_SolLumiere/Sol_3_Musee/_Proto, sans le rebord doré.

	Pour chaque CollectPad_xx du gabarit PLOT_Shop, de PLOT_Shop_Rayons et des boutiques du hub :
	- CollectPad_xx (invisible, volume lu par le code) passe à plat, 4,6 × 5, centré au même x, z ;
	- PadBase (nouveau, décor) : socle gris foncé 4,6 × 0,2 × 5 sous la plaque ;
	- Plate : dalle verte à tenons 4,4 × 4, dessus à y 0,62, couchée face Front vers le ciel, haut du texte vers
	  le socle : le montant se lit depuis le tapis central ; garde SinkDepth, Glow et BurstPoint (remis au-dessus de la plaque, axes du
	  monde, comme collect_pad_fx.luau) ;
	- AmountGui redevient un SurfaceGui sur la face Front (vers le ciel) de Plate (le contrat accepte BillboardGui ou SurfaceGui,
	  LayerCollector) avec Amount (blanc, contour noir). CollectLabel et OfflineLabel ne sont plus posés
	  (Silent dans le contrat).
	À lancer dans la barre de commande en Edit. Sauvegarde avant : ServerStorage/MapBackups/2026-11-23_PadsSol.
]]

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local BASE_SIZE = Vector3.new(4.6, 0.2, 5)
local PLATE_SIZE = Vector3.new(4.4, 0.12, 4.0) -- X le long de l'allée une fois tournée, Z vers le socle
local BASE_Y, PLATE_Y = 0.4, 0.56
local PAD_X = 11.1
local GREEN = Color3.fromRGB(76, 214, 72)
local BASE_COLOR = Color3.fromRGB(58, 62, 72)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function amountGui(plate: BasePart)
	for _, g in plate:GetChildren() do
		if g:IsA("LayerCollector") and g.Name == "AmountGui" then g:Destroy() end
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "AmountGui"
	sg.Face = Enum.NormalId.Front -- Front tourné vers le ciel (voir redo)
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0
	sg.Enabled = false -- le code l'allume dès que la plaque porte au moins $1 (L-107)
	local t = Instance.new("TextLabel")
	t.Name = "Amount"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.92, 0.6)
	t.Position = UDim2.fromScale(0.04, 0.2)
	t.FontFace = FONT
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = "$0"
	t.Parent = sg
	local st = Instance.new("UIStroke")
	st.Thickness = 0.09
	st.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	st.Color = Color3.new(0, 0, 0) -- contour noir (Clément, 2026-11-23)
	st.Parent = t
	sg.Parent = plate
end

local function redo(pad: BasePart, pv: CFrame)
	local lp = pv:PointToObjectSpace(pad.Position)
	local side = lp.X < 0 and -1 or 1
	local x, z = side * PAD_X, lp.Z
	pad.Size = Vector3.new(BASE_SIZE.X, 0.12, BASE_SIZE.Z)
	pad.CFrame = pv * CFrame.new(x, PLATE_Y, z)
	pad.Transparency = 1
	local base = pad:FindFirstChild("PadBase") or Instance.new("Part")
	base.Name = "PadBase"
	quiet(base :: BasePart)
	base.Size = BASE_SIZE
	base.CFrame = pv * CFrame.new(x, BASE_Y, z)
	base.Color = BASE_COLOR
	base.Material = Enum.Material.SmoothPlastic
	base.Parent = pad
	local plate = pad:FindFirstChild("Plate")
	if not (plate and plate:IsA("BasePart")) then return false end
	-- Face Front vers le ciel, haut du texte (UpVector) vers le socle : le montant se lit depuis le tapis
	-- central (Clément, 2026-11-23). Size : X le long de l'allée, Y vers le socle, Z = épaisseur.
	local pos = (pv * CFrame.new(x, PLATE_Y, z)).Position
	plate.Size = Vector3.new(PLATE_SIZE.X, PLATE_SIZE.Z, PLATE_SIZE.Y)
	plate.CFrame = CFrame.lookAt(pos, pos + pv.UpVector, pv:VectorToWorldSpace(Vector3.new(side, 0, 0)))
	plate.Material = Enum.Material.Plastic
	plate.MaterialVariant = "Studs"
	plate.Color = GREEN
	plate.Transparency = 0
	local burst = plate:FindFirstChild("BurstPoint")
	if burst and burst:IsA("Attachment") then
		burst.WorldCFrame = CFrame.new(plate.Position + pv.UpVector * (PLATE_SIZE.Y / 2))
	end
	amountGui(plate)
	return true
end

local function redoAll(root: Instance, pv: CFrame): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^CollectPad_%d%d$") then
			if redo(d, pv) then n += 1 end
		end
	end
	return n
end

local plots = RS.Assets.Plots
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-23_PadsSol") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-23_PadsSol"
	plots.PLOT_Shop:Clone().Parent = f
	plots.PLOT_Shop_Rayons:Clone().Parent = f
	for _, s in workspace.Map.Hub.Shops:GetChildren() do
		if s:IsA("Model") then s:Clone().Parent = f end
	end
	f.Parent = backups
end

local report = {}
-- Le gabarit et PLOT_Shop_Rayons ont le pivot identité (même repère, L-082).
table.insert(report, "PLOT_Shop " .. redoAll(plots.PLOT_Shop, CFrame.identity))
table.insert(report, "PLOT_Shop_Rayons " .. redoAll(plots.PLOT_Shop_Rayons, CFrame.identity))
for _, s in workspace.Map.Hub.Shops:GetChildren() do
	if s:IsA("Model") then table.insert(report, s.Name .. " " .. redoAll(s, s:GetPivot())) end
end
print("[collect_pad_v3] " .. table.concat(report, ", "))
return table.concat(report, ", ")
