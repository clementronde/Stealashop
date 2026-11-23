--[[
	rarest_treadmill_v2.luau (Clément, 2026-11-23) : « revois le plot du rarest devant le shop, et mets plus devant
	la boutique le treadmill ». Validé sur l'aperçu Workspace/_APERCU_SolLumiere/Sol_3_Musee.

	1. RarestDisplay en style musée (comme les socles DisplayStand_xx) : Base = marche de marbre (garde sa
	   collision), Decor (marche, velours marron, bandes et arêtes dorées, liseré, 4 poteaux dorés et cordon de
	   velours rouge sur 3 côtés, l'allée ouverte), Plate = dessus en marbre (garde ItemPoint, LabelPoint et sa
	   PointLight), Sign = plaque dorée, texte foncé. Plus de néons ni de rebords. ItemPoint monte de y 0,8 à 2,35
	   et LabelPoint de 1,55 (11,8 → 13,35).
	2. Treadmill devant la façade, en miroir du socle : pivot de (-24, -56) à (-16,6, -49,25), même orientation ;
	   hors de l'axe de la porte (x -10 à 10). UpgradePoint passe devant le tapis, côté rue, en (-16,6 ; 0 ; -58,6)
	   (sinon il tombait dans le chemin de la porte).
	Gabarit PLOT_Shop et 6 boutiques du hub. À lancer en Edit. Sauvegarde : MapBackups/2026-11-23_RarestTapis.
]]

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local MARBLE = Color3.fromRGB(244, 241, 235)
local ROPE = Color3.fromRGB(170, 20, 40)
local CX, CZ = 14.25, -46.5
local TREAD = Vector3.new(-16.6, 0, -49.25)
local UPGRADE = Vector3.new(-16.6, 0, -58.6)

local function apply(M: Model, pv: CFrame): string
	local R = M:FindFirstChild("RarestDisplay")
	if not R then return M.Name .. " : pas de RarestDisplay" end
	local lip = M:FindFirstChild("GoldLip", true)
	local GOLD = if lip and lip:IsA("BasePart") then lip.Color else Color3.fromRGB(214, 170, 72)
	local st = M:FindFirstChild("DisplayStand_01", true)
	local VELVET = if st and st:IsA("BasePart") then st.Color else Color3.fromRGB(112, 64, 38)

	local function part(parent: Instance, name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local found = parent:FindFirstChild(name)
		local p: Part = if found and found:IsA("Part") then found else Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = pv * CFrame.new(x, y, z)
		p.Color = color
		p.Material = mat
		p.MaterialVariant = ""
		p.Parent = parent
		return p
	end

	for _, n in { "Rim_F", "Rim_B", "Rim_L", "Rim_R", "Trim_F", "Trim_B", "Trim_L", "Trim_R", "CornerLight_FL", "CornerLight_FR", "CornerLight_BL", "CornerLight_BR" } do
		local p = R:FindFirstChild(n)
		if p then p:Destroy() end
	end
	local base = R:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		base.Size = Vector3.new(9, 0.4, 10)
		base.CFrame = pv * CFrame.new(CX, 0.2, CZ)
		base.Color = MARBLE
		base.Material = Enum.Material.Marble
		base.MaterialVariant = ""
	end
	local D = R:FindFirstChild("Decor") or Instance.new("Model")
	D.Name = "Decor"
	D.Parent = R
	part(D, "Step2", CX, 0.55, CZ, 8.2, 0.3, 9.2, MARBLE, Enum.Material.Marble)
	part(D, "GoldBand_Low", CX, 0.74, CZ, 7.5, 0.08, 8.5, GOLD, Enum.Material.Metal)
	part(D, "Shaft", CX, 1.45, CZ, 7.2, 1.3, 8.2, VELVET, Enum.Material.Fabric)
	part(D, "GoldBand_High", CX, 2.06, CZ, 7.5, 0.08, 8.5, GOLD, Enum.Material.Metal)
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		part(D, "GoldEdge_" .. c[1] .. "_" .. c[2], CX + c[1] * 3.6, 1.45, CZ + c[2] * 4.1, 0.14, 1.3, 0.14, GOLD, Enum.Material.Metal)
	end
	local plate = R:FindFirstChild("Plate")
	if plate and plate:IsA("BasePart") then
		plate.Size = Vector3.new(8.0, 0.25, 9.0)
		plate.CFrame = pv * CFrame.new(CX, 2.225, CZ)
		plate.Color = MARBLE
		plate.Material = Enum.Material.Marble
		plate.MaterialVariant = ""
		local ip = plate:FindFirstChild("ItemPoint")
		if ip and ip:IsA("Attachment") then ip.WorldPosition = (pv * CFrame.new(CX, 2.35, CZ)).Position end
		local lp = plate:FindFirstChild("LabelPoint")
		if lp and lp:IsA("Attachment") then lp.WorldPosition = (pv * CFrame.new(CX, 13.35, CZ)).Position end
	end
	part(D, "GoldLip", CX, 2.365, CZ, 8.04, 0.03, 9.04, GOLD, Enum.Material.Metal)
	local posts = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	local px, pz = 4.3, 4.8
	local side = CFrame.Angles(0, 0, math.rad(90)) -- cylindre debout
	for i, c in posts do
		local x, z = CX + c[1] * px, CZ + c[2] * pz
		part(D, "PostFoot_" .. i, x, 0.5, z, 0.2, 0.7, 0.7, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = pv * CFrame.new(x, 0.5, z) * side
		part(D, "Post_" .. i, x, 1.5, z, 2.0, 0.22, 0.22, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = pv * CFrame.new(x, 1.5, z) * side
		part(D, "PostTop_" .. i, x, 2.6, z, 0.36, 0.36, 0.36, GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	end
	for i = 1, 4 do
		local a, b = posts[i], posts[i % 4 + 1]
		if a[2] == -1 and b[2] == -1 then
			local old = D:FindFirstChild("Rope_" .. i)
			if old then old:Destroy() end -- côté de l'allée laissé ouvert
		else
			local p1 = pv * Vector3.new(CX + a[1] * px, 2.25, CZ + a[2] * pz)
			local p2 = pv * Vector3.new(CX + b[1] * px, 2.25, CZ + b[2] * pz)
			local mid = (p1 + p2) / 2 - Vector3.new(0, 0.25, 0)
			local rope = part(D, "Rope_" .. i, 0, 0, 0, (p2 - p1).Magnitude, 0.16, 0.16, ROPE, Enum.Material.Fabric, Enum.PartType.Cylinder)
			rope.CFrame = CFrame.lookAt(mid, mid + (p2 - p1)) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	local sign = R:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") then
		sign.Size = Vector3.new(5, 0.9, 0.12)
		sign.CFrame = pv * CFrame.new(CX, 1.45, CZ - 4.17)
		sign.Color = GOLD
		sign.Material = Enum.Material.Metal
		local g = sign:FindFirstChild("LabelGui_Front")
		local lab = g and g:FindFirstChild("Label")
		if lab and lab:IsA("TextLabel") then
			lab.TextColor3 = Color3.fromRGB(40, 28, 12)
			local s = lab:FindFirstChildOfClass("UIStroke")
			if s then s.Transparency = 1 end
		end
	end

	local tm = M:FindFirstChild("Treadmill")
	if tm and tm:IsA("Model") then
		local up = tm:FindFirstChild("UpgradePoint", true)
		local upRot = if up and up:IsA("Attachment") then up.WorldCFrame.Rotation else nil
		local rot = pv:ToObjectSpace(tm:GetPivot()).Rotation
		tm:PivotTo(pv * CFrame.new(TREAD) * rot)
		if up and up:IsA("Attachment") and upRot then up.WorldCFrame = CFrame.new((pv * CFrame.new(UPGRADE)).Position) * upRot end
	end
	return M.Name .. " ok"
end

local plots = RS.Assets.Plots
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-23_RarestTapis") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-23_RarestTapis"
	plots.PLOT_Shop:Clone().Parent = f
	for _, s in workspace.Map.Hub.Shops:GetChildren() do
		if s:IsA("Model") then s:Clone().Parent = f end
	end
	f.Parent = backups
end
local out = { apply(plots.PLOT_Shop, CFrame.identity) }
for _, s in workspace.Map.Hub.Shops:GetChildren() do
	if s:IsA("Model") then table.insert(out, apply(s, s:GetPivot())) end
end
print("[rarest_treadmill_v2] " .. table.concat(out, ", "))
return table.concat(out, ", ")
